"""Purged chronological empirical forecasting; no tuning on held-out labels."""
from collections import Counter, defaultdict
from datetime import datetime, timezone
import math
import random
from statistics import mean

from .outcomes import RESOLVED_LABELS


def _time(value: str) -> datetime:
    result = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if result.tzinfo is None or result.utcoffset() is None:
        raise ValueError("research timestamps must be timezone-aware")
    return result.astimezone(timezone.utc)


def _eligible(record: dict) -> bool:
    value = record.get("net_r")
    return (record.get("label") in RESOLVED_LABELS and record.get("label_end") is not None
            and isinstance(value, (int, float)) and not isinstance(value, bool)
            and math.isfinite(value))


def _wilson(wins: int, n: int) -> list[float] | None:
    if not n:
        return None
    z = 1.959963984540054
    p = wins / n
    denominator = 1 + z * z / n
    middle = (p + z * z / (2 * n)) / denominator
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / denominator
    return [max(0.0, middle - half), min(1.0, middle + half)]


def _percentile(values: list[float], fraction: float) -> float:
    position = (len(values) - 1) * fraction
    low = int(position)
    high = min(low + 1, len(values) - 1)
    return values[low] + (values[high] - values[low]) * (position - low)


def _day_bootstrap(rows: list[dict], samples: int, seed: int, field: str = "net_r") -> tuple[list[float] | None, int]:
    blocks: dict[str, list[float]] = defaultdict(list)
    for row in rows:
        value = row.get(field)
        if isinstance(value, (int, float)) and math.isfinite(value):
            blocks[_time(row["as_of"]).date().isoformat()].append(value)
    days = sorted(blocks)
    if len(days) < 2 or samples < 2:
        return None, len(days)
    rng = random.Random(seed)
    estimates = []
    for _ in range(samples):
        selected = [value for day in rng.choices(days, k=len(days)) for value in blocks[day]]
        estimates.append(mean(selected))
    estimates.sort()
    return [_percentile(estimates, 0.025), _percentile(estimates, 0.975)], len(days)


def _metrics(predictions: list[dict]) -> dict:
    rows = [row for row in predictions if row["scored"]]
    if not rows:
        return {"n": 0, "brier": None, "baseline_brier": None,
                "brier_skill": None, "log_loss": None, "baseline_log_loss": None}
    brier = mean((row["p_tp"] - row["y"]) ** 2 for row in rows)
    baseline_brier = mean((row["baseline_p_tp"] - row["y"]) ** 2 for row in rows)

    def loss(probability: float, outcome: int) -> float:
        p = min(max(probability, 1e-12), 1 - 1e-12)
        return -(outcome * math.log(p) + (1 - outcome) * math.log(1 - p))

    return {
        "n": len(rows), "brier": brier, "baseline_brier": baseline_brier,
        "brier_skill": 1 - brier / baseline_brier if baseline_brier else None,
        "log_loss": mean(loss(row["p_tp"], row["y"]) for row in rows),
        "baseline_log_loss": mean(loss(row["baseline_p_tp"], row["y"]) for row in rows),
    }


def _batches(groups: list[list[dict]], size: int) -> list[list[dict]]:
    batches = []
    current: list[dict] = []
    for group in groups:
        current.extend(group)
        if len(current) >= size:
            batches.append(current)
            current = []
    if current:
        batches.append(current)
    return batches


def walk_forward(
    records: list[dict], *, min_train: int = 100, test_size: int = 50,
    min_family_train: int = 30, min_oos: int = 100,
    bootstrap_samples: int = 300, seed: int = 7,
) -> dict:
    """Forecast each whole timestamp batch using only previously finished labels.

    TP_FIRST is 1; SL_FIRST and TIMEOUT are 0.  This probability is *TP
    before stop within the chosen horizon*, not win rate or P(net R > 0).
    Every split fits a pooled beta(1, 1) posterior, then a family Bernoulli
    posterior with a two-observation prior centred on that training pool.
    No feature selection, test-driven threshold, or fitted ML calibration
    is performed.  Insufficient training yields None, never a fake 0%.
    """
    for name, value in (("min_train", min_train), ("test_size", test_size),
                        ("min_family_train", min_family_train), ("min_oos", min_oos)):
        if isinstance(value, bool) or not isinstance(value, int) or value < 1:
            raise ValueError(f"{name} must be a positive integer")
    if isinstance(bootstrap_samples, bool) or not isinstance(bootstrap_samples, int) or bootstrap_samples < 2:
        raise ValueError("bootstrap_samples must be at least two")
    ordered = sorted(records, key=lambda record: (_time(record["as_of"]), str(record["candidate_id"])))
    if len({record["candidate_id"] for record in ordered}) != len(ordered):
        raise ValueError("candidate ids must be unique")
    for record in ordered:
        if record.get("label_end") is not None and _time(record["label_end"]) < _time(record["as_of"]):
            raise ValueError("label_end precedes confirmation")
    # Never pool distinct instruments or resolutions into one probability.
    scopes = {(record.get("symbol"), record.get("timeframe")) for record in ordered}
    if len(scopes) > 1:
        raise ValueError("walk_forward requires one symbol and timeframe")
    groups: list[list[dict]] = []
    for record in ordered:
        if not groups or _time(record["as_of"]) != _time(groups[-1][0]["as_of"]):
            groups.append([])
        groups[-1].append(record)
    warmup = []
    split_index = 0
    while split_index < len(groups) and len(warmup) < min_train:
        warmup.extend(groups[split_index])
        split_index += 1
    batches = _batches(groups[split_index:], test_size)
    predictions = []
    splits = []
    previous = list(warmup)
    for split_id, batch in enumerate(batches, start=1):
        test_start = _time(batch[0]["as_of"])
        eligible_past = [row for row in previous if _eligible(row)]
        train = [row for row in eligible_past if _time(row["label_end"]) < test_start]
        sufficient = len(train) >= min_train
        family_train: dict[str, list[dict]] = defaultdict(list)
        for row in train:
            family_train[row["family"]].append(row)
        wins = sum(row["label"] == "TP_FIRST" for row in train)
        pooled_p = (wins + 1) / (len(train) + 2) if sufficient else None
        train_end = max((_time(row["label_end"]) for row in train), default=None)
        train_as_of_end = max((_time(row["as_of"]) for row in train), default=None)
        split = {
            "split_id": split_id, "test_start": test_start.isoformat(),
            "test_end": batch[-1]["as_of"], "test_records": len(batch),
            "train_n": len(train), "purged_overlap_n": len(eligible_past) - len(train),
            "train_end": train_end.isoformat() if train_end else None,
            "train_as_of_end": train_as_of_end.isoformat() if train_as_of_end else None,
            "pooled_p_tp": pooled_p,
            "status": "FITTED" if sufficient else "INSUFFICIENT_TRAINING",
        }
        splits.append(split)
        for row in batch:
            family_rows = family_train.get(row["family"], [])
            family_n = len(family_rows)
            family_wins = sum(item["label"] == "TP_FIRST" for item in family_rows)
            p_tp = None
            status = "INSUFFICIENT_TRAINING"
            if sufficient:
                status = "INSUFFICIENT_FAMILY_TRAINING"
                if family_n >= min_family_train:
                    p_tp = (family_wins + 2 * pooled_p) / (family_n + 2)
                    status = "FORECAST"
            scored = p_tp is not None and _eligible(row)
            predictions.append({
                "candidate_id": row["candidate_id"], "family": row["family"],
                "as_of": row["as_of"], "label_end": row.get("label_end"),
                "label": row.get("label"), "net_r": row.get("net_r"),
                "conservative_net_r": row.get("conservative_net_r"),
                "split_id": split_id, "train_n": len(train),
                "family_train_n": family_n, "family_train_wins": family_wins,
                "train_end": split["train_end"], "p_tp": p_tp,
                "baseline_p_tp": pooled_p, "status": status, "scored": scored,
                "y": int(row["label"] == "TP_FIRST") if _eligible(row) else None,
            })
        # No row from this test batch can enter its own training set.
        previous.extend(batch)

    profiles = []
    all_families = sorted({row["family"] for row in ordered})
    for family_index, family in enumerate(all_families):
        forecasts = [row for row in predictions if row["family"] == family and row["p_tp"] is not None]
        rows = [row for row in forecasts if row["scored"]]
        wins = sum(row["y"] for row in rows)
        ci, days = _day_bootstrap(rows, bootstrap_samples, seed + family_index)
        n = len(rows)
        split_count = len({row["split_id"] for row in rows})
        # Ambiguous outcomes enter only this explicitly adverse sensitivity.
        stress = [dict(row, stress_r=row["net_r"]) for row in rows]
        stress.extend(dict(row, stress_r=row["conservative_net_r"]) for row in forecasts
                      if row["label"] == "AMBIGUOUS" and row["conservative_net_r"] is not None)
        stress_ci, stress_days = _day_bootstrap(stress, bootstrap_samples, seed + family_index, "stress_r")
        reasons = []
        if n < min_oos:
            reasons.append("too_few_oos_labels")
        if days < 5:
            reasons.append("fewer_than_five_utc_day_clusters")
        if split_count < 2:
            reasons.append("fewer_than_two_fitted_test_batches")
        insufficient = bool(reasons)
        if ci is None or ci[0] <= 0:
            reasons.append("positive_expectancy_not_demonstrated")
        if stress_ci is None or stress_ci[0] <= 0:
            reasons.append("adverse_ambiguity_sensitivity_not_positive")
        support = ("INSUFFICIENT_EVIDENCE" if insufficient else
                   "NO_POSITIVE_EDGE" if reasons else "SUPPORTED_FOR_SHADOW_RESEARCH")
        profiles.append({
            "family": family, "n": n, "wins": wins,
            "p_tp": wins / n if n else None, "wilson_95": _wilson(wins, n),
            "mean_predicted_p_tp": mean(row["p_tp"] for row in rows) if rows else None,
            "mean_net_r": mean(row["net_r"] for row in rows) if rows else None,
            "mean_net_r_ci95": ci, "day_clusters": days, "split_count": split_count,
            "first_as_of": rows[0]["as_of"] if rows else None,
            "last_as_of": rows[-1]["as_of"] if rows else None,
            "metrics": _metrics(rows),
            "excluded_forecast_labels": dict(Counter(row["label"] for row in forecasts if not row["scored"])),
            "unforecast_records": sum(row["family"] == family and row["p_tp"] is None for row in predictions),
            "adverse_ambiguity_sensitivity": {
                "n": len(stress), "ambiguous_n": len(stress) - n,
                "mean_net_r": mean(row["stress_r"] for row in stress) if stress else None,
                "mean_net_r_ci95": stress_ci, "day_clusters": stress_days,
                "censored_outcomes": "unknown; excluded, not assumed losses or wins",
            },
            "support_status": support, "reasons": reasons,
        })
    metrics = _metrics(predictions)
    status = "OOS_EVALUATED" if metrics["n"] else "INSUFFICIENT_EVIDENCE"
    return {
        "status": status,
        "methodology": {
            "probability_target": "TP_FIRST vs SL_FIRST or TIMEOUT; ambiguous/censored/invalid excluded",
            "estimator": "training pooled beta(1,1); family posterior with two-observation pooled prior",
            "calibration": "empirical research probabilities; no fitted ML calibration or guarantee",
            "purge": "training label_end strictly earlier than whole test batch start",
            "grouping": "identical confirmation timestamps stay in one batch",
            "baseline": "training pooled posterior scored on exactly the same OOS labels",
            "wilson_caveat": "95% Bernoulli interval assumes independent labels; overlapping trades violate this",
            "bootstrap": "95% percentile bootstrap resampling entire UTC confirmation days",
            "bootstrap_caveat": "day blocks retain same-day dependence; cross-day dependence and regime shifts remain",
            "selection": "fixed supplied candidates and parameters; no OOS threshold optimization",
            "support_rule": "min_oos, five UTC days, two test batches, positive lower bootstrap mean R including ambiguity sensitivity",
            "scope": "research and shadow display only; not a live execution model",
        },
        "settings": {"min_train": min_train, "test_size": test_size,
                     "min_family_train": min_family_train, "min_oos": min_oos,
                     "bootstrap_samples": bootstrap_samples, "seed": seed},
        "counts": {
            "records": len(ordered), "eligible_labels": sum(_eligible(row) for row in ordered),
            "warmup_records": len(warmup), "warmup_timestamps": split_index,
            "test_records": len(predictions), "test_batches": len(splits),
            "fitted_batches": sum(split["status"] == "FITTED" for split in splits),
            "forecast_records": sum(row["p_tp"] is not None for row in predictions),
            "scored_oos": metrics["n"],
        },
        "exclusions": dict(Counter(row.get("label", "MISSING") for row in ordered if not _eligible(row))),
        "oos_metrics": metrics, "profiles": profiles, "splits": splits,
        "predictions": predictions,
    }
