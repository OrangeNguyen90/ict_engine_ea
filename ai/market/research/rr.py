"""Purged, offline selection among predeclared reward/risk actions.

An action is a hypothetical target for one setup, never a second independent
observation.  Forecasts estimate net R directly; TP probabilities are separate
descriptive forecasts and are not substituted into a two-outcome payoff formula.
"""
from collections import Counter
import math
from statistics import mean
import warnings

from .calibration import calibration_report
from .ml import _vector
from .outcomes import RESOLVED_LABELS
from .validation import _batches, _day_bootstrap, _time


def _finite(value) -> bool:
    return (isinstance(value, (int, float)) and not isinstance(value, bool)
            and math.isfinite(value))


def _outcome(row: dict, cutoff=None) -> tuple[float | None, str | None]:
    """Return an observable utility, using the adverse bound for ambiguity."""
    end = row.get("label_end")
    if cutoff is not None and (end is None or _time(end) >= cutoff):
        return None, "UNAVAILABLE_AT_CUTOFF"
    label = row.get("label")
    if not isinstance(label, str):
        return None, "MISSING_LABEL" if label is None else "INVALID_LABEL"
    if label not in RESOLVED_LABELS and label != "AMBIGUOUS":
        return None, label
    if end is None:
        return None, "MISSING_LABEL_END"
    value = row.get("conservative_net_r") if label == "AMBIGUOUS" else row.get("net_r")
    if not _finite(value):
        return None, "NONFINITE_CONSERVATIVE_NET_R" if label == "AMBIGUOUS" else "NONFINITE_NET_R"
    return float(value), None


def _sequence(row: dict) -> list[float] | None:
    values = row.get("sequence_features")
    if not isinstance(values, list) or not values or not all(_finite(value) for value in values):
        return None
    return [float(value) for value in values]


def _paired_records(records_by_target: dict, cutoff, evaluate_holdout: bool,
                    feature_mode: str) -> tuple[list[float], list[dict], int | None]:
    if not isinstance(records_by_target, dict) or len(records_by_target) < 2:
        raise ValueError("records_by_target must contain at least two predeclared targets")
    if any(not _finite(target) or target <= 0 for target in records_by_target):
        raise ValueError("target R values must be positive and finite")
    targets = sorted(float(target) for target in records_by_target)
    indexed = {}
    for target in targets:
        records = records_by_target[target]
        if not isinstance(records, list):
            raise ValueError("each target must contain a list of records")
        index = {}
        for row in records:
            if not isinstance(row, dict) or not isinstance(row.get("candidate_id"), str) or not row["candidate_id"]:
                raise ValueError("each record needs a non-empty string candidate_id")
            if row["candidate_id"] in index:
                raise ValueError("candidate ids must be unique within each target")
            if not isinstance(row.get("as_of"), str):
                raise ValueError("each record needs a timezone-aware as_of timestamp")
            _time(row["as_of"])
            index[row["candidate_id"]] = row
        indexed[target] = index
    first = indexed[targets[0]]
    if any(set(indexed[target]) != set(first) for target in targets):
        raise ValueError("all targets must contain the same candidate ids")
    pairs = []
    scopes = set()
    development_dimensions = set()
    for candidate_id, base in first.items():
        as_of = _time(base["as_of"])
        active = cutoff is None or as_of < cutoff or evaluate_holdout
        actions = {target: indexed[target][candidate_id] for target in targets}
        scopes.add((base.get("symbol"), base.get("timeframe")))
        for target, row in actions.items():
            if (_time(row["as_of"]) != as_of or row.get("symbol") != base.get("symbol")
                    or row.get("timeframe") != base.get("timeframe")):
                raise ValueError("paired targets must share confirmation, symbol and timeframe")
            # Sealed holdout records are identified only by minimal metadata.
            # Their labels, label_end, family, direction and features are unread.
            if not active:
                continue
            if (row.get("family") != base.get("family") or row.get("direction") != base.get("direction")
                    or row.get("features", {}) != base.get("features", {})):
                raise ValueError("paired targets must share family, direction and confirmation features")
            if feature_mode == "sequence" and row.get("sequence_features") != base.get("sequence_features"):
                raise ValueError("paired targets must share sequence features")
            if "target_r" in row and (not _finite(row["target_r"]) or row["target_r"] != target):
                raise ValueError("record target_r must match its action key")
            if row.get("label_end") is not None:
                if not isinstance(row["label_end"], str):
                    raise ValueError("label_end must be a timezone-aware timestamp")
                if _time(row["label_end"]) < as_of:
                    raise ValueError("label_end precedes confirmation")
        if active and (not isinstance(base.get("family"), str) or not base["family"]
                       or isinstance(base.get("direction"), bool) or base.get("direction") not in (-1, 1)):
            raise ValueError("records need a family and direction of -1 or 1")
        if feature_mode == "sequence" and (cutoff is None or as_of < cutoff):
            values = _sequence(base)
            if values is not None:
                development_dimensions.add(len(values))
        pairs.append({"candidate_id": candidate_id, "as_of": as_of, "base": base, "actions": actions})
    if len(scopes) > 1:
        raise ValueError("walk_forward_rr requires one symbol and timeframe")
    if len(development_dimensions) > 1:
        raise ValueError("development sequence features must have a consistent dimension")
    dimension = next(iter(development_dimensions), None)
    if feature_mode == "sequence" and evaluate_holdout and dimension is not None:
        for pair in pairs:
            values = _sequence(pair["base"])
            if values is not None and len(values) != dimension:
                raise ValueError("holdout sequence dimension must match development")
    pairs.sort(key=lambda pair: (pair["as_of"], pair["candidate_id"]))
    return targets, pairs, dimension


def _summary(predictions: list[dict], targets: list[float], samples: int, seed: int) -> dict:
    selected = [row for row in predictions if row["selected_target_r"] is not None]
    scored = [row for row in selected if row["scored"]]
    ci, days = _day_bootstrap(scored, samples, seed)
    counts = Counter(row["selected_target_r"] for row in selected)
    matched = [row for row in predictions if row["common_scored"]]
    baselines, forecasts, outcomes, probability_reports = [], [], [], []
    for index, target in enumerate(targets):
        actions = [(row, row["actions"][index]) for row in predictions]
        baseline_rows = [dict(as_of=row["as_of"], net_r=row["actions"][index]["evaluation_net_r"])
                         for row in scored]
        baseline_ci, baseline_days = _day_bootstrap(baseline_rows, samples, seed)
        differences = [dict(as_of=row["as_of"], net_r=row["net_r"] - row["actions"][index]["evaluation_net_r"])
                       for row in scored]
        difference_ci, _ = _day_bootstrap(differences, samples, seed)
        baselines.append({
            "target_r": target, "n": len(baseline_rows),
            "mean_net_r": mean(row["net_r"] for row in baseline_rows) if baseline_rows else None,
            "mean_net_r_ci95": baseline_ci, "day_clusters": baseline_days,
            "mean_policy_difference_r": mean(row["net_r"] for row in differences) if differences else None,
            "mean_policy_difference_ci95": difference_ci,
        })
        fitted = [(row, action) for row, action in actions if row["common_scored"]
                  and action["expected_net_r"] is not None]
        forecasts.append({
            "target_r": target, "n": len(fitted),
            "mae": mean(abs(action["expected_net_r"] - action["evaluation_net_r"])
                        for _, action in fitted) if fitted else None,
            "baseline_mae": mean(abs(action["baseline_net_r"] - action["evaluation_net_r"])
                                 for _, action in fitted) if fitted else None,
            "rmse": math.sqrt(mean((action["expected_net_r"] - action["evaluation_net_r"]) ** 2
                                   for _, action in fitted)) if fitted else None,
        })
        outcomes.append({
            "target_r": target, "known_n": sum(action["evaluation_net_r"] is not None for _, action in actions),
            "ambiguous_adverse_n": sum(action["adverse_ambiguity"] for _, action in actions),
            "excluded": dict(Counter(action["outcome_exclusion"] for _, action in actions
                                     if action["outcome_exclusion"] is not None)),
        })
        probability_rows = [{"scored": row["common_scored"] and action["y"] is not None,
                             "p_tp": action["p_tp"], "baseline_p_tp": action["baseline_p_tp"],
                             "y": action["y"]} for row, action in actions]
        probability_reports.append({"target_r": target, **calibration_report(probability_rows, "p_tp")})
    return {
        "n": len(scored), "forecast_candidates": len(predictions), "matched_outcome_candidates": len(matched),
        "selected_n": len(selected), "abstained_n": len(predictions) - len(selected),
        "selection_coverage": len(selected) / len(predictions) if predictions else None,
        "scored_coverage": len(scored) / len(predictions) if predictions else None,
        "selected_scoring_coverage": len(scored) / len(selected) if selected else None,
        "selected_outcome_known_n": sum(row["selected_outcome_known"] for row in selected),
        "selected_excluded_due_to_other_actions": sum(row["selected_outcome_known"] and not row["common_scored"]
                                                      for row in selected),
        "abstention_reasons": dict(Counter(row["reason"] for row in predictions if row["status"] == "ABSTAIN")),
        "selected_target_counts": [{"target_r": target, "n": counts[target]} for target in targets],
        "mean_net_r": mean(row["net_r"] for row in scored) if scored else None,
        "mean_net_r_ci95": ci, "day_clusters": days,
        "ambiguous_selected_adverse_n": sum(row["label"] == "AMBIGUOUS" for row in scored),
        "fixed_target_baselines": baselines, "forecast_metrics": forecasts,
        "outcomes_by_target": outcomes,
        "calibration": {"selected_policy": calibration_report(predictions, "p_tp"),
                        "by_target": probability_reports},
        "interpretation": "per hypothetical selected setup on the all-action observable cohort; no portfolio PnL",
    }


def walk_forward_rr(records_by_target: dict[float, list[dict]], *, min_train: int = 100,
                    test_size: int = 50, min_mlp_train: int = 200, seed: int = 7,
                    model: str = "ridge", min_expected_r: float = 0.0,
                    holdout_cutoff: str | None = None, evaluate_holdout: bool = False,
                    min_holdout: int = 30, bootstrap_samples: int = 300,
                    feature_mode: str = "tabular") -> dict:
    """Choose maximum forecast net R; abstain unless it exceeds a fixed threshold.

    Model, target grid, feature mode and threshold must be declared before OOS
    review. Every fit uses a common cohort with *all* actions observable strictly
    before the test batch. Evaluation uses the same all-action observable cohort;
    ambiguity contributes its adverse bound and unknown outcomes remain excluded.
    """
    for name, value in (("min_train", min_train), ("test_size", test_size),
                        ("min_mlp_train", min_mlp_train), ("min_holdout", min_holdout)):
        if isinstance(value, bool) or not isinstance(value, int) or value < 1:
            raise ValueError(f"{name} must be a positive integer")
    if isinstance(bootstrap_samples, bool) or not isinstance(bootstrap_samples, int) or bootstrap_samples < 2:
        raise ValueError("bootstrap_samples must be at least two")
    if isinstance(seed, bool) or not isinstance(seed, int) or not 0 <= seed <= 2 ** 32 - 1:
        raise ValueError("seed must be an integer between 0 and 2**32-1")
    if model not in ("ridge", "mlp"):
        raise ValueError("model must be ridge or mlp")
    if feature_mode not in ("tabular", "sequence"):
        raise ValueError("feature_mode must be tabular or sequence")
    if not _finite(min_expected_r):
        raise ValueError("min_expected_r must be finite")
    if not isinstance(evaluate_holdout, bool):
        raise ValueError("evaluate_holdout must be a bool")
    if evaluate_holdout and holdout_cutoff is None:
        raise ValueError("evaluate_holdout requires holdout_cutoff")
    if holdout_cutoff is not None and not isinstance(holdout_cutoff, str):
        raise ValueError("holdout_cutoff must be a timezone-aware ISO timestamp")
    cutoff = _time(holdout_cutoff) if holdout_cutoff is not None else None
    targets, pairs, sequence_dimension = _paired_records(records_by_target, cutoff, evaluate_holdout, feature_mode)
    development = [pair for pair in pairs if cutoff is None or pair["as_of"] < cutoff]
    holdout = [pair for pair in pairs if cutoff is not None and pair["as_of"] >= cutoff]

    def vector(pair):
        if feature_mode == "tabular":
            return _vector(pair["base"])
        values = _sequence(pair["base"])
        if values is None or sequence_dimension is None or len(values) != sequence_dimension:
            return None
        # Direction and setup family only; sequence prices are already relative
        # to the last confirmation close and normalized by confirmation ATR.
        return values + _vector(pair["base"])[-5:]

    def common(pair, end_cutoff=None):
        return all(_outcome(row, end_cutoff)[0] is not None for row in pair["actions"].values())

    result = {
        "status": "INSUFFICIENT_EVIDENCE", "usable_for_shadow": False,
        "settings": {"targets_r": targets, "min_train": min_train, "test_size": test_size,
                     "min_mlp_train": min_mlp_train, "seed": seed, "model": model,
                     "min_expected_r": float(min_expected_r), "bootstrap_samples": bootstrap_samples,
                     "feature_mode": feature_mode, "sequence_dimension": sequence_dimension},
        "methodology": {
            "scope": "exploratory offline hypothetical setups only; no portfolio PnL or live execution eligibility",
            "selection": "fixed caller-selected model, targets and threshold; maximum forecast net R; exact ties use smaller target",
            "regressor": "Ridge alpha=1 or MLPRegressor hidden layers (32,16), max_iter=500, fixed seed, no random early stopping",
            "utility": "observed net R including timeouts and gap losses; ambiguous bars use conservative_net_r in fit and scoring",
            "probability": "separate uncalibrated logistic P(TP_FIRST vs SL_FIRST or TIMEOUT); ambiguity excluded; not used as expectancy",
            "cohort": "one setup per candidate; every action must be observable for training and matched evaluation",
            "purge": "all action label_end values strictly before whole test batch first confirmation",
            "preprocessing": "train-only StandardScaler; confirmation allowlist or finite causal normalized sequence plus direction/family",
            "sequence": "missing or gapped windows excluded from training and force abstention; no zero imputation",
            "baselines": "every fixed target on the identical selected scored cohort; no posthoc winning target recommendation",
            "bootstrap": "95% percentile interval resampling entire UTC confirmation days; cross-day dependence and selection uncertainty remain",
            "limitations": "fixed action grid cannot establish a globally highest RR; repeated comparisons and regime change limit inference",
        },
        "counts": {"records": len(development), "common_observable": sum(common(pair, cutoff) for pair in development),
                   "missing_features": sum(vector(pair) is None for pair in development)},
        "exclusions_by_target": [
            {"target_r": target, "excluded": dict(Counter(
                exclusion for pair in development
                for _, exclusion in [_outcome(pair["actions"][target], cutoff)] if exclusion is not None))}
            for target in targets],
        "splits": [], "predictions": [], "metrics": {}, "family_summaries": [],
    }
    if cutoff is not None:
        result["settings"].update(holdout_cutoff=cutoff.isoformat(), evaluate_holdout=evaluate_holdout,
                                  min_holdout=min_holdout)
        result["methodology"]["holdout"] = (
            "chronological cutoff; sealed labels and features unread by default; one frozen fit at cutoff when explicitly evaluated; "
            "repeated unsealing invalidates independence")
        result["holdout"] = {"cutoff": cutoff.isoformat(), "records": len(holdout), "min_scored": min_holdout,
                             "status": "NOT_EVALUATED" if evaluate_holdout else "SEALED", "split": None,
                             "predictions": [], "metrics": {}, "family_summaries": []}
    try:
        from sklearn.exceptions import ConvergenceWarning
        from sklearn.linear_model import LogisticRegression, Ridge
        from sklearn.neural_network import MLPRegressor
        from sklearn.preprocessing import StandardScaler
        import sklearn
    except ImportError:
        result["status"] = "SKLEARN_UNAVAILABLE"
        result["dependency"] = "Install the optional scikit-learn research dependency."
        return result
    result["sklearn_version"] = sklearn.__version__
    groups = []
    for pair in development:
        if not groups or pair["as_of"] != groups[-1][0]["as_of"]:
            groups.append([])
        groups[-1].append(pair)
    previous = []
    split_index = 0
    while split_index < len(groups) and len(previous) < min_train:
        previous.extend(groups[split_index])
        split_index += 1
    result["counts"].update(warmup_records=len(previous), warmup_timestamps=split_index)
    batches = [(split_id, batch, False) for split_id, batch in enumerate(_batches(groups[split_index:], test_size), 1)]
    if evaluate_holdout and holdout:
        batches.append(("holdout", holdout, True))
    for split_id, batch, is_holdout in batches:
        start = cutoff if is_holdout else batch[0]["as_of"]
        observable_past = [pair for pair in previous if common(pair, cutoff) and vector(pair) is not None]
        train = [pair for pair in observable_past
                 if all(_time(row["label_end"]) < start for row in pair["actions"].values())]
        required = max(min_train, min_mlp_train) if model == "mlp" else min_train
        sufficient = len(train) >= required
        train_end = max((_time(row["label_end"]) for pair in train for row in pair["actions"].values()), default=None)
        split = {"split_id": split_id, "test_start": start.isoformat(), "test_end": batch[-1]["base"]["as_of"],
                 "test_records": len(batch), "train_n": len(train), "minimum_required": required,
                 "train_end": train_end.isoformat() if train_end else None,
                 "purged_overlap_n": len(observable_past) - len(train),
                 "excluded_unknown_or_missing_features_n": len(previous) - len(observable_past),
                 "status": "FITTED" if sufficient else "INSUFFICIENT_TRAINING",
                 "classifier_by_target": [], "convergence_warnings": []}
        destination = result["holdout"] if is_holdout else result
        if is_holdout:
            destination["split"] = split
        else:
            result["splits"].append(split)
        valid_batch = [index for index, pair in enumerate(batch) if vector(pair) is not None]
        expectations, probabilities = {}, {}
        baseline_r, baseline_p = {}, {}
        if sufficient:
            scaler = StandardScaler()
            x_train = scaler.fit_transform([vector(pair) for pair in train])
            x_test = scaler.transform([vector(batch[index]) for index in valid_batch]) if valid_batch else None
            y_train = [[_outcome(pair["actions"][target], cutoff)[0] for target in targets] for pair in train]
            for target_index, target in enumerate(targets):
                baseline_r[target] = mean(row[target_index] for row in y_train)
            estimator = (Ridge(alpha=1.0) if model == "ridge" else
                         MLPRegressor(hidden_layer_sizes=(32, 16), max_iter=500, random_state=seed, early_stopping=False))
            with warnings.catch_warnings(record=True) as caught:
                warnings.simplefilter("always", ConvergenceWarning)
                estimator.fit(x_train, y_train)
                predicted = estimator.predict(x_test) if x_test is not None else []
                split["convergence_warnings"].extend(f"{model}: {warning.message}" for warning in caught
                                                      if issubclass(warning.category, ConvergenceWarning))
            for batch_index, predicted_values in zip(valid_batch, predicted):
                expectations[batch_index] = [float(value) if _finite(float(value)) else None for value in predicted_values]
            for target in targets:
                classifier_indices = [index for index, pair in enumerate(train)
                                      if pair["actions"][target]["label"] in RESOLVED_LABELS]
                labels = [int(train[index]["actions"][target]["label"] == "TP_FIRST") for index in classifier_indices]
                baseline_p[target] = (sum(labels) + 1) / (len(labels) + 2) if len(labels) >= min_train else None
                status = ("INSUFFICIENT_TRAINING" if len(labels) < min_train else
                          "ONE_CLASS" if len(set(labels)) < 2 else "FITTED")
                split["classifier_by_target"].append({"target_r": target, "train_n": len(labels), "status": status})
                if status == "FITTED":
                    with warnings.catch_warnings(record=True) as caught:
                        warnings.simplefilter("always", ConvergenceWarning)
                        classifier = LogisticRegression(max_iter=1000, random_state=seed).fit(x_train[classifier_indices], labels)
                        predicted_p = classifier.predict_proba(x_test)[:, 1] if x_test is not None else []
                        split["convergence_warnings"].extend(f"logistic target={target}: {warning.message}" for warning in caught
                                                              if issubclass(warning.category, ConvergenceWarning))
                    probabilities[target] = {batch_index: float(value) if _finite(float(value)) and 0 <= value <= 1 else None
                                             for batch_index, value in zip(valid_batch, predicted_p)}
        for batch_index, pair in enumerate(batch):
            end_cutoff = None if is_holdout else cutoff
            values = [_outcome(pair["actions"][target], end_cutoff) for target in targets]
            matched = all(value is not None for value, _ in values)
            predicted_values = expectations.get(batch_index)
            finite_prediction = predicted_values is not None and all(value is not None for value in predicted_values)
            best_index = max(range(len(targets)), key=lambda index: predicted_values[index]) if finite_prediction else None
            best_r = predicted_values[best_index] if best_index is not None else None
            reason = ("MISSING_SEQUENCE_FEATURES" if vector(pair) is None else
                      "INSUFFICIENT_TRAINING" if not sufficient else
                      "NONFINITE_PREDICTION" if not finite_prediction else
                      "EXPECTED_NET_R_NOT_ABOVE_THRESHOLD" if best_r <= min_expected_r else None)
            selected_index = best_index if reason is None else None
            selected_target = targets[selected_index] if selected_index is not None else None
            actions = []
            for target_index, target in enumerate(targets):
                row = pair["actions"][target]
                utility, exclusion = values[target_index]
                visible = end_cutoff is None or (row.get("label_end") is not None and _time(row["label_end"]) < end_cutoff)
                label = row.get("label") if visible and isinstance(row.get("label"), str) else None
                actions.append({"target_r": target,
                                "expected_net_r": predicted_values[target_index] if predicted_values is not None else None,
                                "baseline_net_r": baseline_r.get(target),
                                "p_tp": probabilities.get(target, {}).get(batch_index),
                                "baseline_p_tp": baseline_p.get(target),
                                "label": label, "label_end": row.get("label_end") if visible else None,
                                "y": int(label == "TP_FIRST") if utility is not None and label in RESOLVED_LABELS else None,
                                "evaluation_net_r": utility, "outcome_exclusion": exclusion,
                                "adverse_ambiguity": utility is not None and label == "AMBIGUOUS"})
            selected_action = actions[selected_index] if selected_index is not None else None
            known = selected_action is not None and selected_action["evaluation_net_r"] is not None
            destination["predictions"].append({
                "candidate_id": pair["candidate_id"], "family": pair["base"]["family"],
                "direction": pair["base"]["direction"], "as_of": pair["base"]["as_of"],
                "split_id": split_id, "train_n": len(train), "train_end": split["train_end"],
                "status": "SELECTED" if selected_target is not None else "ABSTAIN", "reason": reason,
                "selected_target_r": selected_target, "expected_net_r": best_r,
                "p_tp": selected_action["p_tp"] if selected_action is not None else None,
                "baseline_p_tp": selected_action["baseline_p_tp"] if selected_action is not None else None,
                "label": selected_action["label"] if selected_action is not None else None,
                "label_end": selected_action["label_end"] if selected_action is not None else None,
                "y": selected_action["y"] if selected_action is not None else None,
                "selected_evaluation_net_r": selected_action["evaluation_net_r"] if selected_action is not None else None,
                "selected_outcome_known": known, "common_scored": matched,
                "scored": selected_target is not None and matched,
                "net_r": selected_action["evaluation_net_r"] if selected_target is not None and matched else None,
                "actions": actions,
            })
        if not is_holdout:
            previous.extend(batch)
    for destination in (result, result.get("holdout")):
        if destination is None or (destination is not result and not evaluate_holdout):
            continue
        destination["metrics"] = _summary(destination["predictions"], targets, bootstrap_samples, seed)
        families = sorted({row["family"] for row in destination["predictions"]})
        destination["family_summaries"] = [
            {"family": family, **_summary([row for row in destination["predictions"] if row["family"] == family],
                                         targets, bootstrap_samples, seed)} for family in families]
    result["counts"].update(test_records=len(result["predictions"]), test_batches=len(result["splits"]),
                            fitted_batches=sum(split["status"] == "FITTED" for split in result["splits"]))
    if any(item["n"] for item in result["metrics"]["forecast_metrics"]):
        result["status"] = "OOS_EVALUATED_EXPLORATORY"
    if cutoff is not None and evaluate_holdout:
        destination = result["holdout"]
        if not holdout:
            destination["status"] = "NO_HOLDOUT_RECORDS"
        elif destination["split"]["status"] != "FITTED":
            destination["status"] = "INSUFFICIENT_TRAINING"
        elif destination["metrics"]["n"] < min_holdout:
            destination["status"] = "INSUFFICIENT_SCORED_HOLDOUT"
        else:
            destination["status"] = "HOLDOUT_EVALUATED"
    return result
