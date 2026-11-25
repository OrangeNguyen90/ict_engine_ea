"""Confirmation-time candle windows for optional offline neural research.

These flattened, normalized sequences can feed a deep feedforward MLP. They
are not an LSTM or Transformer, and their availability implies no advantage
over tabular models. Missing history is explicit; no candle is invented.
"""

from copy import deepcopy
from datetime import timedelta
import math

from .types import Bar
from .validation import _time


def _finite_number(value) -> bool:
    return (isinstance(value, (int, float)) and not isinstance(value, bool)
            and math.isfinite(value))


def attach_sequences(records: list[dict], bars: list[Bar], *, window: int,
                     timeframe_seconds: int) -> list[dict]:
    """Copy records and attach only closed, contiguous confirmation windows.

    A confirmation at ``as_of`` must equal the final candle's open plus one
    timeframe. Every window ends at that candle, before the entry candle.
    ATR comes exclusively from the detector's confirmation-time ``features``.

    Each candle contributes five values, oldest first: direction-normalized
    open, favorable extreme, adverse extreme and close relative to the last
    known close, then spread; all are divided by confirmation-time ATR. For
    shorts the favorable extreme is the low, and the adverse extreme is the
    high. Reflecting prices and reversing direction therefore preserves the
    representation. Volume, entry prices and outcome fields are never read.

    Unavailable/invalid windows have ``sequence_features=None`` and a reason
    in ``sequence_status``. They must be excluded by the sequence model,
    rather than imputed as a synthetic all-zero price path.
    """
    for name, value in (("window", window), ("timeframe_seconds", timeframe_seconds)):
        if isinstance(value, bool) or not isinstance(value, int) or value < 1:
            raise ValueError(f"{name} must be a positive integer")

    step = timedelta(seconds=timeframe_seconds)
    by_confirmation = {}
    for index, bar in enumerate(bars):
        if bar.time.tzinfo is None or bar.time.utcoffset() is None:
            raise ValueError("bar timestamps must be timezone-aware")
        if index and bar.time <= bars[index - 1].time:
            raise ValueError("bars must be in strictly increasing time order")
        by_confirmation[bar.time + step] = index

    output = []
    for source in records:
        record = deepcopy(source)
        output.append(record)
        record["sequence_features"] = None
        record["sequence_status"] = "MISSING_CONFIRMATION_BAR"
        end = by_confirmation.get(_time(record["as_of"]))
        if end is None:
            continue
        start = end - window + 1
        if start < 0:
            record["sequence_status"] = "INSUFFICIENT_HISTORY"
            continue
        candles = bars[start:end + 1]
        if any(current.time - previous.time != step
               for previous, current in zip(candles, candles[1:])):
            record["sequence_status"] = "GAP_IN_WINDOW"
            continue

        features = record.get("features")
        atr = features.get("atr") if isinstance(features, dict) else None
        if not _finite_number(atr) or atr <= 0:
            record["sequence_status"] = "INVALID_ATR"
            continue
        direction = record.get("direction")
        if isinstance(direction, bool) or direction not in (-1, 1):
            record["sequence_status"] = "INVALID_DIRECTION"
            continue
        if any(not all(_finite_number(value) for value in
                       (bar.open, bar.high, bar.low, bar.close, bar.spread))
               or bar.spread < 0 or bar.low > min(bar.open, bar.close)
               or bar.high < max(bar.open, bar.close) or bar.low > bar.high
               for bar in candles):
            record["sequence_status"] = "INVALID_BAR_VALUES"
            continue

        anchor = candles[-1].close
        vector = []
        for bar in candles:
            favorable = bar.high if direction == 1 else bar.low
            adverse = bar.low if direction == 1 else bar.high
            vector.extend(direction * (value - anchor) / atr
                          for value in (bar.open, favorable, adverse, bar.close))
            vector.append(bar.spread / atr)
        if not all(math.isfinite(value) for value in vector):
            record["sequence_status"] = "INVALID_BAR_VALUES"
            continue
        record["sequence_features"] = vector
        record["sequence_status"] = "READY"
    return output
