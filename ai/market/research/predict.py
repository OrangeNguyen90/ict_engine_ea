"""Freeze a research model and publish opt-in, display-only MT5 forecasts.

No terminal connection or order API is used. Predictions require a refreshed,
verified export replayed from the original context start; a rolling tail cannot
reconstruct the detector's consumed liquidity state.
"""
import argparse
from dataclasses import replace
from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path
import time

from .candidates import detect_candidates
from .data import load_dataset
from .outcomes import evaluate_candidates
from .run import _rr_settings
from .sequences import attach_sequences
from .types import ResearchConfig
from .validation import _time


MAX_MODEL_BYTES = 16 * 1024 * 1024


def history_digest(bars, *, fit_cutoff, timeframe_seconds):
    """Fingerprint the exact causal replay prefix, excluding all later candles."""
    cutoff = _time(fit_cutoff)
    step = timedelta(seconds=timeframe_seconds)
    material = [[bar.time.isoformat(), bar.open, bar.high, bar.low, bar.close,
                 bar.spread, bar.volume] for bar in bars if bar.time + step <= cutoff]
    return hashlib.sha256(json.dumps(material, separators=(",", ":"),
                                    allow_nan=False).encode("ascii")).hexdigest()


def _verified_source(source):
    quality = source.get("quality", {})
    if (source.get("price_type") != "bid" or source.get("price_type_historically_verified") is not True
            or quality.get("export_complete") is not True or quality.get("coverage_verified") is not True):
        raise ValueError("frozen prediction requires verified historical Bid, coverage and complete source")


def fit_from_csv(csv_path, *, fit_cutoff, targets, commission_r, slippage_ticks,
                 metadata_path=None, source_timezone=None, utc_offset_minutes=None,
                 model="ridge", sequence_window=None, min_expected_r=0.0,
                 horizon_bars=16, min_train=100, min_mlp_train=200, seed=7):
    """Fit once before the fixed cutoff; held candles are never detected/labeled."""
    from .portable_model import fit_model
    targets = _rr_settings(targets, model, min_expected_r, sequence_window)
    if targets is None:
        raise ValueError("at least two fixed targets are required")
    if commission_r is None or slippage_ticks is None:
        raise ValueError("explicit commission_r and slippage_ticks are required")
    cutoff = _time(fit_cutoff)
    bars, source = load_dataset(
        csv_path, metadata_path=metadata_path, source_timezone=source_timezone,
        utc_offset_minutes=utc_offset_minutes, as_of=cutoff, require_verified_bid=True)
    _verified_source(source)
    config = ResearchConfig(
        source["symbol"], source["timeframe"], source["timeframe_seconds"],
        source["tick_size"], source["point"], target_r=targets[0], horizon_bars=horizon_bars,
        commission_r=commission_r, slippage_ticks=slippage_ticks)
    candidates = [candidate for candidate in detect_candidates(bars, config)
                  if candidate.confirmed_at < cutoff]
    records_by_target = {}
    for target in targets:
        records = evaluate_candidates(bars, candidates, replace(config, target_r=target))
        if sequence_window is not None:
            records = attach_sequences(records, bars, window=sequence_window,
                                       timeframe_seconds=config.timeframe_seconds)
        records_by_target[target] = records
    return fit_model(
        records_by_target, config=config, fit_cutoff=cutoff.isoformat(), source=source,
        context_start=bars[0].time.isoformat(), min_train=min_train, min_mlp_train=min_mlp_train,
        model=model, sequence_window=sequence_window, min_expected_r=min_expected_r, seed=seed,
        training_prefix_sha256=history_digest(bars, fit_cutoff=cutoff.isoformat(),
                                             timeframe_seconds=config.timeframe_seconds))


def _unique_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate model key: {key}")
        result[key] = value
    return result


def load_model(path, *, expected_model_id=None):
    from .portable_model import validate_model
    path = Path(path)
    if path.stat().st_size > MAX_MODEL_BYTES:
        raise ValueError("model JSON exceeds size limit")
    def invalid_constant(value):
        raise ValueError(f"nonfinite JSON constant: {value}")
    bundle = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=_unique_keys,
                        parse_constant=invalid_constant)
    validate_model(bundle)
    if expected_model_id is not None and bundle["model_id"] != expected_model_id:
        raise ValueError("model id does not match the pinned model")
    return bundle


def save_model(path, bundle):
    from .portable_model import validate_model
    validate_model(bundle)
    serialized = json.dumps(bundle, ensure_ascii=True, indent=2, allow_nan=False) + "\n"
    if len(serialized.encode("ascii")) > MAX_MODEL_BYTES:
        raise ValueError("model JSON exceeds size limit")
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="ascii", newline="\n") as stream:
        stream.write(serialized)


def _same_source(bundle, source):
    _verified_source(source)
    config = bundle["config"]
    for name in ("symbol", "timeframe", "timeframe_seconds", "tick_size", "point"):
        if source.get(name) != config.get(name):
            raise ValueError(f"prediction source {name} differs from frozen model")
    original = bundle["source"].get("export_metadata", {})
    current = source.get("export_metadata", {})
    for name in ("broker", "server"):
        if not original.get(name) or current.get(name) != original[name]:
            raise ValueError(f"prediction source {name} differs from frozen model")


def infer_from_csv(bundle, csv_path, *, now, metadata_path=None, source_timezone=None,
                   utc_offset_minutes=None, ttl_seconds=60):
    """Infer only the latest closed confirmation; never compute future outcomes."""
    from .portable_model import predict_record, validate_model
    from .prediction_bridge import build_snapshot
    validate_model(bundle)
    if not isinstance(now, datetime) or now.tzinfo is None or now.utcoffset() is None:
        raise ValueError("now must be a timezone-aware datetime")
    now = now.astimezone(timezone.utc)
    bars, source = load_dataset(
        csv_path, metadata_path=metadata_path, source_timezone=source_timezone,
        utc_offset_minutes=utc_offset_minutes, as_of=now, require_verified_bid=True)
    _same_source(bundle, source)
    config = ResearchConfig(**bundle["config"])
    if bars[0].time != _time(bundle["context_start"]):
        raise ValueError("CONTEXT_START_MISMATCH: replay the original detector history, not a rolling tail")
    prefix = history_digest(bars, fit_cutoff=bundle["fit_cutoff"],
                            timeframe_seconds=config.timeframe_seconds)
    if prefix != bundle["training_prefix_sha256"]:
        raise ValueError("TRAINING_HISTORY_CHANGED: use the exact original replay prefix")
    as_of = bars[-1].time + timedelta(seconds=config.timeframe_seconds)
    if as_of < _time(bundle["fit_cutoff"]):
        raise ValueError("prediction confirmation must be at or after frozen fit cutoff")
    if now < as_of or now >= as_of + timedelta(seconds=config.timeframe_seconds):
        raise ValueError("DATA_STALE: no current closed-candle confirmation")
    candidates = [candidate for candidate in detect_candidates(bars, config)
                  if candidate.confirmed_at == as_of]
    prediction = {"status": "ABSTAIN", "reason": "NO_CURRENT_CANDIDATE",
                  "candidate_id": "-", "family": "-", "direction": 0,
                  "selected_target_r": None, "expected_net_r": None, "p_tp": None}
    if len(candidates) > 1:
        # The research policy scores individual setups. Selecting a winner
        # among concurrent setups would introduce another unvalidated policy.
        prediction["reason"] = "MULTIPLE_CURRENT_CANDIDATES"
    elif candidates:
        candidate = candidates[0]
        record = {"candidate_id": candidate.id, "symbol": candidate.symbol,
                  "timeframe": candidate.timeframe, "family": candidate.family,
                  "direction": candidate.direction, "as_of": candidate.confirmed_at.isoformat(),
                  "features": dict(candidate.features)}
        window = bundle.get("sequence_window")
        if window is not None:
            record = attach_sequences([record], bars, window=window,
                                       timeframe_seconds=config.timeframe_seconds)[0]
        prediction = dict(predict_record(bundle, record), candidate_id=candidate.id,
                          family=candidate.family, direction=candidate.direction)
    return build_snapshot(bundle, prediction, symbol=config.symbol, timeframe=config.timeframe,
                          as_of=as_of, now=now, ttl_seconds=ttl_seconds)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    fit = commands.add_parser("fit", help="Fit a frozen, research-advisory model from a verified export")
    predict = commands.add_parser("predict", help="Publish one advisory snapshot, optionally watching refreshed exports")
    for command in (fit, predict):
        command.add_argument("--csv", type=Path, required=True)
        command.add_argument("--metadata", type=Path)
        command.add_argument("--output", type=Path, required=True)
        zone = command.add_mutually_exclusive_group()
        zone.add_argument("--source-timezone")
        zone.add_argument("--utc-offset-minutes", type=int)
    fit.add_argument("--fit-cutoff", required=True, help="Fixed UTC/offset time after all training outcomes")
    fit.add_argument("--targets", type=float, nargs="+", required=True)
    fit.add_argument("--commission-r", type=float, required=True)
    fit.add_argument("--slippage-ticks", type=float, required=True)
    fit.add_argument("--model", choices=("ridge", "mlp"), default="ridge")
    fit.add_argument("--sequence-window", type=int)
    fit.add_argument("--min-expected-r", type=float, default=0)
    fit.add_argument("--horizon-bars", type=int, default=16)
    fit.add_argument("--min-train", type=int, default=100)
    fit.add_argument("--min-mlp-train", type=int, default=200)
    fit.add_argument("--seed", type=int, default=7)
    predict.add_argument("--model-file", type=Path, required=True)
    predict.add_argument("--expected-model-id", required=True, help="Pin the model_id reported by fit")
    predict.add_argument("--ttl-seconds", type=int, default=60)
    predict.add_argument("--watch-seconds", type=int, default=0, help="0 runs once; otherwise recheck export every 1..60 seconds")
    args = parser.parse_args(argv)
    try:
        source_options = dict(metadata_path=args.metadata, source_timezone=args.source_timezone,
                              utc_offset_minutes=args.utc_offset_minutes)
        if args.command == "fit":
            bundle = fit_from_csv(
                args.csv, fit_cutoff=args.fit_cutoff, targets=args.targets,
                commission_r=args.commission_r, slippage_ticks=args.slippage_ticks,
                model=args.model, sequence_window=args.sequence_window, min_expected_r=args.min_expected_r,
                horizon_bars=args.horizon_bars, min_train=args.min_train,
                min_mlp_train=args.min_mlp_train, seed=args.seed, **source_options)
            save_model(args.output, bundle)
            print(json.dumps({"output": str(args.output), "model_id": bundle["model_id"],
                              "scope": bundle["scope"], "execution_allowed": False}, allow_nan=False))
            return 0
        if not 0 <= args.watch_seconds <= 60:
            raise ValueError("watch_seconds must be 0..60")
        from .prediction_bridge import atomic_write_snapshot
        bundle = load_model(args.model_file, expected_model_id=args.expected_model_id)
        while True:
            try:
                snapshot = infer_from_csv(bundle, args.csv, now=datetime.now(timezone.utc),
                                          ttl_seconds=args.ttl_seconds, **source_options)
                atomic_write_snapshot(args.output, snapshot)
                print(json.dumps({"output": str(args.output), "status": snapshot["status"],
                                  "reason": snapshot["reason"], "model_id": bundle["model_id"]},
                                 allow_nan=False), flush=True)
            except (OSError, ValueError) as exc:
                if not args.watch_seconds:
                    raise
                # Never refresh the old forecast's expiry on source failures.
                print(json.dumps({"status": "UNAVAILABLE", "reason": str(exc)}, ensure_ascii=True), flush=True)
            if not args.watch_seconds:
                return 0
            time.sleep(args.watch_seconds)
    except KeyboardInterrupt:
        return 0
    except (OSError, ValueError) as exc:
        parser.exit(2, f"Frozen prediction failed: {exc}\n")


if __name__ == "__main__":
    raise SystemExit(main())
