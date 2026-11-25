"""Causal research setups, isolated from the existing ICT decision engine.

All input bars must be closed, ordered and validated by the caller. Pivots are
usable only at the next bar's open after their right confirmation closes. ATR
is a simple mean of true ranges from prior closed bars within the same
contiguous segment. A missing or nonstandard interval resets all detector state.
The definitions here are research hypotheses, not validated trading signals.
"""

from __future__ import annotations

from collections import deque
from dataclasses import dataclass
from datetime import timedelta
import hashlib
import json

from .types import Bar, Candidate, ResearchConfig


DETECTOR_VERSION = "research-candidates-v1"


@dataclass
class _Pool:
    index: int
    price: float
    source_id: str
    consumed_sweep: bool = False
    consumed_break: bool = False


@dataclass(frozen=True)
class _Gap:
    index: int
    direction: int
    lower: float
    upper: float
    source_id: str
    formation_atr: float
    impulse_body_atr: float


@dataclass(frozen=True)
class _Break:
    index: int
    direction: int
    level: float
    source_id: str
    strength_atr: float


def _identity(*parts: object) -> str:
    serialized = json.dumps(parts, separators=(",", ":"), ensure_ascii=True)
    return hashlib.sha256(serialized.encode("utf-8")).hexdigest()[:24]


def _body_ratio(bar: Bar) -> float:
    width = bar.high - bar.low
    return abs(bar.close - bar.open) / width if width > 0 else 0.0


def detect_candidates(bars: list[Bar], config: ResearchConfig) -> list[Candidate]:
    """Find three symmetric setup families without looking beyond each close.

    Only the latest confirmed high and low are retained as structural pools.
    Each pool can create one sweep and one closed-break source; a closed break
    consumes its sweep eligibility. Each FVG's first subsequent contact either
    produces a directional reaction or retires the zone. A break similarly
    requires its first subsequent contact to hold. Both expire after
    ``max_setup_bars``; the break/formation candle cannot retest itself.

    No entry, outcome, probability, higher-timeframe alignment or session is
    inferred here. The caller evaluates entry strictly after ``confirmed_at``.
    """
    output: list[Candidate] = []
    if not bars:
        return output

    duration = timedelta(seconds=config.timeframe_seconds)
    tolerance = config.tolerance_ticks * config.tick_size
    buffer = config.stop_buffer_ticks * config.tick_size
    ranges: deque[float] = deque(maxlen=config.atr_period)
    range_sum = 0.0
    previous_middle_atr: float | None = None
    segment_start = 0
    high_pool: _Pool | None = None
    low_pool: _Pool | None = None
    gaps: list[_Gap] = []
    breaks: dict[int, _Break] = {}
    rule_id = _identity(
        DETECTOR_VERSION, config.symbol, config.timeframe, config.timeframe_seconds,
        config.tick_size, config.atr_period, config.pivot_left, config.pivot_right,
        config.tolerance_ticks, config.stop_buffer_ticks, config.min_gap_atr,
        config.impulse_atr, config.impulse_body_ratio, config.max_setup_bars,
    )

    def emit(
        family: str, direction: int, index: int, stop: float, source_id: str,
        atr: float, extra: dict[str, float | str | None],
    ) -> None:
        bar = bars[index]
        # This only checks the signal-close geometry, never a future entry.
        if direction * (bar.close - stop) <= 0:
            return
        confirmed_at = bar.time + duration
        features: dict[str, float | str | None] = {
            "detector_version": DETECTOR_VERSION,
            "atr": atr,
            "body_ratio": _body_ratio(bar),
            "range_atr": (bar.high - bar.low) / atr,
            "signal_spread": bar.spread,
            "signal_close": bar.close,
            **extra,
        }
        output.append(Candidate(
            id=_identity(rule_id, family, direction, source_id, confirmed_at.isoformat()),
            symbol=config.symbol, timeframe=config.timeframe, family=family,
            direction=direction, confirmed_at=confirmed_at, bar_index=index,
            stop=stop, source_id=source_id, features=features,
        ))

    for index, bar in enumerate(bars):
        if index and bar.time - bars[index - 1].time != duration:
            segment_start = index
            ranges.clear()
            range_sum = 0.0
            previous_middle_atr = None
            high_pool = low_pool = None
            gaps.clear()
            breaks.clear()

        atr = range_sum / config.atr_period if len(ranges) == config.atr_period else None
        if atr is not None and atr <= 0:
            atr = None

        # Right-side confirmation must be entirely closed BEFORE this bar opens.
        pivot = index - config.pivot_right - 1
        if pivot - config.pivot_left >= segment_start:
            center = bars[pivot]
            neighbors = (
                bars[pivot - config.pivot_left:pivot]
                + bars[pivot + 1:pivot + config.pivot_right + 1]
            )
            if all(center.high > neighbor.high for neighbor in neighbors):
                high_pool = _Pool(pivot, center.high, _identity(
                    rule_id, "PIVOT_HIGH", center.time.isoformat(), center.high,
                ))
            if all(center.low < neighbor.low for neighbor in neighbors):
                low_pool = _Pool(pivot, center.low, _identity(
                    rule_id, "PIVOT_LOW", center.time.isoformat(), center.low,
                ))

        # Existing zones are evaluated before formation/breaks on this bar.
        surviving_gaps: list[_Gap] = []
        for gap in gaps:
            if index - gap.index > config.max_setup_bars:
                continue
            traversed = bar.low <= gap.lower if gap.direction == 1 else bar.high >= gap.upper
            if traversed:
                continue
            touched = bar.low <= gap.upper and bar.high >= gap.lower
            if not touched:
                surviving_gaps.append(gap)
                continue
            midpoint = (gap.lower + gap.upper) / 2
            reacted = gap.direction * (bar.close - bar.open) > 0 and gap.direction * (bar.close - midpoint) > 0
            if reacted and atr is not None:
                stop = gap.lower - buffer if gap.direction == 1 else gap.upper + buffer
                penetration = gap.upper - bar.low if gap.direction == 1 else bar.high - gap.lower
                emit("FVG_FIRST_RETEST", gap.direction, index, stop, gap.source_id, atr, {
                    "zone_lower": gap.lower, "zone_upper": gap.upper,
                    "gap_atr": (gap.upper - gap.lower) / gap.formation_atr,
                    "impulse_body_atr": gap.impulse_body_atr,
                    "age_bars": float(index - gap.index),
                    "fill_fraction": penetration / (gap.upper - gap.lower),
                })
            # A rejected first contact never becomes a later "first" retest.
        gaps = surviving_gaps

        for direction, event in list(breaks.items()):
            if index - event.index > config.max_setup_bars or direction * (bar.close - event.level) < -tolerance:
                del breaks[direction]
                continue
            touched = bar.low <= event.level + tolerance and bar.high >= event.level - tolerance
            if not touched:
                continue
            if direction * (bar.close - event.level) > 0 and direction * (bar.close - bar.open) > 0 and atr is not None:
                stop = bar.low - buffer if direction == 1 else bar.high + buffer
                emit("BREAK_RETEST", direction, index, stop, event.source_id, atr, {
                    "level": event.level, "age_bars": float(index - event.index),
                    "break_strength_atr": event.strength_atr,
                })
            del breaks[direction]

        for pool, sweep_direction in ((low_pool, 1), (high_pool, -1)):
            if pool is None:
                continue
            extreme = bar.low if sweep_direction == 1 else bar.high
            breached = sweep_direction * (pool.price - extreme) > tolerance
            reclaimed = sweep_direction * (bar.close - pool.price) > 0
            if breached and not pool.consumed_sweep:
                pool.consumed_sweep = True
                if reclaimed and atr is not None:
                    stop = extreme - sweep_direction * buffer
                    emit("SWEEP_RECLAIM", sweep_direction, index, stop, pool.source_id, atr, {
                        "level": pool.price,
                        "sweep_depth_atr": abs(extreme - pool.price) / atr,
                        "pool_age_bars": float(index - pool.index),
                    })
            direction = -sweep_direction
            if direction * (bar.close - pool.price) > tolerance:
                pool.consumed_sweep = True
                if not pool.consumed_break:
                    pool.consumed_break = True
                    # A warmup break is consumed but cannot seed a later setup.
                    if atr is not None:
                        breaks[direction] = _Break(
                            index, direction, pool.price,
                            _identity(pool.source_id, "CLOSED_BREAK", bar.time.isoformat()),
                            direction * (bar.close - pool.price) / atr,
                        )

        if index - segment_start >= 2 and previous_middle_atr is not None and previous_middle_atr > 0:
            first, middle = bars[index - 2], bars[index - 1]
            impulse = abs(middle.close - middle.open) / previous_middle_atr
            if impulse >= config.impulse_atr and _body_ratio(middle) >= config.impulse_body_ratio:
                for direction, lower, upper in (
                    (1, first.high, bar.low), (-1, bar.high, first.low),
                ):
                    if direction * (middle.close - middle.open) <= 0:
                        continue
                    if upper - lower > 0 and upper - lower >= config.min_gap_atr * previous_middle_atr:
                        gaps.append(_Gap(
                            index, direction, lower, upper,
                            _identity(rule_id, "FVG", direction, first.time.isoformat(), bar.time.isoformat(), lower, upper),
                            previous_middle_atr, impulse,
                        ))

        previous_close = bars[index - 1].close if index > segment_start else bar.open
        true_range = max(bar.high - bar.low, abs(bar.high - previous_close), abs(bar.low - previous_close))
        if len(ranges) == config.atr_period:
            range_sum -= ranges[0]
        ranges.append(true_range)
        range_sum += true_range
        previous_middle_atr = atr

    return output
