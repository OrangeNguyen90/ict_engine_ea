"""Descriptive evaluation of already generated out-of-sample probabilities.

This module does not fit, adjust, select, or validate the origin of predictions.
The caller must ensure forecasts were generated without using their outcomes.
"""
from bisect import bisect_right
import math
from statistics import mean


def _probability(value):
    return (isinstance(value, (int, float)) and not isinstance(value, bool)
            and math.isfinite(value) and 0 <= value <= 1)


def _loss(probability, outcome):
    # Clamp only for logarithms; Brier scores and bins use the original value.
    p = min(max(probability, 1e-12), 1 - 1e-12)
    return -(outcome * math.log(p) + (1 - outcome) * math.log(1 - p))


def calibration_report(predictions: list[dict], probability_field: str, *,
                       bins: int = 10, min_samples: int = 30) -> dict:
    """Score matched eligible predictions and summarize fixed-width bins.

    Only rows with ``scored is True``, a binary ``y``, and finite model and
    baseline probabilities in [0, 1] are included. Exclusion counts are
    mutually exclusive in that order. Bins are left-closed/right-open except
    the final bin includes 1.0. No calibration model is fitted.
    """
    if not isinstance(probability_field, str) or not probability_field:
        raise ValueError("probability_field must be a non-empty string")
    if isinstance(bins, bool) or not isinstance(bins, int) or not 1 <= bins <= 100:
        raise ValueError("bins must be an integer between 1 and 100")
    if isinstance(min_samples, bool) or not isinstance(min_samples, int) or min_samples < 1:
        raise ValueError("min_samples must be a positive integer")

    counts = {"input": len(predictions), "unscored": 0, "invalid_label": 0,
              "invalid_probability": 0, "invalid_baseline": 0, "included": 0}
    included = []
    grouped = [[] for _ in range(bins)]
    boundaries = [index / bins for index in range(1, bins)]
    for row in predictions:
        if row.get("scored") is not True:
            counts["unscored"] += 1
            continue
        y = row.get("y")
        if isinstance(y, bool) or not isinstance(y, (int, float)) or y not in (0, 1):
            counts["invalid_label"] += 1
            continue
        p = row.get(probability_field)
        if not _probability(p):
            counts["invalid_probability"] += 1
            continue
        baseline = row.get("baseline_p_tp")
        if not _probability(baseline):
            counts["invalid_baseline"] += 1
            continue
        included.append((p, baseline, y))
        grouped[bisect_right(boundaries, p)].append((p, y))
    n = len(included)
    counts["included"] = n
    reliability = []
    for index, group in enumerate(grouped):
        reliability.append({
            "lower": index / bins, "upper": (index + 1) / bins,
            "upper_inclusive": index == bins - 1, "n": len(group),
            "mean_probability": mean(item[0] for item in group) if group else None,
            "observed_frequency": mean(item[1] for item in group) if group else None,
        })
    ece = (sum(item["n"] * abs(item["mean_probability"] - item["observed_frequency"])
               for item in reliability if item["n"]) / n if n else None)
    metrics = {
        "n": n,
        "brier": mean((p - y) ** 2 for p, _, y in included) if n else None,
        "baseline_brier": mean((baseline - y) ** 2 for _, baseline, y in included) if n else None,
        "log_loss": mean(_loss(p, y) for p, _, y in included) if n else None,
        "baseline_log_loss": mean(_loss(baseline, y) for _, baseline, y in included) if n else None,
        "ece": ece,
    }
    return {
        "status": "NO_SCORED_ROWS" if not n else "SMALL_SAMPLE" if n < min_samples else "DESCRIPTIVE",
        "probability_field": probability_field,
        "settings": {"bins": bins, "min_samples": min_samples},
        "counts": counts, "metrics": metrics, "reliability_bins": reliability,
        "caveats": [
            "Caller must supply genuinely out-of-sample forecasts; this function cannot verify temporal isolation.",
            "ECE and bin frequencies are descriptive, sensitive to binning and sample size, and are not a calibration guarantee.",
            "Overlapping outcomes and regime changes can make observations dependent; no uncertainty interval is asserted.",
            "Comparisons use identical included rows; sparse or empty bins provide little or no evidence.",
        ],
    }
