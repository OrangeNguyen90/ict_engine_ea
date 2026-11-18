"""Deterministic ICT-style research rules. These are system interpretations."""
from datetime import timedelta
from decimal import Decimal
from .timeframes import TIMEFRAME_DELTAS, expected_next

ALGORITHM_VERSION = "system-ict-2"


def _d(value):
    return value if isinstance(value, Decimal) else Decimal(str(value))


def candle_close_at(candle, timeframe):
    return expected_next(candle["timestamp"], timeframe)


def validate_sequence(candles, timeframe=None):
    """Reject malformed, duplicate, or out-of-order inputs before analysis."""
    previous = None
    for candle in candles:
        stamp = candle["timestamp"]
        if stamp.tzinfo is None or stamp.utcoffset() is None:
            raise ValueError("candle timestamps must include a timezone")
        if previous is not None and stamp <= previous:
            raise ValueError("candles must have unique, increasing timestamps")
        if timeframe and previous is not None and expected_next(previous, timeframe) != stamp:
            raise ValueError("missing or misaligned candles; supply a continuous series for analysis")
        previous = stamp
        prices = [_d(candle[name]) for name in ("open", "high", "low", "close")]
        if not all(price.is_finite() for price in prices):
            raise ValueError("nonfinite candle price")
        opening, high, low, close = prices
        if high < max(opening, low, close) or low > min(opening, high, close):
            raise ValueError("invalid OHLC candle")
        if candle.get("volume") is not None:
            volume = _d(candle["volume"])
            if not volume.is_finite() or volume < 0:
                raise ValueError("invalid candle volume")
    return candles


def _base(kind, candle, *, symbol, timeframe, source, params):
    return {
        "category": kind, "symbol": symbol, "timeframe": timeframe,
        "data_source": source, "algorithm_version": ALGORITHM_VERSION,
        "parameters": params, "status": "confirmed",
        "formed_at": candle["timestamp"], "confirmed_at": candle_close_at(candle, timeframe),
        "evidence_ids": [candle.get("id")] if candle.get("id") is not None else [],
    }


class SwingDetectionEngine:
    def __init__(self, left_bars=2, right_bars=2):
        if left_bars < 1 or right_bars < 1:
            raise ValueError("pivot windows must be positive")
        self.left_bars, self.right_bars = left_bars, right_bars

    def detect(self, candles, *, symbol, timeframe, source):
        validate_sequence(candles, timeframe)
        output, previous = [], {}
        params = {"left_bars": self.left_bars, "right_bars": self.right_bars,
                  "ties": "strict extremes; equal pivots rejected"}
        for index in range(self.left_bars, len(candles) - self.right_bars):
            pivot = candles[index]
            window = candles[index - self.left_bars:index + self.right_bars + 1]
            for swing_type, field, comparison in (
                ("high", "high", lambda value, others: all(value > other for other in others)),
                ("low", "low", lambda value, others: all(value < other for other in others)),
            ):
                price = _d(pivot[field])
                if not comparison(price, [_d(c[field]) for c in window if c is not pivot]):
                    continue
                confirmed = candles[index + self.right_bars]
                event = _base("swing", pivot, symbol=symbol, timeframe=timeframe, source=source, params=params)
                prior = previous.get(swing_type)
                label = None if prior is None else (
                    ("EQH" if price == prior else "HH" if price > prior else "LH") if swing_type == "high"
                    else ("EQL" if price == prior else "HL" if price > prior else "LL")
                )
                event.update(swing_type=swing_type, structure_label=label, price=price,
                             pivot_time=pivot["timestamp"], confirmed_at=candle_close_at(confirmed, timeframe),
                             evidence_ids=[c.get("id") for c in window if c.get("id") is not None],
                             structure_scope="external")
                previous[swing_type] = price
                output.append(event)
        return sorted(output, key=lambda item: (item["confirmed_at"], item["pivot_time"]))


class MarketStructureEngine:
    def __init__(self, min_break=Decimal("0"), require_displacement=False, displacement_ratio=Decimal("0.6")):
        self.min_break = _d(min_break)
        self.require_displacement = require_displacement
        self.displacement_ratio = _d(displacement_ratio)

    def detect(self, candles, swings, *, symbol, timeframe, source):
        validate_sequence(candles, timeframe)
        events, broken, trend = [], set(), None
        for candle in candles:
            stamp = candle["timestamp"]
            eligible = [s for s in swings if s["confirmed_at"] <= stamp and s["pivot_time"] < stamp]
            # Only the latest confirmed level on each side is structural. An
            # older already crossed level must not generate a delayed second BOS.
            latest = {}
            for swing in eligible:
                latest[swing["swing_type"]] = swing
            eligible = list(latest.values())
            for swing in reversed(eligible):
                key = (swing["swing_type"], swing["pivot_time"])
                if key in broken:
                    continue
                direction = "bullish" if swing["swing_type"] == "high" else "bearish"
                level = _d(swing["price"])
                close = _d(candle["close"])
                crossed = close > level + self.min_break if direction == "bullish" else close < level - self.min_break
                if not crossed:
                    continue
                if self.require_displacement:
                    body = abs(close - _d(candle["open"]))
                    span = _d(candle["high"]) - _d(candle["low"])
                    if span <= 0 or body / span < self.displacement_ratio:
                        continue
                kind = "MSS" if trend is not None and trend != direction else "BOS"
                event = _base("structure", candle, symbol=symbol, timeframe=timeframe, source=source,
                              params={"min_break": str(self.min_break), "require_displacement": self.require_displacement,
                                      "displacement_ratio": str(self.displacement_ratio)})
                event.update(signal_type=kind, direction=direction, price=level,
                             trend_before=trend or "undetermined", trend_after=direction,
                             pivot_time=swing["pivot_time"],
                             evidence_ids=[identifier for identifier in [*swing["evidence_ids"], candle.get("id")] if identifier is not None])
                events.append(event)
                broken.add(key)
                trend = direction
                break
        return events


class FVGDetectionEngine:
    def __init__(self, min_gap=Decimal("0"), mitigation="full", require_displacement=False):
        if mitigation not in ("touch", "half", "full"):
            raise ValueError("mitigation must be touch, half, or full")
        self.min_gap, self.mitigation = _d(min_gap), mitigation
        self.require_displacement = require_displacement

    def detect(self, candles, *, symbol, timeframe, source):
        validate_sequence(candles, timeframe)
        gaps = []
        for index in range(2, len(candles)):
            first, middle, last = candles[index - 2:index + 1]
            candidates = (
                ("bullish", _d(first["high"]), _d(last["low"])),
                ("bearish", _d(last["high"]), _d(first["low"])),
            )
            for direction, lower, upper in candidates:
                if upper - lower <= self.min_gap:
                    continue
                if self.require_displacement and abs(_d(middle["close"]) - _d(middle["open"])) <= (
                    _d(middle["high"]) - _d(middle["low"])
                ) / 2:
                    continue
                event = _base("fvg", last, symbol=symbol, timeframe=timeframe, source=source,
                              params={"min_gap": str(self.min_gap), "mitigation": self.mitigation,
                                      "require_displacement": self.require_displacement})
                event.update(direction=direction, lower_price=lower, upper_price=upper,
                             equilibrium=(lower + upper) / 2, status="open", mitigated=False,
                             formed_at=last["timestamp"], confirmed_at=candle_close_at(last, timeframe),
                             invalidated_at=None, history=[],
                             evidence_ids=[c.get("id") for c in (first, middle, last) if c.get("id") is not None])
                gaps.append(event)
        for gap in gaps:
            later = [c for c in candles if c["timestamp"] >= gap["confirmed_at"]]
            for candle in later:
                if gap["direction"] == "bullish":
                    touched = _d(candle["low"]) <= gap["upper_price"]
                    half = _d(candle["low"]) <= gap["equilibrium"]
                    full = _d(candle["low"]) <= gap["lower_price"]
                    invalid = _d(candle["close"]) < gap["lower_price"]
                else:
                    touched = _d(candle["high"]) >= gap["lower_price"]
                    half = _d(candle["high"]) >= gap["equilibrium"]
                    full = _d(candle["high"]) >= gap["upper_price"]
                    invalid = _d(candle["close"]) > gap["upper_price"]
                new_status = ("invalidated" if invalid else "filled" if full else
                              "partial" if half else "touched" if touched else gap["status"])
                rank = {"open": 0, "touched": 1, "partial": 2, "filled": 3, "invalidated": 4}
                if rank[new_status] < rank[gap["status"]]:
                    continue
                if new_status != gap["status"]:
                    gap["status"] = new_status
                    gap["mitigated"] = gap["mitigated"] or (touched if self.mitigation == "touch" else
                                        half if self.mitigation == "half" else full)
                    gap["history"].append({"at": candle_close_at(candle, timeframe), "status": new_status,
                                           "mitigated": gap["mitigated"], "candle_id": candle.get("id")})
                    if invalid:
                        gap["invalidated_at"] = candle_close_at(candle, timeframe)
                if new_status in ("filled", "invalidated"):
                    break
        return gaps


class LiquidityDetectionEngine:
    def __init__(self, tolerance=Decimal("0")):
        self.tolerance = _d(tolerance)
        if self.tolerance < 0:
            raise ValueError("tolerance must be nonnegative")

    def detect(self, candles, swings, *, symbol, timeframe, source):
        validate_sequence(candles, timeframe)
        zones, events = [], []
        for index, swing in enumerate(swings):
            side = "BSL" if swing["swing_type"] == "high" else "SSL"
            matches = [prior for prior in swings[:index] if prior["swing_type"] == swing["swing_type"]
                       and abs(_d(prior["price"]) - _d(swing["price"])) <= self.tolerance]
            event = dict(swing, category="liquidity", signal_type=("EQH" if side == "BSL" else "EQL") if matches else side,
                         side=side, lower_price=_d(swing["price"]) - self.tolerance,
                         upper_price=_d(swing["price"]) + self.tolerance,
                         status="untouched", history=[], invalidation_condition="close outside zone",
                         parameters={"tolerance": str(self.tolerance), "swing_parameters": swing["parameters"]} if "parameters" in swing else {"tolerance": str(self.tolerance)})
            if matches:
                event["evidence_ids"] = list(set(event["evidence_ids"] + matches[-1]["evidence_ids"]))
            zones.append(event)
        for zone in zones:
            for candle in candles:
                if candle["timestamp"] < zone["confirmed_at"]:
                    continue
                above = zone["side"] == "BSL"
                wick = _d(candle["high"]) > zone["upper_price"] if above else _d(candle["low"]) < zone["lower_price"]
                close_outside = _d(candle["close"]) > zone["upper_price"] if above else _d(candle["close"]) < zone["lower_price"]
                touched = _d(candle["high"]) >= zone["lower_price"] if above else _d(candle["low"]) <= zone["upper_price"]
                new_status = "broken" if close_outside else "swept" if wick else "touched" if touched else zone["status"]
                if new_status != zone["status"]:
                    zone["status"] = new_status
                    zone["history"].append({"at": candle_close_at(candle, timeframe), "status": new_status,
                                            "candle_id": candle.get("id")})
                    if new_status == "swept":
                        sweep = _base("liquidity_event", candle, symbol=symbol, timeframe=timeframe, source=source,
                                      params={"tolerance": str(self.tolerance)})
                        sweep.update(signal_type="sweep", side=zone["side"], price=zone["price"],
                                     zone_time=zone["confirmed_at"], evidence_ids=[candle.get("id")])
                        events.append(sweep)
                if new_status in ("broken", "swept"):
                    break
        return zones, events


class PremiumDiscountEngine:
    def detect(self, swings, *, symbol, timeframe, source):
        confirmed = sorted(swings, key=lambda s: s["confirmed_at"])
        if len(confirmed) < 2:
            return {"status": "insufficient_structure"}
        for last in reversed(confirmed):
            opposite = next((s for s in reversed(confirmed) if s["pivot_time"] < last["pivot_time"]
                             and s["swing_type"] != last["swing_type"]), None)
            if opposite is None:
                continue
            high = last if last["swing_type"] == "high" else opposite
            low = last if last["swing_type"] == "low" else opposite
            if _d(high["price"]) <= _d(low["price"]):
                continue
            event = _base("dealing_range", {"timestamp": last["pivot_time"]}, symbol=symbol, timeframe=timeframe, source=source,
                          params={"anchor_rule": "latest confirmed swing and preceding opposite confirmed swing"})
            event.update(range_high=_d(high["price"]), range_low=_d(low["price"]),
                         equilibrium=(_d(high["price"]) + _d(low["price"])) / 2,
                         high_anchor=high["pivot_time"], low_anchor=low["pivot_time"],
                         confirmed_at=max(high["confirmed_at"], low["confirmed_at"]),
                         evidence_ids=list(set(high["evidence_ids"] + low["evidence_ids"])),
                         structure_scope="external")
            return event
        return {"status": "insufficient_structure"}
