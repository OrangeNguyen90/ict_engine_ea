"""Exploratory, purged walk-forward ML; never used for live execution.

Only explicitly listed features from the detector at confirmation are used.
Preprocessing and estimators are fitted anew on each purged training set.
Scikit-learn is an optional research dependency, loaded only when requested.
"""
from collections import Counter
import math
from statistics import mean
import warnings

from .validation import _batches, _eligible, _time


# Explicit allowlist: entry, outcome and arbitrary caller-supplied features are
# excluded because their availability at confirmation cannot be established.
NUMERIC_FEATURES = (
    "atr", "body_ratio", "range_atr", "signal_spread", "signal_close",
    "zone_lower", "zone_upper", "gap_atr", "impulse_body_atr", "age_bars",
    "fill_fraction", "level", "break_strength_atr", "sweep_depth_atr",
    "pool_age_bars",
)
FAMILIES = ("FVG_FIRST_RETEST", "BREAK_RETEST", "SWEEP_RECLAIM")


def _vector(record: dict) -> list[float]:
    features = record.get("features")
    if not isinstance(features, dict):
        features = {}
    values, missing = [], []
    for name in NUMERIC_FEATURES:
        value = features.get(name)
        valid = isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)
        values.append(float(value) if valid else 0.0)
        missing.append(0.0 if valid else 1.0)
    direction = record.get("direction")
    return values + missing + [float(direction == 1), float(direction == -1)] + [
        float(record.get("family") == family) for family in FAMILIES
    ]


def _metrics(rows: list[dict], model: str) -> dict:
    scored = [row for row in rows if row[model] is not None and row["scored"]]
    if model == "linear_net_r":
        return {"n": len(scored),
                "mae": mean(abs(row[model] - row["net_r"]) for row in scored) if scored else None,
                "baseline_mae": mean(abs(row["baseline_net_r"] - row["net_r"]) for row in scored) if scored else None,
                "rmse": math.sqrt(mean((row[model] - row["net_r"]) ** 2 for row in scored)) if scored else None,
                "baseline_rmse": math.sqrt(mean((row["baseline_net_r"] - row["net_r"]) ** 2 for row in scored)) if scored else None}
    def log_loss(probability, outcome):
        p = min(max(probability, 1e-12), 1 - 1e-12)
        return -(outcome * math.log(p) + (1 - outcome) * math.log(1 - p))

    return {"n": len(scored),
            "brier": mean((row[model] - row["y"]) ** 2 for row in scored) if scored else None,
            "baseline_brier": mean((row["baseline_p_tp"] - row["y"]) ** 2 for row in scored) if scored else None,
            "log_loss": mean(log_loss(row[model], row["y"]) for row in scored) if scored else None,
            "baseline_log_loss": mean(log_loss(row["baseline_p_tp"], row["y"]) for row in scored) if scored else None}


def walk_forward_ml(records: list[dict], *, min_train: int = 100,
                    test_size: int = 50, min_mlp_train: int = 200, seed: int = 7,
                    holdout_cutoff: str | None = None, min_holdout: int = 30,
                    evaluate_holdout: bool = False) -> dict:
    """Compare fixed models against training-mean baselines on the same OOS rows.

    MLP here is a two-hidden-layer neural classifier, not a trading policy.
    No tuning, selection, calibration or holdout reuse is performed. Labels
    resolving at or after a test batch's first confirmation are purged.
    """
    for name, value in (("min_train", min_train), ("test_size", test_size),
                        ("min_mlp_train", min_mlp_train), ("min_holdout", min_holdout)):
        if isinstance(value, bool) or not isinstance(value, int) or value < 1:
            raise ValueError(f"{name} must be a positive integer")
    if isinstance(seed, bool) or not isinstance(seed, int) or seed < 0:
        raise ValueError("seed must be a non-negative integer")
    if not isinstance(evaluate_holdout, bool):
        raise ValueError("evaluate_holdout must be a bool")
    if evaluate_holdout and holdout_cutoff is None:
        raise ValueError("evaluate_holdout requires holdout_cutoff")
    ordered = sorted(records, key=lambda row: (_time(row["as_of"]), str(row["candidate_id"])))
    if len({row["candidate_id"] for row in ordered}) != len(ordered):
        raise ValueError("candidate ids must be unique")
    if len({(row.get("symbol"), row.get("timeframe")) for row in ordered}) > 1:
        raise ValueError("walk_forward_ml requires one symbol and timeframe")
    for row in ordered:
        if row.get("label_end") is not None and _time(row["label_end"]) < _time(row["as_of"]):
            raise ValueError("label_end precedes confirmation")
    if holdout_cutoff is not None and not isinstance(holdout_cutoff, str):
        raise ValueError("holdout_cutoff must be a timezone-aware ISO timestamp")
    cutoff = _time(holdout_cutoff) if holdout_cutoff is not None else None
    development = [row for row in ordered if cutoff is None or _time(row["as_of"]) < cutoff]
    holdout = [row for row in ordered if cutoff is not None and _time(row["as_of"]) >= cutoff]

    def development_eligible(row):
        return _eligible(row) and (cutoff is None or _time(row["label_end"]) < cutoff)
    methodology = {
        "scope": "exploratory offline research only; not a live execution model or evidence of profitability",
        "features": "fixed confirmation-time allowlist with missing indicators; no entry or outcome data",
        "purge": "training label_end strictly before the first confirmation of each whole test batch",
        "grouping": "identical confirmation timestamps remain together",
        "targets": "net R regression; TP_FIRST versus SL_FIRST or TIMEOUT classification",
        "exclusions": "ambiguous, censored, invalid and missing/nonfinite net R excluded from training and scoring",
        "baseline": "training mean net R or smoothed pooled TP frequency on identical scored rows",
        "preprocessing": "zero for missing numeric values with indicators; standard scaler fitted on train only",
        "models": "ordinary least squares; logistic regression; two-layer MLP classifier, fixed parameters and seed; no random early stopping",
        "caveat": "overlapping outcomes and repeated model comparisons limit inference; no profitability claim",
    }
    result = {"status": "INSUFFICIENT_EVIDENCE", "methodology": methodology,
              "settings": {"min_train": min_train, "test_size": test_size,
                           "min_mlp_train": min_mlp_train, "seed": seed},
              "counts": {"records": len(ordered), "eligible_labels": sum(_eligible(row) for row in ordered)},
              "exclusions": dict(Counter(row.get("label", "MISSING") for row in ordered if not _eligible(row))),
              "splits": [], "predictions": [], "metrics": {}}
    if cutoff is not None:
        result["settings"].update(holdout_cutoff=cutoff.isoformat(), min_holdout=min_holdout,
                                  evaluate_holdout=evaluate_holdout)
        result["methodology"]["holdout"] = (
            "fixed chronological cutoff; fit once on development labels ending strictly before cutoff; "
            "no tuning or selection on holdout; repeated use invalidates independence")
        result["counts"] = {"records": len(development),
                            "eligible_labels": sum(development_eligible(row) for row in development)}
        result["exclusions"] = dict(Counter(
            "UNAVAILABLE_AT_CUTOFF" if row.get("label_end") is None or
            _time(row["label_end"]) >= cutoff else row.get("label", "MISSING")
            for row in development if not development_eligible(row)))
        result["holdout"] = {"cutoff": cutoff.isoformat(), "records": len(holdout),
                             "min_scored": min_holdout, "status": "NOT_EVALUATED" if evaluate_holdout else "SEALED",
                             "split": None, "predictions": [], "metrics": {}}
    try:
        from sklearn.linear_model import LinearRegression, LogisticRegression
        from sklearn.neural_network import MLPClassifier
        from sklearn.preprocessing import StandardScaler
        from sklearn.exceptions import ConvergenceWarning
        import sklearn
    except ImportError:
        result["status"] = "SKLEARN_UNAVAILABLE"
        result["dependency"] = "Install the optional scikit-learn research dependency."
        return result
    result["sklearn_version"] = sklearn.__version__
    groups: list[list[dict]] = []
    for row in development:
        if not groups or _time(row["as_of"]) != _time(groups[-1][0]["as_of"]):
            groups.append([])
        groups[-1].append(row)
    previous: list[dict] = []
    split_index = 0
    while split_index < len(groups) and len(previous) < min_train:
        previous.extend(groups[split_index])
        split_index += 1
    batches = [(split_id, batch, False) for split_id, batch in
               enumerate(_batches(groups[split_index:], test_size), 1)]
    if holdout and evaluate_holdout:
        batches.append(("holdout", holdout, True))
    for split_id, batch, is_holdout in batches:
        start = cutoff if is_holdout else _time(batch[0]["as_of"])
        past = [row for row in previous if _eligible(row)]
        train = [row for row in past if _time(row["label_end"]) < start]
        sufficient = len(train) >= min_train
        labels = [int(row["label"] == "TP_FIRST") for row in train]
        baseline_r = mean(row["net_r"] for row in train) if sufficient else None
        baseline_p = (sum(labels) + 1) / (len(labels) + 2) if sufficient else None
        split = {"split_id": split_id, "test_start": start.isoformat(), "test_records": len(batch),
                 "train_n": len(train), "purged_overlap_n": len(past) - len(train),
                 "train_end": max((_time(row["label_end"]) for row in train), default=None),
                 "status": "FITTED" if sufficient else "INSUFFICIENT_TRAINING",
                 "classifier_status": "FITTED" if sufficient and len(set(labels)) == 2 else
                                      "ONE_CLASS" if sufficient else "INSUFFICIENT_TRAINING",
                 "mlp_status": "FITTED" if sufficient and len(train) >= min_mlp_train and len(set(labels)) == 2 else
                               "ONE_CLASS" if sufficient and len(train) >= min_mlp_train else "INSUFFICIENT_TRAINING",
                 "convergence_warnings": []}
        if split["train_end"] is not None:
            split["train_end"] = split["train_end"].isoformat()
        target = result["holdout"] if is_holdout else result
        if is_holdout:
            target["split"] = split
        else:
            result["splits"].append(split)
        regression = logistic = neural = None
        if sufficient:
            scaler = StandardScaler()
            x_train = scaler.fit_transform([_vector(row) for row in train])
            x_test = scaler.transform([_vector(row) for row in batch])
            regression = LinearRegression().fit(x_train, [row["net_r"] for row in train]).predict(x_test)
            if len(set(labels)) == 2:
                with warnings.catch_warnings(record=True) as caught:
                    warnings.simplefilter("always", ConvergenceWarning)
                    logistic = LogisticRegression(max_iter=1000, random_state=seed).fit(x_train, labels).predict_proba(x_test)[:, 1]
                    split["convergence_warnings"].extend(f"logistic: {warning.message}" for warning in caught
                                                          if issubclass(warning.category, ConvergenceWarning))
                if len(train) >= min_mlp_train:
                    with warnings.catch_warnings(record=True) as caught:
                        warnings.simplefilter("always", ConvergenceWarning)
                        neural = MLPClassifier(hidden_layer_sizes=(32, 16), max_iter=500, random_state=seed,
                                               early_stopping=False).fit(x_train, labels).predict_proba(x_test)[:, 1]
                        split["convergence_warnings"].extend(f"mlp: {warning.message}" for warning in caught
                                                              if issubclass(warning.category, ConvergenceWarning))
        for i, row in enumerate(batch):
            eligible = _eligible(row) if is_holdout else development_eligible(row)
            target["predictions"].append({
                "candidate_id": row["candidate_id"], "as_of": row["as_of"], "split_id": split_id,
                "label": row.get("label") if is_holdout or cutoff is None or
                         (row.get("label_end") is not None and _time(row["label_end"]) < cutoff) else None,
                "net_r": row.get("net_r") if eligible else None,
                "y": int(row["label"] == "TP_FIRST") if eligible else None, "scored": eligible,
                "baseline_net_r": baseline_r, "baseline_p_tp": baseline_p,
                "linear_net_r": float(regression[i]) if regression is not None else None,
                "logistic_p_tp": float(logistic[i]) if logistic is not None else None,
                "mlp_p_tp": float(neural[i]) if neural is not None else None,
            })
        if not is_holdout:
            previous.extend(batch)
    result["metrics"] = {name: _metrics(result["predictions"], name) for name in
                         ("linear_net_r", "logistic_p_tp", "mlp_p_tp")}
    for split in result["splits"]:
        rows = [row for row in result["predictions"] if row["split_id"] == split["split_id"]]
        split["metrics"] = {name: _metrics(rows, name) for name in result["metrics"]}
    if any(item["n"] for item in result["metrics"].values()):
        result["status"] = "OOS_EVALUATED_EXPLORATORY"
    if cutoff is not None and evaluate_holdout:
        target = result["holdout"]
        target["metrics"] = {name: _metrics(target["predictions"], name) for name in result["metrics"]}
        if not holdout:
            target["status"] = "NO_HOLDOUT_RECORDS"
        elif target["split"]["status"] != "FITTED":
            target["status"] = "INSUFFICIENT_TRAINING"
        elif target["metrics"]["linear_net_r"]["n"] < min_holdout:
            target["status"] = "INSUFFICIENT_SCORED_HOLDOUT"
        else:
            target["status"] = "HOLDOUT_EVALUATED"
    return result
