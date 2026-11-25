"""Strict file ingestion without Django, database writes, or invented candles."""
import csv
from datetime import datetime, timedelta, timezone
import hashlib
import json
import math
from pathlib import Path
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from .types import Bar, TIMEFRAME_SECONDS


def file_digest(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_time(value, *, source_timezone=None, utc_offset_minutes=None):
    stamp = datetime.fromisoformat(str(value).strip().replace("Z", "+00:00"))
    if stamp.tzinfo is not None and stamp.utcoffset() is not None:
        return stamp.astimezone(timezone.utc)
    if source_timezone is not None and utc_offset_minutes is not None:
        raise ValueError("choose source timezone or fixed UTC offset, not both")
    if utc_offset_minutes is not None:
        if not -840 <= utc_offset_minutes <= 840:
            raise ValueError("UTC offset must be between -840 and 840 minutes")
        return stamp.replace(tzinfo=timezone(timedelta(minutes=utc_offset_minutes))).astimezone(timezone.utc)
    if not source_timezone:
        raise ValueError("naive broker time requires an explicit historical timezone or UTC offset")
    try:
        zone = ZoneInfo(source_timezone)
    except ZoneInfoNotFoundError as exc:
        raise ValueError("timezone unavailable; install tzdata or supply a verified UTC offset") from exc
    possible = set()
    for fold in (0, 1):
        utc = stamp.replace(tzinfo=zone, fold=fold).astimezone(timezone.utc)
        if utc.astimezone(zone).replace(tzinfo=None) == stamp:
            possible.add(utc)
    if len(possible) != 1:
        raise ValueError("ambiguous or nonexistent broker-local timestamp; export explicit offsets")
    return possible.pop()


def _number(value, name, *, positive=False):
    try:
        result = float(value)
    except (ValueError, TypeError) as exc:
        raise ValueError(f"invalid {name}") from exc
    if not math.isfinite(result) or result < 0 or (positive and result <= 0):
        raise ValueError(f"{name} must be finite and {'positive' if positive else 'nonnegative'}")
    return result


def load_dataset(csv_path, *, metadata_path=None, source_timezone=None,
                 utc_offset_minutes=None, price_type=None, as_of=None,
                 allow_partial=False, require_verified_bid=True):
    """Return immutable UTC bars plus an inspectable quality/provenance receipt.

    Unclassified gaps delimit independent segments. No assertion that a missing
    interval is an exchange closure or that a bar spread is a tick Ask path.
    """
    csv_path = Path(csv_path)
    sidecar = Path(metadata_path) if metadata_path else Path(str(csv_path) + ".meta.json")
    metadata = json.loads(sidecar.read_text(encoding="utf-8-sig"))
    if metadata.get("schema_version") != 1:
        raise ValueError("research export metadata schema_version=1 is required")
    if metadata.get("csv_file") != csv_path.name:
        raise ValueError("metadata CSV filename does not match source file")
    declared_bytes = metadata.get("csv_bytes")
    if declared_bytes is not None and (isinstance(declared_bytes, bool)
                                       or not isinstance(declared_bytes, int)
                                       or declared_bytes != csv_path.stat().st_size):
        raise ValueError("CSV byte size does not match manifest")
    symbol, timeframe = metadata.get("symbol", ""), metadata.get("timeframe", "")
    if not isinstance(symbol, str) or not symbol.strip() or timeframe not in TIMEFRAME_SECONDS:
        raise ValueError("metadata needs symbol and a supported timeframe")
    seconds = TIMEFRAME_SECONDS[timeframe]
    if metadata.get("timeframe_seconds") != seconds:
        raise ValueError("metadata timeframe_seconds does not match timeframe")
    if metadata.get("complete") is not True and not allow_partial:
        raise ValueError("export incomplete: obtain a complete export or explicitly use --allow-partial")
    declared_type = metadata.get("price_type", "unknown")
    if declared_type not in ("unknown", "bid", "last"):
        raise ValueError("invalid metadata price type")
    if price_type is not None and declared_type != price_type:
        raise ValueError("price type override conflicts with exporter metadata")
    if require_verified_bid and (declared_type != "bid"
                                 or metadata.get("price_type_historically_verified") is not True):
        raise ValueError("outcome evaluation requires historically verified Bid OHLC")
    point = _number(metadata.get("point"), "point", positive=True)
    tick = _number(metadata.get("tick_size"), "tick_size", positive=True)
    if source_timezone is not None and utc_offset_minutes is not None:
        raise ValueError("choose source timezone or fixed UTC offset, not both")
    if as_of is None:
        raw_cutoff = metadata.get("effective_end") or metadata.get("requested_end_exclusive")
        if not raw_cutoff:
            raise ValueError("metadata needs effective_end or requested_end_exclusive for a reproducible cutoff")
        cutoff = parse_time(raw_cutoff, source_timezone=source_timezone,
                            utc_offset_minutes=utc_offset_minutes)
    else:
        cutoff = as_of
    if cutoff.tzinfo is None or cutoff.utcoffset() is None:
        raise ValueError("as_of must include timezone")
    cutoff = cutoff.astimezone(timezone.utc)
    digest = file_digest(csv_path)
    if metadata.get("csv_sha256") and metadata["csv_sha256"] != digest:
        raise ValueError("CSV hash does not match manifest")
    bars, gaps = [], []
    previous = None
    first_source = last_source = None
    read = dropped = 0
    with csv_path.open("r", encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream)
        required = {"timestamp", "open", "high", "low", "close", "volume", "spread_points"}
        if not required.issubset(reader.fieldnames or []):
            raise ValueError("CSV requires timestamp, OHLC, volume and historical spread_points")
        for line, row in enumerate(reader, 2):
            read += 1
            try:
                stamp = parse_time(row["timestamp"], source_timezone=source_timezone,
                                   utc_offset_minutes=utc_offset_minutes)
                if previous is not None and stamp <= previous:
                    raise ValueError("duplicate or out-of-order candle timestamp")
                if previous is not None and (stamp - previous).total_seconds() < seconds:
                    raise ValueError("overlapping candle intervals")
                previous = stamp
                if first_source is None:
                    first_source = stamp
                last_source = stamp
                prices = [_number(row[name], name, positive=True) for name in ("open", "high", "low", "close")]
                opening, high, low, close = prices
                if high < max(opening, low, close) or low > min(opening, high, close):
                    raise ValueError("invalid OHLC bounds")
                volume = _number(row["volume"], "volume")
                spread = _number(row["spread_points"], "spread_points") * point
                if stamp + timedelta(seconds=seconds) > cutoff:
                    dropped += 1
                    continue
                if bars and (stamp - bars[-1].time).total_seconds() != seconds:
                    gaps.append({"after": bars[-1].time.isoformat(), "before": stamp.isoformat(),
                                 "seconds_between_opens": (stamp - bars[-1].time).total_seconds(),
                                 "classification": "UNCLASSIFIED"})
                bars.append(Bar(stamp, opening, high, low, close, spread, volume))
            except (ValueError, TypeError) as exc:
                raise ValueError(f"CSV line {line}: {exc}") from exc
    expected = metadata.get("count")
    if isinstance(expected, bool) or not isinstance(expected, int) or expected != read:
        raise ValueError("CSV row count does not match manifest")
    for key, observed in (("actual_first", first_source), ("actual_last", last_source)):
        declared = metadata.get(key)
        if declared is not None and parse_time(declared, source_timezone=source_timezone,
                                                utc_offset_minutes=utc_offset_minutes) != observed:
            raise ValueError(f"CSV {key} does not match manifest")
    if not bars:
        raise ValueError("no usable closed candles")
    warnings = [
        ("Bar spread is an Ask-path proxy; intrabar spread and fills are unverified."
         if declared_type == "bid" else
         "Historical price type is not verified Bid; execution outcomes are unavailable."),
        "Gaps are unclassified; state resets and unresolved outcomes are censored.",
        "No claim of parity with the production MQL ICT engine.",
    ]
    if metadata.get("complete") is not True:
        warnings.append("Explicit partial-export override: requested history coverage is not established.")
    if utc_offset_minutes is not None:
        warnings.append("Fixed historical offset supplied by operator; DST correctness is not independently verified.")
    quality = {"rows_read": read, "closed_bars": len(bars), "dropped_unclosed": dropped,
               "first_open_utc": bars[0].time.isoformat(), "last_open_utc": bars[-1].time.isoformat(),
               "as_of_utc": cutoff.isoformat(), "gap_count": len(gaps), "gap_examples": gaps[:50],
               "zero_spread_bars": sum(bar.spread == 0 for bar in bars),
               "coverage_verified": metadata.get("coverage_verified") is True,
               "export_complete": metadata.get("complete") is True, "warnings": warnings}
    manifest = {"schema_version": 1, "symbol": symbol, "timeframe": timeframe,
                "timeframe_seconds": seconds, "point": point, "tick_size": tick,
                "price_type": declared_type,
                "price_type_historically_verified": metadata.get("price_type_historically_verified") is True,
                "csv_sha256": digest,
                "metadata_sha256": file_digest(sidecar), "source_timezone": source_timezone,
                "utc_offset_minutes": utc_offset_minutes, "export_metadata": metadata,
                "quality": quality}
    return bars, manifest
