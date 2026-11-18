"""Market data validation, import, and aggregation primitives."""
import csv
import hashlib
from datetime import datetime, timezone as dt_timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from django.db import transaction
from .models import ImportBatch, MarketCandle
from .timeframes import TIMEFRAME_DELTAS


def validate_ohlcv(row):
    values = {}
    for field in ("open", "high", "low", "close"):
        try:
            values[field] = Decimal(str(row[field]))
        except (KeyError, InvalidOperation, TypeError):
            raise ValueError(f"{field} must be a finite decimal")
        if not values[field].is_finite():
            raise ValueError(f"{field} must be finite")
    if values["high"] < max(values["open"], values["close"], values["low"]):
        raise ValueError("high must be at least open, close, and low")
    if values["low"] > min(values["open"], values["close"], values["high"]):
        raise ValueError("low must be at most open, close, and high")
    if row.get("volume") not in (None, ""):
        try:
            volume = Decimal(str(row["volume"]))
        except (InvalidOperation, TypeError):
            raise ValueError("volume must be a nonnegative finite decimal")
        if not volume.is_finite() or volume < 0:
            raise ValueError("volume must be a nonnegative finite decimal")
        values["volume"] = volume
    else:
        values["volume"] = None
    return values


def parse_timestamp(value, source_timezone="UTC"):
    try:
        parsed = datetime.fromisoformat(value.strip().replace("Z", "+00:00"))
        zone = ZoneInfo(source_timezone)
    except (ValueError, ZoneInfoNotFoundError, AttributeError):
        raise ValueError("timestamp or source timezone is invalid")
    if parsed.tzinfo is None:
        candidates = [parsed.replace(tzinfo=zone, fold=fold) for fold in (0, 1)]
        valid = [candidate for candidate in candidates
                 if candidate.astimezone(dt_timezone.utc).astimezone(zone).replace(tzinfo=None) == parsed]
        if not valid:
            raise ValueError("local timestamp does not exist because of a DST transition")
        if len(valid) == 2 and valid[0].utcoffset() != valid[1].utcoffset():
            raise ValueError("ambiguous local timestamp during DST transition; provide an offset")
        parsed = valid[0]
    return parsed.astimezone(dt_timezone.utc)


def _row_to_record(row, defaults, source_timezone):
    aliases = {"timestamp": ("timestamp", "time", "datetime", "date")}
    normalized = {str(k).strip().lower(): v for k, v in row.items()}
    stamp = next((normalized.get(name) for name in aliases["timestamp"] if normalized.get(name)), None)
    if not stamp:
        raise ValueError("timestamp column is required")
    merged = {**defaults, **normalized}
    values = validate_ohlcv(merged)
    timeframe = str(merged.get("timeframe", "")).strip().upper()
    if timeframe not in TIMEFRAME_DELTAS:
        raise ValueError("unsupported timeframe")
    for field in ("symbol", "exchange", "data_source"):
        if not str(merged.get(field, "")).strip():
            raise ValueError(f"{field} is required")
    return {
        "symbol": str(merged["symbol"]).strip().upper(),
        "exchange": str(merged["exchange"]).strip(),
        "contract": str(merged.get("contract", "")).strip(),
        "timestamp": parse_timestamp(str(stamp), source_timezone),
        "timeframe": timeframe, **values,
        "volume_type": merged.get("volume_type") or "unknown",
        "data_source": str(merged["data_source"]).strip(),
        "price_type": merged.get("price_type") or "trade",
    }


@transaction.atomic
def import_market_file(path, *, symbol, exchange, timeframe, data_source,
                       source_timezone="UTC", contract="", volume_type="unknown",
                       price_type="trade", update_existing=False):
    path = Path(path)
    suffix = path.suffix.lower()
    if suffix == ".csv":
        with path.open("r", newline="", encoding="utf-8-sig") as stream:
            rows = list(csv.DictReader(stream))
    elif suffix in (".parquet", ".pq"):
        try:
            import pandas as pd
        except ImportError as exc:
            raise ValueError("Parquet import requires pandas and pyarrow") from exc
        rows = pd.read_parquet(path).to_dict(orient="records")
    else:
        raise ValueError("Only CSV and Parquet files are supported")
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    batch = ImportBatch.objects.create(source_file=path.name, file_sha256=digest, data_source=data_source, rows_read=len(rows))
    defaults = dict(symbol=symbol, exchange=exchange, timeframe=timeframe, data_source=data_source,
                    contract=contract, volume_type=volume_type, price_type=price_type)
    created = updated = skipped = 0
    warnings = []
    for line, row in enumerate(rows, start=2):
        try:
            record = _row_to_record(row, defaults, source_timezone)
            lookup = {key: record[key] for key in ("symbol", "exchange", "contract", "timestamp", "timeframe", "data_source", "price_type")}
            candle = MarketCandle.objects.filter(**lookup).first()
            if candle is not None:
                if update_existing:
                    for key, value in record.items():
                        setattr(candle, key, value)
                    candle.provenance = batch
                    candle.save()
                    updated += 1
                else:
                    skipped += 1
                continue
            MarketCandle.objects.create(**record, provenance=batch)
            created += 1
        except (ValueError, TypeError) as exc:
            warnings.append(f"row {line}: {exc}")
    batch.rows_created, batch.rows_updated, batch.rows_skipped, batch.warnings = created, updated, skipped, warnings
    batch.save(update_fields=["rows_created", "rows_updated", "rows_skipped", "warnings"])
    return batch


def resample_candles(candles, target_timeframe, *, calendar=None):
    """Aggregate complete, aligned buckets only. Input rows must be chronological."""
    if target_timeframe not in TIMEFRAME_DELTAS:
        raise ValueError("unsupported target timeframe")
    rows = sorted(candles, key=lambda row: row["timestamp"])
    if not rows:
        return []
    # Calendar-sensitive daily/weekly/monthly buckets require a session calendar.
    if target_timeframe in ("D1", "W1", "MN1") and calendar is None:
        raise ValueError("daily and larger resampling requires an explicit session calendar")
    buckets = {}
    for row in rows:
        key = calendar.bucket_open(row["timestamp"], target_timeframe) if calendar else _fixed_bucket(row["timestamp"], target_timeframe)
        buckets.setdefault(key, []).append(row)
    result = []
    for start, members in sorted(buckets.items()):
        expected = calendar.expected_opens(start, target_timeframe) if calendar else None
        if expected is not None and [item["timestamp"] for item in members] != list(expected):
            continue
        if expected is None:
            source_steps = [b["timestamp"] - a["timestamp"] for a, b in zip(members, members[1:])]
            source_delta = source_steps[0] if source_steps and all(step == source_steps[0] for step in source_steps) else None
            target_delta = TIMEFRAME_DELTAS[target_timeframe]
            if target_delta is not None:
                if source_delta is None or target_delta.total_seconds() % source_delta.total_seconds() != 0:
                    continue
                count = int(target_delta.total_seconds() / source_delta.total_seconds())
                if len(members) != count:
                    continue
                if any(b["timestamp"] - a["timestamp"] != source_delta for a, b in zip(members, members[1:])):
                    continue
        result.append({
            "timestamp": start, "timeframe": target_timeframe,
            "open": members[0]["open"], "high": max(x["high"] for x in members),
            "low": min(x["low"] for x in members), "close": members[-1]["close"],
            "volume": None if any(x.get("volume") is None for x in members) else sum((x["volume"] for x in members), Decimal(0)),
            "source_timestamps": [x["timestamp"] for x in members],
        })
    return result


def _fixed_bucket(timestamp, timeframe):
    from datetime import timedelta
    delta = TIMEFRAME_DELTAS[timeframe]
    seconds = int(delta.total_seconds())
    epoch = int(timestamp.timestamp())
    return datetime.fromtimestamp(epoch - epoch % seconds, tz=dt_timezone.utc)
