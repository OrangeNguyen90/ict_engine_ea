"""Strict, non-executable advisory snapshots for an independently pinned model.

The ASCII wire format contains one complete line with 22 semicolon-separated
fields. It transports research predictions only, never models or order rights.
Writers replace a file atomically; readers still validate freshness and pins.
"""

from datetime import datetime, timezone
import math
import os
from pathlib import Path
import re
import tempfile

from .types import TIMEFRAME_SECONDS


PROTOCOL = "ICTML1"
SCOPE = "RESEARCH_ADVISORY"
MAX_TIMESTAMP = 9_999_999_999
MAX_TRAIN_N = 2_147_483_647
MAX_LINE_LENGTH = 8192
FAMILIES = frozenset({"SWEEP_RECLAIM", "FVG_FIRST_RETEST", "BREAK_RETEST"})
_MODEL_ID = re.compile(r"[0-9a-fA-F]{64}\Z", re.ASCII)
_CANDIDATE_ID = re.compile(r"[0-9a-fA-F]{24}\Z", re.ASCII)
_REASON = re.compile(r"[A-Z][A-Z0-9_]{0,63}\Z", re.ASCII)
_UINT = re.compile(r"[0-9]+\Z", re.ASCII)
_FLOAT = re.compile(r"[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?\Z", re.ASCII)


def _unix(value: datetime, name: str) -> int:
    if not isinstance(value, datetime) or value.tzinfo is None or value.utcoffset() is None:
        raise ValueError(f"{name} must be a timezone-aware datetime")
    try:
        stamp = int(value.astimezone(timezone.utc).timestamp())
    except (OverflowError, OSError, ValueError) as exc:
        raise ValueError(f"invalid {name}") from exc
    return _integer(stamp, name, MAX_TIMESTAMP)


def _iso_unix(value, name: str) -> int:
    if not isinstance(value, str):
        raise ValueError(f"{name} must be a timezone-aware ISO timestamp")
    try:
        stamp = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ValueError(f"invalid {name}") from exc
    return _unix(stamp, name)


def _integer(value, name: str, maximum: int) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or not 0 < value <= maximum:
        raise ValueError(f"{name} must be a positive integer no greater than {maximum}")
    return value


def _number(value, name: str, *, nullable: bool = True):
    if value is None and nullable:
        return None
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f"{name} must be a finite number" + (" or None" if nullable else ""))
    try:
        result = float(value)
    except (OverflowError, ValueError) as exc:
        raise ValueError(f"{name} must be a finite number") from exc
    if not math.isfinite(result):
        raise ValueError(f"{name} must be a finite number")
    return result


def _symbol(value) -> str:
    if (not isinstance(value, str) or not 1 <= len(value) <= 40
            or any(not 33 <= ord(char) <= 126 or char == ";" for char in value)):
        raise ValueError("symbol must be 1 to 40 printable ASCII characters without whitespace or semicolons")
    return value


def _timeframe(value) -> str:
    if not isinstance(value, str) or value not in TIMEFRAME_SECONDS:
        raise ValueError("unsupported timeframe")
    return value


def _model_id(value) -> str:
    if not isinstance(value, str) or _MODEL_ID.fullmatch(value) is None:
        raise ValueError("model_id must contain exactly 64 hexadecimal characters")
    return value


def _validate_source(bundle: dict, symbol: str, timeframe: str) -> None:
    if bundle.get("scope") != SCOPE or bundle.get("execution_allowed") is not False:
        raise ValueError("model bundle must be a research advisory with execution_allowed=False")
    if bundle.get("source_gate") != "VERIFIED":
        raise ValueError("model bundle requires a VERIFIED source")
    source = bundle.get("source")
    quality = source.get("quality") if isinstance(source, dict) else None
    if (not isinstance(source, dict) or not isinstance(quality, dict)
            or source.get("symbol") != symbol or source.get("timeframe") != timeframe
            or source.get("timeframe_seconds") != TIMEFRAME_SECONDS[timeframe]
            or source.get("price_type") != "bid"
            or source.get("price_type_historically_verified") is not True
            or quality.get("export_complete") is not True
            or quality.get("coverage_verified") is not True):
        raise ValueError("model source verification or symbol/timeframe does not match")
    for key in ("point", "tick_size"):
        if _number(source.get(key), f"source.{key}", nullable=False) <= 0:
            raise ValueError(f"source.{key} must be positive")
    if "config" in bundle:
        config = bundle["config"]
        if (not isinstance(config, dict) or config.get("symbol") != symbol
                or config.get("timeframe") != timeframe):
            raise ValueError("model config symbol/timeframe does not match")


def _fields(snapshot: dict) -> list[str]:
    """Validate structure without treating an expired advisory as current."""
    if not isinstance(snapshot, dict) or snapshot.get("protocol") != PROTOCOL:
        raise ValueError("unsupported snapshot protocol")
    model_id = _model_id(snapshot.get("model_id"))
    symbol = _symbol(snapshot.get("symbol"))
    timeframe = _timeframe(snapshot.get("timeframe"))
    times = [_integer(snapshot.get(key), key, MAX_TIMESTAMP)
             for key in ("generated_at", "as_of", "expires_at", "fit_cutoff", "train_end")]
    generated, as_of, expires, cutoff, train_end = times
    if not train_end < cutoff <= as_of:
        raise ValueError("training must end strictly before fit_cutoff, at or before as_of")
    if expires > as_of + TIMEFRAME_SECONDS[timeframe]:
        raise ValueError("expiry cannot outlive the next candle confirmation")
    candidate_id, family, direction = (snapshot.get(key) for key in
                                        ("candidate_id", "family", "direction"))
    if isinstance(direction, bool) or not isinstance(direction, int) or direction not in (-1, 0, 1):
        raise ValueError("direction must be -1, 0 or 1")
    if candidate_id == "-":
        if family != "-" or direction != 0:
            raise ValueError("an absent candidate requires family '-' and direction 0")
    elif (not isinstance(candidate_id, str) or _CANDIDATE_ID.fullmatch(candidate_id) is None
          or not isinstance(family, str) or family not in FAMILIES or direction not in (-1, 1)):
        raise ValueError("candidate identity, family and direction must be coherent")
    status, reason = snapshot.get("status"), snapshot.get("reason")
    if status not in ("SELECTED", "ABSTAIN"):
        raise ValueError("status must be SELECTED or ABSTAIN")
    if not isinstance(reason, str) or _REASON.fullmatch(reason) is None:
        raise ValueError("reason must be an uppercase ASCII token of at most 64 characters")
    target = _number(snapshot.get("selected_target_r"), "selected_target_r")
    expected = _number(snapshot.get("expected_net_r"), "expected_net_r")
    probability = _number(snapshot.get("p_tp"), "p_tp")
    if probability is not None and not 0 <= probability <= 1:
        raise ValueError("p_tp must be between zero and one")
    if status == "SELECTED" and (candidate_id == "-" or target is None or target <= 0 or expected is None):
        raise ValueError("SELECTED requires a candidate, positive target R and expected net R")
    if status == "ABSTAIN" and target is not None:
        raise ValueError("ABSTAIN must not retain a selected target")
    train_n = _integer(snapshot.get("train_n"), "train_n", MAX_TRAIN_N)
    if (snapshot.get("scope") != SCOPE or snapshot.get("execution_allowed") is not False
            or snapshot.get("source_gate") != "VERIFIED"):
        raise ValueError("snapshot must retain research-only scope and a VERIFIED source")

    def token(value):
        return "NA" if value is None else format(value, ".17g")

    return [PROTOCOL, model_id, symbol, timeframe, *(str(value) for value in times),
            candidate_id, family, str(direction), status, reason,
            token(target), token(expected), token(probability), str(train_n),
            SCOPE, "0", "VERIFIED", "END"]


def build_snapshot(bundle: dict, prediction: dict, *, symbol: str, timeframe: str,
                   as_of: datetime, now: datetime, ttl_seconds: int = 60) -> dict:
    """Build an advisory; clock skew or stale data forces explicit abstention.

    Such clock-invalid snapshots remain serializable for diagnostics, but the
    consumer/parser rejects them. Invalid model/source contracts raise rather
    than granting a transport path around source verification.
    """
    if not isinstance(bundle, dict) or not isinstance(prediction, dict):
        raise ValueError("bundle and prediction must be dictionaries")
    symbol, timeframe = _symbol(symbol), _timeframe(timeframe)
    _validate_source(bundle, symbol, timeframe)
    generated, confirmation = _unix(now, "now"), _unix(as_of, "as_of")
    ttl = _integer(ttl_seconds, "ttl_seconds", MAX_TRAIN_N)
    snapshot = {
        "protocol": PROTOCOL, "model_id": _model_id(bundle.get("model_id")),
        "symbol": symbol, "timeframe": timeframe,
        "generated_at": generated, "as_of": confirmation,
        "expires_at": min(generated + ttl, confirmation + TIMEFRAME_SECONDS[timeframe]),
        "fit_cutoff": _iso_unix(bundle.get("fit_cutoff"), "fit_cutoff"),
        "train_end": _iso_unix(bundle.get("train_end"), "train_end"),
        "candidate_id": prediction.get("candidate_id", "-"),
        "family": prediction.get("family", "-"), "direction": prediction.get("direction", 0),
        "status": prediction.get("status"), "reason": prediction.get("reason"),
        "selected_target_r": prediction.get("selected_target_r"),
        "expected_net_r": prediction.get("expected_net_r"), "p_tp": prediction.get("p_tp"),
        "train_n": bundle.get("train_n"), "scope": SCOPE,
        "execution_allowed": False, "source_gate": "VERIFIED",
    }
    _fields(snapshot)
    if generated < confirmation:
        snapshot.update(status="ABSTAIN", reason="CLOCK_BEFORE_ASOF", selected_target_r=None)
    elif generated >= confirmation + TIMEFRAME_SECONDS[timeframe]:
        snapshot.update(status="ABSTAIN", reason="DATA_STALE", selected_target_r=None)
    return snapshot


def serialize_snapshot(snapshot: dict) -> str:
    """Return exactly one ASCII semicolon line, including its LF terminator."""
    return ";".join(_fields(snapshot)) + "\n"


def _parse_uint(value: str, name: str, maximum: int) -> int:
    if (not value or len(value) > len(str(maximum)) or _UINT.fullmatch(value) is None):
        raise ValueError(f"invalid unsigned integer {name}")
    return _integer(int(value), name, maximum)


def _parse_number(value: str, name: str):
    if value == "NA":
        return None
    if len(value) > 64 or _FLOAT.fullmatch(value) is None:
        raise ValueError(f"invalid numeric token {name}")
    return _number(float(value), name, nullable=False)


def parse_snapshot(text: str, *, expected_model_id: str, symbol: str, timeframe: str,
                   as_of: datetime, now: datetime) -> dict:
    """Validate pins, clocks, source/scope, and a complete single-line receipt."""
    expected_model_id = _model_id(expected_model_id)
    symbol, timeframe = _symbol(symbol), _timeframe(timeframe)
    confirmation, current = _unix(as_of, "as_of"), _unix(now, "now")
    if not isinstance(text, str) or len(text) > MAX_LINE_LENGTH or not text.isascii():
        raise ValueError("snapshot must be a bounded ASCII line")
    if text.endswith("\r\n"):
        line = text[:-2]
    elif text.endswith(("\n", "\r")):
        line = text[:-1]
    else:
        raise ValueError("snapshot is incomplete: final line terminator is required")
    if "\r" in line or "\n" in line:
        raise ValueError("snapshot must contain exactly one line")
    fields = line.split(";")
    if len(fields) != 22 or fields[0] != PROTOCOL or fields[21] != "END":
        raise ValueError("snapshot field count or framing is invalid")
    if fields[18:21] != [SCOPE, "0", "VERIFIED"]:
        raise ValueError("snapshot cannot permit execution or bypass source verification")
    if fields[11] not in ("-1", "0", "1"):
        raise ValueError("invalid direction token")
    snapshot = {
        "protocol": fields[0], "model_id": fields[1], "symbol": fields[2], "timeframe": fields[3],
        **{key: _parse_uint(fields[index], key, MAX_TIMESTAMP)
           for index, key in enumerate(("generated_at", "as_of", "expires_at", "fit_cutoff", "train_end"), 4)},
        "candidate_id": fields[9], "family": fields[10], "direction": int(fields[11]),
        "status": fields[12], "reason": fields[13],
        "selected_target_r": _parse_number(fields[14], "selected_target_r"),
        "expected_net_r": _parse_number(fields[15], "expected_net_r"),
        "p_tp": _parse_number(fields[16], "p_tp"),
        "train_n": _parse_uint(fields[17], "train_n", MAX_TRAIN_N),
        "scope": fields[18], "execution_allowed": False, "source_gate": fields[20],
    }
    _fields(snapshot)
    if (snapshot["model_id"] != expected_model_id or snapshot["symbol"] != symbol
            or snapshot["timeframe"] != timeframe or snapshot["as_of"] != confirmation):
        raise ValueError("snapshot model, symbol, timeframe or confirmation pin does not match")
    if current < confirmation or snapshot["generated_at"] < confirmation:
        raise ValueError("snapshot precedes its confirmation")
    if snapshot["generated_at"] > current + 5:
        raise ValueError("snapshot generation clock is more than five seconds ahead")
    if (snapshot["expires_at"] <= snapshot["generated_at"]
            or current >= snapshot["expires_at"]):
        raise ValueError("snapshot is stale or has an invalid lifetime")
    return snapshot


def atomic_write_snapshot(path, snapshot: dict) -> None:
    """Replace one local receipt after writing and syncing a same-folder file."""
    payload = serialize_snapshot(snapshot)
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="ascii", newline="\n",
                                         dir=path.parent, prefix=f".{path.name}.",
                                         suffix=".tmp", delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
