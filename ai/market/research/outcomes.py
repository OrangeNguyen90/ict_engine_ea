"""Label offline candidates with explicit, conservative bid/ask execution.

MT5 exported OHLC is treated as bid.  Its per-candle spread is a constant
ask proxy within that candle, not a reconstruction of historical ticks.
These labels therefore describe a bar simulation, not executable fills.
"""
from copy import deepcopy
from datetime import timedelta
import math

from .types import Bar, Candidate, ResearchConfig


RESOLVED_LABELS = frozenset({"TP_FIRST", "SL_FIRST", "TIMEOUT"})


def _record(candidate: Candidate, config: ResearchConfig) -> dict:
    return {
        "candidate_id": candidate.id,
        "family": candidate.family,
        "symbol": candidate.symbol,
        "timeframe": candidate.timeframe,
        "direction": candidate.direction,
        "as_of": candidate.confirmed_at.isoformat(),
        "source_id": candidate.source_id,
        "entry_at": None,
        "label_end": None,
        "label": "CENSORED",
        "reason": None,
        "entry": None,
        "stop": candidate.stop,
        "target": None,
        "entry_spread": None,
        "risk_price": None,
        "target_r": config.target_r,
        "planned_net_target_r": None,
        "planned_net_stop_r": None,
        "planned_net_reward_risk": None,
        "exit_price": None,
        "gross_r": None,
        "net_r": None,
        "conservative_net_r": None,
        "optimistic_net_r": None,
        "features": deepcopy(candidate.features),
        "cost_assumptions": {
            "spread_model": "bid OHLC + constant per-bar spread ask proxy",
            "slippage_ticks_each_side": config.slippage_ticks,
            "commission_round_trip_r": config.commission_r,
            "target_basis": "gross R from actual market entry to proposed stop",
        },
    }


def evaluate_candidates(
    bars: list[Bar], candidates: list[Candidate], config: ResearchConfig,
) -> list[dict]:
    """Keep every candidate, including missing data and invalid entry plans.

    Enter only at the next contiguous candle's open.  A gap in the history
    prevents observing an unresolved trade and censors it.  Ordinary price
    jumps across a stop at a *contiguous* open fill at that worse open.
    When both barriers occur within one candle OHLC cannot order them: keep
    the adverse stop result separately and do not assign a win or net R.
    """
    step = timedelta(seconds=config.timeframe_seconds)
    slippage = config.slippage_ticks * config.tick_size
    for index, bar in enumerate(bars):
        if bar.time.tzinfo is None or bar.time.utcoffset() is None:
            raise ValueError("bar timestamps must be timezone-aware")
        if index and bar.time <= bars[index - 1].time:
            raise ValueError("bars must be in strictly increasing time order")
        values = (bar.open, bar.high, bar.low, bar.close, bar.spread)
        if not all(math.isfinite(value) for value in values):
            raise ValueError("bar prices and spreads must be finite")
        if bar.spread < 0 or bar.low > min(bar.open, bar.close) or bar.high < max(bar.open, bar.close) or bar.low > bar.high:
            raise ValueError("invalid OHLC or spread")

    results = []
    for candidate in candidates:
        record = _record(candidate, config)
        results.append(record)
        index = candidate.bar_index
        if (candidate.symbol != config.symbol or candidate.timeframe != config.timeframe
                or candidate.direction not in (-1, 1)
                or isinstance(index, bool) or not isinstance(index, int)
                or index < 0 or index >= len(bars)
                or not math.isfinite(candidate.stop)
                or candidate.confirmed_at.tzinfo is None
                or candidate.confirmed_at.utcoffset() is None):
            record.update(label="INVALID_PLAN", reason="invalid_candidate")
            continue
        if candidate.confirmed_at != bars[index].time + step:
            record.update(label="INVALID_PLAN", reason="confirmation_must_equal_bar_close")
            continue
        if index + 1 >= len(bars):
            record["reason"] = "no_entry_bar"
            continue
        entry_bar = bars[index + 1]
        if entry_bar.time != candidate.confirmed_at:
            record["reason"] = "missing_entry_bar"
            continue

        direction = candidate.direction
        entry = entry_bar.open + entry_bar.spread + slippage if direction == 1 else entry_bar.open - slippage
        risk = direction * (entry - candidate.stop)
        record.update(entry_at=entry_bar.time.isoformat(), entry=entry, entry_spread=entry_bar.spread)
        if not math.isfinite(risk) or risk <= 0:
            record.update(label="INVALID_PLAN", reason="stop_wrong_side_of_actual_entry")
            continue
        target = entry + direction * config.target_r * risk
        record.update(risk_price=risk, target=target)

        def net_at(exit_price: float) -> float:
            return direction * (exit_price - entry) / risk - config.commission_r

        planned_win = net_at(target - direction * slippage)
        planned_loss = net_at(candidate.stop - direction * slippage)
        record.update(planned_net_target_r=planned_win, planned_net_stop_r=planned_loss,
                      planned_net_reward_risk=planned_win / abs(planned_loss))

        def finish(label: str, bar: Bar, price: float, reason: str) -> None:
            # Entry slippage is already part of entry; apply exit slippage once.
            fill = price - direction * slippage
            gross_r = direction * (fill - entry) / risk
            net_r = gross_r - config.commission_r
            record.update(label=label, reason=reason, label_end=(bar.time + step).isoformat(),
                          exit_price=fill, gross_r=gross_r, net_r=net_r, conservative_net_r=net_r)

        expected = entry_bar.time
        for holding_index in range(config.horizon_bars):
            future_index = index + 1 + holding_index
            if future_index >= len(bars):
                record["reason"] = "incomplete_horizon"
                break
            future = bars[future_index]
            if future.time != expected:
                record["reason"] = "missing_bar_during_horizon"
                break
            expected += step
            record["label_end"] = (future.time + step).isoformat()
            # Long closes sell at bid; short closes buy at the ask proxy.
            offset = 0.0 if direction == 1 else future.spread
            opening = future.open + offset
            high, low = future.high + offset, future.low + offset
            stop_at_open = opening <= candidate.stop if direction == 1 else opening >= candidate.stop
            tp_at_open = opening >= target if direction == 1 else opening <= target
            if stop_at_open:
                finish("SL_FIRST", future, opening, "stop_crossed_at_open")
                break
            if tp_at_open:
                finish("TP_FIRST", future, target, "target_crossed_at_open_capped")
                break
            stop_hit = low <= candidate.stop if direction == 1 else high >= candidate.stop
            tp_hit = high >= target if direction == 1 else low <= target
            if stop_hit and tp_hit:
                record.update(label="AMBIGUOUS", reason="both_barriers_in_same_bar",
                              conservative_net_r=net_at(candidate.stop - direction * slippage),
                              optimistic_net_r=net_at(target - direction * slippage))
                break
            if stop_hit:
                finish("SL_FIRST", future, candidate.stop, "stop_touched")
                break
            if tp_hit:
                finish("TP_FIRST", future, target, "target_touched")
                break
            if holding_index == config.horizon_bars - 1:
                finish("TIMEOUT", future, future.close + offset, "horizon_close")
                break
    return results
