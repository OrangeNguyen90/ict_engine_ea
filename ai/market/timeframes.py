from datetime import timedelta

TIMEFRAME_DELTAS = {
    "M1": timedelta(minutes=1), "M5": timedelta(minutes=5),
    "M15": timedelta(minutes=15), "H1": timedelta(hours=1),
    "H4": timedelta(hours=4), "D1": timedelta(days=1),
    "W1": timedelta(weeks=1), "MN1": None,
}


def expected_next(timestamp, timeframe, calendar=None):
    """Return next expected UTC open; calendar may omit market-closed periods."""
    if timeframe not in TIMEFRAME_DELTAS:
        raise ValueError(f"Unsupported timeframe: {timeframe}")
    if calendar:
        return calendar.next_open(timestamp, timeframe)
    delta = TIMEFRAME_DELTAS[timeframe]
    if delta is None:
        month = timestamp.month % 12 + 1
        year = timestamp.year + (timestamp.month == 12)
        from datetime import datetime, timezone
        return datetime(year, month, 1, tzinfo=timezone.utc)
    return timestamp + delta


def detect_missing_candles(timestamps, timeframe, calendar=None):
    """Report absent expected opens; never fabricates candle data."""
    ordered = sorted(set(timestamps))
    missing = []
    for left, right in zip(ordered, ordered[1:]):
        candidate = expected_next(left, timeframe, calendar)
        while candidate is not None and candidate < right:
            missing.append(candidate)
            following = expected_next(candidate, timeframe, calendar)
            if following is None or following <= candidate:
                break
            candidate = following
    return missing
