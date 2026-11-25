"""Reproducible, offline audit and exploratory replay of one export pair.

No Django, database, MT5 connection, chart change, or trading call is used.
"""

import argparse
from collections import Counter
from dataclasses import asdict, replace
from datetime import timedelta
import hashlib
from importlib import metadata as package_metadata
import json
import math
from pathlib import Path

from . import RESEARCH_VERSION
from .candidates import DETECTOR_VERSION, detect_candidates
from .data import file_digest, load_dataset, parse_time
from .outcomes import evaluate_candidates
from .types import ResearchConfig
from .validation import walk_forward


def _code_hashes():
    directory = Path(__file__).resolve().parent
    return {name: file_digest(directory / name) for name in
            ("__init__.py", "types.py", "data.py", "candidates.py",
             "outcomes.py", "validation.py", "ml.py", "calibration.py", "rr.py",
             "sequences.py", "portable_model.py", "prediction_bridge.py", "predict.py", "run.py")}


def _rr_settings(targets, model, minimum, window):
    """Validate and canonicalize the predeclared action space before any fit."""
    if targets is None:
        if model != "ridge" or minimum != 0.0 or window is not None:
            raise ValueError("RR model, threshold and sequence window require rr_targets")
        return None
    if not isinstance(targets, (list, tuple)) or len(targets) < 2:
        raise ValueError("rr_targets must contain at least two unique positive targets")
    if any(isinstance(value, bool) or not isinstance(value, (int, float)) or
           not math.isfinite(value) or value <= 0 for value in targets):
        raise ValueError("rr_targets must contain finite positive numbers")
    targets = sorted(float(value) for value in targets)
    if len(set(targets)) != len(targets):
        raise ValueError("rr_targets must be unique")
    if model not in ("ridge", "mlp"):
        raise ValueError("rr_model must be ridge or mlp")
    if isinstance(minimum, bool) or not isinstance(minimum, (int, float)) or not math.isfinite(minimum):
        raise ValueError("rr_min_expected_r must be finite")
    if window is not None and (isinstance(window, bool) or not isinstance(window, int) or window < 2):
        raise ValueError("rr_sequence_window must be an integer of at least two")
    return targets


def build_report(csv_path, *, metadata_path=None, source_timezone=None,
                 utc_offset_minutes=None, as_of=None, mode="audit",
                 allow_partial=False, commission_r=None, slippage_ticks=None,
                 target_r=2.0, horizon_bars=16, min_train=100, test_size=50,
                 min_family_train=30, min_oos=100, bootstrap_samples=300,
                 seed=7, include_ml=False, min_mlp_train=200,
                 holdout_cutoff=None, evaluate_holdout=False, min_holdout=30,
                 rr_targets=None, rr_model="ridge", rr_min_expected_r=0.0,
                 rr_sequence_window=None):
    rr_targets = _rr_settings(rr_targets, rr_model, rr_min_expected_r, rr_sequence_window)
    if rr_targets is not None and (mode != "evaluate" or not include_ml):
        raise ValueError("RR study requires evaluate mode and include_ml (--ml)")
    if mode not in ("audit", "evaluate"):
        raise ValueError("mode must be audit or evaluate")
    if mode == "evaluate":
        if allow_partial:
            raise ValueError("evaluation cannot use a partial export")
        if commission_r is None or slippage_ticks is None:
            raise ValueError("evaluation requires explicit commission_r and slippage_ticks")
    elif commission_r is not None or slippage_ticks is not None:
        raise ValueError("cost assumptions apply only to evaluation")
    if mode != "evaluate" and include_ml:
        raise ValueError("ML requires evaluate mode")
    if holdout_cutoff is not None and not include_ml:
        raise ValueError("holdout requires ML evaluation")
    if evaluate_holdout and holdout_cutoff is None:
        raise ValueError("evaluating holdout requires a cutoff")
    holdout_time = None
    if holdout_cutoff is not None:
        from .validation import _time
        holdout_time = _time(holdout_cutoff)
        holdout_cutoff = holdout_time.isoformat()

    ml_dependencies = None
    if include_ml:
        try:
            ml_dependencies = {name: package_metadata.version(name)
                               for name in ("scikit-learn", "numpy", "scipy")}
        except package_metadata.PackageNotFoundError as exc:
            raise ValueError("ML requires dependencies from requirements-research-ml.txt") from exc

    bars, manifest = load_dataset(
        csv_path, metadata_path=metadata_path, source_timezone=source_timezone,
        utc_offset_minutes=utc_offset_minutes, as_of=as_of,
        allow_partial=allow_partial, require_verified_bid=(mode == "evaluate"),
    )
    if holdout_time is not None and not (bars[0].time < holdout_time <=
                                          parse_time(manifest["quality"]["as_of_utc"])):
        raise ValueError("holdout cutoff must be inside the loaded dataset interval")
    code_hashes = _code_hashes()
    settings = {"mode": mode, "allow_partial": allow_partial,
                "target_r": target_r, "horizon_bars": horizon_bars,
                "commission_r": commission_r, "slippage_ticks": slippage_ticks,
                "min_train": min_train, "test_size": test_size,
                "min_family_train": min_family_train, "min_oos": min_oos,
                "bootstrap_samples": bootstrap_samples, "seed": seed,
                "include_ml": include_ml, "min_mlp_train": min_mlp_train,
                "holdout_cutoff": holdout_cutoff, "evaluate_holdout": evaluate_holdout,
                "min_holdout": min_holdout,
                "rr_targets": rr_targets, "rr_model": rr_model,
                "rr_min_expected_r": rr_min_expected_r,
                "rr_sequence_window": rr_sequence_window}
    trial_material = {"research_version": RESEARCH_VERSION,
                      "csv_sha256": manifest["csv_sha256"],
                      "metadata_sha256": manifest["metadata_sha256"],
                      "as_of_utc": manifest["quality"]["as_of_utc"],
                      "settings": settings, "code_sha256": code_hashes,
                      "ml_dependencies": ml_dependencies}
    trial_id = hashlib.sha256(json.dumps(trial_material, sort_keys=True,
                                         allow_nan=False).encode("utf-8")).hexdigest()
    quality = manifest["quality"]
    source_verified = (quality["export_complete"] and quality["coverage_verified"]
                       and manifest["price_type"] == "bid"
                       and manifest["price_type_historically_verified"])
    report = {"schema_version": 1, "research_version": RESEARCH_VERSION,
              "trial_id": trial_id, "detector_version": DETECTOR_VERSION,
              "code_sha256": code_hashes, "settings": settings,
              "ml_dependencies": ml_dependencies,
              "source": manifest,
              "source_gate": "VERIFIED" if source_verified else "UNVERIFIED_SOURCE",
              "usable_for_shadow": False}
    if mode == "audit":
        report.update(status="AUDIT_ONLY", counts={"bars": len(bars),
                      "unclassified_gaps": quality["gap_count"]})
        return report

    config = ResearchConfig(
        symbol=manifest["symbol"], timeframe=manifest["timeframe"],
        timeframe_seconds=manifest["timeframe_seconds"],
        tick_size=manifest["tick_size"], point=manifest["point"],
        target_r=target_r, horizon_bars=horizon_bars,
        commission_r=commission_r, slippage_ticks=slippage_ticks,
    )
    # The ordinary report and empirical validation always stop at the cutoff.
    # In development mode, no candidates or outcomes after it are computed.
    step = timedelta(seconds=config.timeframe_seconds)
    development_bars = (bars if holdout_time is None else
                        [bar for bar in bars if bar.time + step <= holdout_time])
    candidates = detect_candidates(development_bars, config)
    if holdout_time is not None:
        candidates = [item for item in candidates if item.confirmed_at < holdout_time]
    outcomes = evaluate_candidates(development_bars, candidates, config)
    validation = walk_forward(
        outcomes, min_train=min_train, test_size=test_size,
        min_family_train=min_family_train, min_oos=min_oos,
        bootstrap_samples=bootstrap_samples, seed=seed,
    )
    if include_ml:
        from .ml import walk_forward_ml
        ml_records = outcomes
        if evaluate_holdout:
            all_candidates = detect_candidates(bars, config)
            held_candidates = [item for item in all_candidates if item.confirmed_at >= holdout_time]
            ml_records = outcomes + evaluate_candidates(bars, held_candidates, config)
        ml_result = walk_forward_ml(ml_records, min_train=min_train, test_size=test_size,
                                    min_mlp_train=min_mlp_train, seed=seed,
                                    holdout_cutoff=holdout_cutoff, min_holdout=min_holdout,
                                    evaluate_holdout=evaluate_holdout)
        if ml_result["status"] == "SKLEARN_UNAVAILABLE":
            raise ValueError("ML dependencies are installed but cannot be imported")
        if holdout_time is not None and not evaluate_holdout:
            ml_result["holdout"]["records"] = None
            ml_result["holdout"]["note"] = "Holdout candidates are not detected in development mode."
        from .calibration import calibration_report
        def assess(rows):
            models = ("logistic_p_tp", "mlp_p_tp")
            common = [row for row in rows if row.get("scored") is True and
                      all(row.get(model) is not None for model in models)]
            return {"by_model": {model: calibration_report(rows, model) for model in models},
                    "common_rows": {model: calibration_report(common, model) for model in models}}
        ml_result["calibration"] = assess(ml_result["predictions"])
        if evaluate_holdout:
            ml_result["holdout"]["calibration"] = assess(ml_result["holdout"]["predictions"])
        report["ml"] = ml_result
        if rr_targets is not None:
            from .rr import walk_forward_rr
            records_by_target = {}
            for reward in rr_targets:
                rr_config = replace(config, target_r=reward)
                rr_records = evaluate_candidates(development_bars, candidates, rr_config)
                if evaluate_holdout:
                    rr_records += evaluate_candidates(bars, held_candidates, rr_config)
                if rr_sequence_window is not None:
                    from .sequences import attach_sequences
                    rr_records = attach_sequences(
                        rr_records, bars if evaluate_holdout else development_bars,
                        window=rr_sequence_window, timeframe_seconds=config.timeframe_seconds)
                records_by_target[reward] = rr_records
            rr_result = walk_forward_rr(
                records_by_target, min_train=min_train, test_size=test_size,
                min_mlp_train=min_mlp_train, seed=seed, model=rr_model,
                min_expected_r=rr_min_expected_r,
                feature_mode="sequence" if rr_sequence_window is not None else "tabular",
                holdout_cutoff=holdout_cutoff, evaluate_holdout=evaluate_holdout,
                min_holdout=min_holdout, bootstrap_samples=bootstrap_samples)
            if rr_result["status"] == "SKLEARN_UNAVAILABLE":
                raise ValueError("RR dependencies are installed but cannot be imported")
            rr_result["source_gate"] = report["source_gate"]
            rr_result["usable_for_shadow"] = False
            if holdout_time is not None and not evaluate_holdout:
                rr_result["holdout"]["records"] = None
                rr_result["holdout"]["note"] = "Holdout candidates are not detected in development mode."
            report["rr_study"] = rr_result
    if not source_verified:
        for profile in validation["profiles"]:
            profile["statistical_support_status"] = profile["support_status"]
            profile["support_status"] = "UNVERIFIED_SOURCE"
    report.update(
        status=(validation["status"] if source_verified else "EXPLORATORY_SOURCE_UNVERIFIED"),
        config=asdict(config),
        counts={"bars": len(development_bars), "source_unclassified_gaps": quality["gap_count"],
                "candidates": len(candidates),
                "by_family": dict(Counter(item.family for item in candidates)),
                "outcomes": dict(Counter(item["label"] for item in outcomes))},
        candidates=[{**asdict(item), "confirmed_at": item.confirmed_at.isoformat()}
                    for item in candidates],
        outcomes=outcomes, validation=validation,
    )
    # Statistical support is only an offline screening result. Shadow display
    # additionally needs source verification and an independently frozen model.
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csv", type=Path, required=True)
    parser.add_argument("--metadata", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--mode", choices=("audit", "evaluate"), default="audit")
    zone = parser.add_mutually_exclusive_group()
    zone.add_argument("--source-timezone")
    zone.add_argument("--utc-offset-minutes", type=int)
    parser.add_argument("--as-of", help="Optional frozen cutoff in ISO-8601")
    parser.add_argument("--allow-partial", action="store_true", help="Audit only")
    parser.add_argument("--commission-r", type=float)
    parser.add_argument("--slippage-ticks", type=float)
    parser.add_argument("--target-r", type=float, default=2.0)
    parser.add_argument("--horizon-bars", type=int, default=16)
    parser.add_argument("--min-train", type=int, default=100)
    parser.add_argument("--test-size", type=int, default=50)
    parser.add_argument("--min-family-train", type=int, default=30)
    parser.add_argument("--min-oos", type=int, default=100)
    parser.add_argument("--bootstrap-samples", type=int, default=300)
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument("--ml", action="store_true", help="Evaluate optional offline research models")
    parser.add_argument("--min-mlp-train", type=int, default=200)
    parser.add_argument("--holdout-cutoff", help="UTC/offset ISO time; reserve later candidates")
    parser.add_argument("--evaluate-holdout", action="store_true", help="Unseal and score holdout once after locking the study")
    parser.add_argument("--min-holdout", type=int, default=30)
    parser.add_argument("--rr-targets", type=float, nargs="+",
                        help="Fixed gross-R action grid, e.g. 1 1.5 2 3; requires --ml")
    parser.add_argument("--rr-model", choices=("ridge", "mlp"), default="ridge",
                        help="Predeclared net-R regressor for RR selection")
    parser.add_argument("--rr-min-expected-r", type=float, default=0.0,
                        help="Abstain unless predicted net R exceeds this fixed threshold")
    parser.add_argument("--rr-sequence-window", type=int,
                        help="Use this many contiguous closed candles as RR model input")
    args = parser.parse_args(argv)
    try:
        cutoff = (parse_time(args.as_of, source_timezone=args.source_timezone,
                             utc_offset_minutes=args.utc_offset_minutes)
                  if args.as_of else None)
        report = build_report(
            args.csv, metadata_path=args.metadata,
            source_timezone=args.source_timezone,
            utc_offset_minutes=args.utc_offset_minutes, as_of=cutoff,
            mode=args.mode, allow_partial=args.allow_partial,
            commission_r=args.commission_r, slippage_ticks=args.slippage_ticks,
            target_r=args.target_r, horizon_bars=args.horizon_bars,
            min_train=args.min_train, test_size=args.test_size,
            min_family_train=args.min_family_train, min_oos=args.min_oos,
            bootstrap_samples=args.bootstrap_samples, seed=args.seed,
            include_ml=args.ml, min_mlp_train=args.min_mlp_train,
            holdout_cutoff=args.holdout_cutoff, evaluate_holdout=args.evaluate_holdout,
            min_holdout=args.min_holdout,
            rr_targets=args.rr_targets, rr_model=args.rr_model,
            rr_min_expected_r=args.rr_min_expected_r,
            rr_sequence_window=args.rr_sequence_window,
        )
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open("x", encoding="utf-8") as stream:
            json.dump(report, stream, ensure_ascii=False, indent=2, allow_nan=False)
            stream.write("\n")
        print(json.dumps({"output": str(args.output), "status": report["status"],
                          "trial_id": report["trial_id"], "counts": report["counts"]},
                         ensure_ascii=False, allow_nan=False))
        return 0
    except (OSError, ValueError) as exc:
        parser.exit(2, f"Research run failed: {exc}\n")


if __name__ == "__main__":
    raise SystemExit(main())
