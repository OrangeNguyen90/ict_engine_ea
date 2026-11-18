"""Persistence and query boundary for the independent analysis engines."""
import hashlib
import json
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation

from django.db import transaction

from .engine import (ALGORITHM_VERSION, FVGDetectionEngine, LiquidityDetectionEngine,
                     MarketStructureEngine, PremiumDiscountEngine, SwingDetectionEngine,
                     candle_close_at, validate_sequence)
from .models import ICTAnalysisRun, ICTSignal, MarketCandle


def _jsonable(value):
    if isinstance(value, datetime):
        return value.astimezone(timezone.utc).isoformat()
    if isinstance(value, Decimal):
        return str(value)
    if isinstance(value, list):
        return [_jsonable(item) for item in value]
    if isinstance(value, dict):
        return {key: _jsonable(item) for key, item in value.items()}
    return value


class MarketDataService:
    def candles(self, *, symbol, timeframe, data_source, exchange=None, contract="", price_type="trade", start=None, end=None):
        query = MarketCandle.objects.filter(symbol=symbol, timeframe=timeframe, data_source=data_source,
                                            contract=contract, price_type=price_type)
        if exchange:
            query = query.filter(exchange=exchange)
        if start:
            query = query.filter(timestamp__gte=start)
        if end:
            query = query.filter(timestamp__lte=end)
        rows = list(query.order_by("timestamp", "id").values(
            "id", "timestamp", "open", "high", "low", "close", "volume", "symbol",
            "timeframe", "data_source", "exchange", "contract", "price_type"))
        if len({(row["exchange"], row["contract"], row["price_type"]) for row in rows}) > 1:
            raise ValueError("select one exchange, contract, and price type for analysis")
        validate_sequence(rows)
        return rows


class CandleValidationService:
    def validate(self, rows, timeframe=None):
        return validate_sequence(rows, timeframe)


class ICTAnalysisOrchestrator:
    def analyze(self, *, symbol, timeframe, data_source, exchange=None, contract="", price_type="trade",
                left_bars=2, right_bars=2, min_break="0", fvg_min_gap="0", liquidity_tolerance="0",
                as_of=None, mitigation="full", require_displacement=False):
        rows = MarketDataService().candles(symbol=symbol, timeframe=timeframe, data_source=data_source,
                                          exchange=exchange, contract=contract, price_type=price_type)
        cutoff = as_of or datetime.now(timezone.utc)
        if cutoff.tzinfo is None:
            raise ValueError("as_of must include a timezone")
        rows = [row for row in rows if candle_close_at(row, timeframe) <= cutoff]
        if not rows:
            raise ValueError("no closed market candles for this selection")
        CandleValidationService().validate(rows, timeframe)
        exchange = rows[0]["exchange"]
        for name, value in (("min_break", min_break), ("fvg_min_gap", fvg_min_gap), ("liquidity_tolerance", liquidity_tolerance)):
            try:
                number = Decimal(str(value))
            except InvalidOperation as exc:
                raise ValueError(f"{name} must be finite and nonnegative") from exc
            if not number.is_finite() or number < 0:
                raise ValueError(f"{name} must be finite and nonnegative")
        params = dict(left_bars=left_bars, right_bars=right_bars, min_break=min_break,
                      fvg_min_gap=fvg_min_gap, liquidity_tolerance=liquidity_tolerance,
                      exchange=exchange, contract=contract, price_type=price_type,
                      mitigation=mitigation, require_displacement=require_displacement)
        common = dict(symbol=symbol, timeframe=timeframe, source=data_source)
        swings = SwingDetectionEngine(left_bars, right_bars).detect(rows, **common)
        internal_swings = []
        if (left_bars, right_bars) != (1, 1):
            internal_swings = SwingDetectionEngine(1, 1).detect(rows, **common)
            for swing in internal_swings:
                swing["structure_scope"] = "internal"
        structure = MarketStructureEngine(min_break, require_displacement).detect(rows, swings, **common)
        fvgs = FVGDetectionEngine(fvg_min_gap, mitigation, require_displacement).detect(rows, **common)
        zones, liquidity_events = LiquidityDetectionEngine(liquidity_tolerance).detect(rows, swings, **common)
        signals = [*swings, *internal_swings, *structure, *fvgs, *zones, *liquidity_events]
        # Preserve every range that was knowable, rather than only the final range.
        for count in range(2, len(swings) + 1):
            dealing_range = PremiumDiscountEngine().detect(swings[:count], **common)
            if dealing_range.get("category"):
                signals.append(dealing_range)
        revisions = {}
        digest = hashlib.sha256()
        for row in rows:
            digest.update(json.dumps(_jsonable(row), sort_keys=True).encode())
            revisions[candle_close_at(row, timeframe)] = digest.hexdigest()
        with transaction.atomic():
            run = ICTAnalysisRun.objects.create(
                symbol=symbol, timeframe=timeframe, data_source=data_source,
                algorithm_version=ALGORITHM_VERSION, parameters=params,
                candle_count=len(rows), last_candle_at=rows[-1]["timestamp"])
            for signal in signals:
                signal.update(exchange=exchange, contract=contract, price_type=price_type,
                              analysis_parameters=params,
                              data_revision=revisions[signal["confirmed_at"]])
                identity = {key: _jsonable(signal.get(key)) for key in (
                    "category", "signal_type", "direction", "symbol", "timeframe",
                    "data_source", "algorithm_version", "formed_at", "parameters",
                    "structure_scope", "price", "lower_price", "upper_price", "range_high", "range_low",
                    "exchange", "contract", "price_type", "analysis_parameters", "data_revision")}
                key = hashlib.sha256(json.dumps(identity, sort_keys=True).encode()).hexdigest()
                run.signal_keys.append(key)
                payload = _jsonable(signal)
                history = payload.get("history", [])
                stored, created = ICTSignal.objects.get_or_create(signal_key=key, defaults={
                    "category": signal["category"], "signal_type": signal.get("signal_type", ""),
                    "direction": signal.get("direction", ""), "symbol": symbol, "timeframe": timeframe,
                    "data_source": data_source, "algorithm_version": ALGORITHM_VERSION,
                    "parameters": signal["parameters"], "formed_at": signal["formed_at"],
                    "confirmed_at": signal["confirmed_at"], "status": signal["status"],
                    "state_history": history, "evidence_ids": signal.get("evidence_ids", []),
                    "payload": payload, "first_run": run,
                })
                if not created and history != stored.state_history:
                    # A replay with more candles may extend state. Earlier transitions stay intact.
                    if history[:len(stored.state_history)] == stored.state_history:
                        stored.status, stored.state_history, stored.payload = signal["status"], history, payload
                        stored.save(update_fields=["status", "state_history", "payload"])
                    elif stored.state_history[:len(history)] != history:
                        raise ValueError("source correction changed signal history; import under a versioned data_source before reanalysis")
            run.signal_keys = sorted(set(run.signal_keys))
            run.save(update_fields=["signal_keys"])
            return run


def signal_as_of(signal, as_of):
    if signal.confirmed_at > as_of:
        return None
    payload = dict(signal.payload)
    status = "open" if signal.category == "fvg" else "untouched" if signal.category == "liquidity" else "confirmed"
    for transition in signal.state_history:
        if datetime.fromisoformat(transition["at"]) <= as_of:
            status = transition["status"]
    payload["status"] = status
    payload["history"] = [transition for transition in signal.state_history
                          if datetime.fromisoformat(transition["at"]) <= as_of]
    if signal.category == "fvg":
        payload["mitigated"] = payload["history"][-1].get("mitigated", False) if payload["history"] else False
    if payload.get("invalidated_at") and datetime.fromisoformat(payload["invalidated_at"]) > as_of:
        payload["invalidated_at"] = None
    return payload
