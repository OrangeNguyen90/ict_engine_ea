"""Frozen research RR models with JSON weights and standard-library inference.

The payload is data, never executable serialization. Its digest detects changes;
it is not a signature, statistical validation, or permission to place orders.
Scikit-learn is imported only while fitting a new frozen model.
"""
from dataclasses import asdict, fields
import hashlib
import json
import math
from pathlib import Path
import warnings

from . import RESEARCH_VERSION
from .candidates import DETECTOR_VERSION
from .ml import FAMILIES, NUMERIC_FEATURES, _vector
from .outcomes import RESOLVED_LABELS
from .rr import _outcome, _paired_records, _sequence
from .types import ResearchConfig
from .validation import _time


SCHEMA_VERSION = 1
FEATURE_VERSION = "ict-rr-portable-features-1"
KIND = "ict_rr_portable"
MAX_TARGETS = 32
MAX_SEQUENCE_WINDOW = 256
MAX_BUNDLE_BYTES = 2_000_000
CODE_FILES = ("__init__.py", "candidates.py", "ml.py", "sequences.py", "rr.py", "types.py",
              "outcomes.py", "validation.py", "data.py", "predict.py", "portable_model.py")


def _finite(value):
    return (isinstance(value, (int, float)) and not isinstance(value, bool)
            and math.isfinite(value))


def _positive_int(value):
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _digest(value):
    return (isinstance(value, str) and len(value) == 64
            and all(character in "0123456789abcdef" for character in value))


def _stamp(value, name):
    if not isinstance(value, str):
        raise ValueError(f"{name} must be a timezone-aware timestamp")
    try:
        return _time(value)
    except (TypeError, ValueError, OverflowError) as exc:
        raise ValueError(f"{name} must be a timezone-aware timestamp") from exc


def _canonical(bundle):
    try:
        encoded = json.dumps({key: value for key, value in bundle.items() if key != "model_id"},
                             sort_keys=True, separators=(",", ":"), ensure_ascii=True,
                             allow_nan=False).encode("utf-8")
    except (TypeError, ValueError, OverflowError) as exc:
        raise ValueError("model payload must contain finite JSON data") from exc
    if len(encoded) > MAX_BUNDLE_BYTES:
        raise ValueError("model payload exceeds size limit")
    return encoded


def _code_hashes():
    directory = Path(__file__).resolve().parent
    try:
        return {name: hashlib.sha256((directory / name).read_bytes()).hexdigest() for name in CODE_FILES}
    except OSError as exc:
        raise ValueError("current inference code fingerprint cannot be verified") from exc


def _feature_schema(window):
    if window is not None and (not _positive_int(window) or window > MAX_SEQUENCE_WINDOW):
        raise ValueError(f"sequence_window must be 1..{MAX_SEQUENCE_WINDOW}")
    return {
        "version": FEATURE_VERSION, "mode": "sequence" if window is not None else "tabular",
        "numeric_features": list(NUMERIC_FEATURES), "missing_indicators": True,
        "families": list(FAMILIES), "categorical_order": ["long", "short", *FAMILIES],
        "sequence_window": window,
        "sequence_order": ["direction_open", "direction_favorable", "direction_adverse", "direction_close", "spread"],
        "sequence_normalization": "confirmation close anchor and confirmation ATR; oldest closed candle first",
        "dimension": 5 * window + 5 if window is not None else 2 * len(NUMERIC_FEATURES) + 5,
    }


def _config(config):
    if not isinstance(config, dict) or set(config) != {field.name for field in fields(ResearchConfig)}:
        raise ValueError("model config must contain the complete ResearchConfig schema")
    if not isinstance(config.get("symbol"), str) or not isinstance(config.get("timeframe"), str):
        raise ValueError("model config needs symbol and timeframe")
    if any(not _finite(value) for name, value in config.items() if name not in ("symbol", "timeframe")):
        raise ValueError("model config numeric values must be finite and non-boolean")
    if not _positive_int(config.get("timeframe_seconds")):
        raise ValueError("model timeframe_seconds must be a positive integer")
    try:
        return ResearchConfig(**config)
    except (TypeError, ValueError, AttributeError) as exc:
        raise ValueError("invalid model ResearchConfig") from exc


def _source(source, config):
    if not isinstance(source, dict) or not isinstance(source.get("quality"), dict):
        raise ValueError("model requires a verified research source manifest")
    quality = source["quality"]
    if (source.get("price_type") != "bid" or source.get("price_type_historically_verified") is not True
            or quality.get("coverage_verified") is not True or quality.get("export_complete") is not True):
        raise ValueError("model requires historically verified Bid prices, coverage and a complete export")
    for name in ("symbol", "timeframe", "timeframe_seconds", "point", "tick_size"):
        value = source.get(name)
        if name in ("point", "tick_size", "timeframe_seconds") and not _finite(value):
            raise ValueError("source instrument specification must be finite")
        if value != getattr(config, name):
            raise ValueError(f"source {name} does not match model config")
    if not _digest(source.get("csv_sha256")) or not _digest(source.get("metadata_sha256")):
        raise ValueError("source CSV and metadata SHA-256 digests are required")
    metadata = source.get("export_metadata", {})
    if not isinstance(metadata, dict):
        raise ValueError("source export_metadata must be a dictionary")
    for name in ("broker", "server"):
        if not isinstance(metadata.get(name), str) or not metadata[name].strip():
            raise ValueError("source broker/server identity must be nonempty")
    identity = {}
    for name in ("broker", "server", "source"):
        if name in metadata:
            if not isinstance(metadata[name], str) or len(metadata[name]) > 256:
                raise ValueError("source broker/server identity must be a bounded string")
            identity[name] = metadata[name]
    return {
        **{name: source[name] for name in ("symbol", "timeframe", "timeframe_seconds", "point", "tick_size",
                                         "price_type", "price_type_historically_verified", "csv_sha256", "metadata_sha256")},
        "quality": {"coverage_verified": True, "export_complete": True}, "export_metadata": identity,
    }


def _numbers(values, length, name):
    if not isinstance(values, list) or len(values) != length or not all(_finite(value) for value in values):
        raise ValueError(f"{name} has an invalid shape or nonfinite values")


def _matrix(values, rows, columns, name):
    if not isinstance(values, list) or len(values) != rows:
        raise ValueError(f"{name} has an invalid shape")
    for row in values:
        _numbers(row, columns, name)


def _record_vector(record, schema):
    if schema["mode"] == "tabular":
        return _vector(record)
    values = _sequence(record)
    if values is None or len(values) != 5 * schema["sequence_window"]:
        return None
    return values + _vector(record)[-5:]


def validate_model(bundle: dict) -> None:
    """Reject changed, incompatible, unverified or malformed model data."""
    if (not isinstance(bundle, dict) or not isinstance(bundle.get("schema_version"), int)
            or isinstance(bundle.get("schema_version"), bool) or bundle["schema_version"] != SCHEMA_VERSION):
        raise ValueError("unsupported portable model schema_version")
    if bundle.get("kind") != KIND or not _digest(bundle.get("model_id")):
        raise ValueError("invalid portable model kind or model_id")
    if hashlib.sha256(_canonical(bundle)).hexdigest() != bundle["model_id"]:
        raise ValueError("portable model digest mismatch")
    if (bundle.get("detector_version") != DETECTOR_VERSION or bundle.get("research_version") != RESEARCH_VERSION
            or bundle.get("scope") != "RESEARCH_ADVISORY" or bundle.get("execution_allowed") is not False
            or bundle.get("source_gate") != "VERIFIED"):
        raise ValueError("model version, source gate or advisory scope is incompatible")
    code = bundle.get("code_sha256")
    if (not isinstance(code, dict) or set(code) != set(CODE_FILES) or not all(_digest(value) for value in code.values())
            or code != _code_hashes()):
        raise ValueError("model code fingerprint is incompatible with current inference")
    config = _config(bundle.get("config"))
    normalized_source = _source(bundle.get("source"), config)
    if bundle["source"] != normalized_source:
        raise ValueError("model source must use the normalized provenance schema")
    schema = bundle.get("feature_schema")
    if not isinstance(schema, dict) or schema != _feature_schema(schema.get("sequence_window")):
        raise ValueError("model feature schema is incompatible")
    if bundle.get("sequence_window") != schema["sequence_window"]:
        raise ValueError("model sequence_window does not match its feature schema")
    targets = bundle.get("targets_r")
    if (not isinstance(targets, list) or not 2 <= len(targets) <= MAX_TARGETS
            or any(not _finite(target) or target <= 0 for target in targets)
            or targets != sorted(set(targets))):
        raise ValueError("model targets must be unique, sorted, positive and bounded")
    if not _finite(bundle.get("min_expected_r")):
        raise ValueError("model min_expected_r must be finite")
    cutoff = _stamp(bundle.get("fit_cutoff"), "fit_cutoff")
    context_start = _stamp(bundle.get("context_start"), "context_start")
    train_end = _stamp(bundle.get("train_end"), "train_end")
    train_start = _stamp(bundle.get("train_as_of_start"), "train_as_of_start")
    train_last = _stamp(bundle.get("train_as_of_end"), "train_as_of_end")
    if not context_start <= train_start <= train_last <= train_end < cutoff:
        raise ValueError("model training times must precede fit_cutoff and follow context_start")
    if not _digest(bundle.get("training_prefix_sha256")):
        raise ValueError("model training prefix SHA-256 is required")
    if not _positive_int(bundle.get("train_n")):
        raise ValueError("model train_n must be positive")
    settings = bundle.get("training_settings")
    if (not isinstance(settings, dict) or not _positive_int(settings.get("min_train"))
            or not _positive_int(settings.get("min_mlp_train"))
            or isinstance(settings.get("seed"), bool) or not isinstance(settings.get("seed"), int)
            or not 0 <= settings["seed"] <= 2 ** 32 - 1):
        raise ValueError("model training settings are invalid")
    dimension = schema["dimension"]
    scaler = bundle.get("scaler")
    if not isinstance(scaler, dict) or set(scaler) != {"mean", "scale"}:
        raise ValueError("model scaler schema is invalid")
    _numbers(scaler["mean"], dimension, "scaler mean")
    _numbers(scaler["scale"], dimension, "scaler scale")
    if any(value <= 0 for value in scaler["scale"]):
        raise ValueError("model scaler scales must be positive")
    estimator = bundle.get("estimator")
    if not isinstance(estimator, dict):
        raise ValueError("model estimator is missing")
    if estimator.get("type") == "ridge":
        if set(estimator) != {"type", "alpha", "coef", "intercept"} or not _finite(estimator["alpha"]) or estimator["alpha"] != 1:
            raise ValueError("model Ridge parameters are incompatible")
        _matrix(estimator["coef"], len(targets), dimension, "Ridge coef")
        _numbers(estimator["intercept"], len(targets), "Ridge intercept")
        minimum = settings["min_train"]
    elif estimator.get("type") == "mlp":
        if (set(estimator) != {"type", "hidden_activation", "output_activation", "layers"}
                or estimator.get("hidden_activation") != "relu" or estimator.get("output_activation") != "identity"):
            raise ValueError("model MLP activations are incompatible")
        layers = estimator.get("layers")
        if not isinstance(layers, list) or len(layers) != 3:
            raise ValueError("model MLP must have two fixed hidden layers")
        for layer, inputs, outputs in zip(layers, (dimension, 32, 16), (32, 16, len(targets))):
            if not isinstance(layer, dict) or set(layer) != {"weights", "bias"}:
                raise ValueError("model MLP layer schema is invalid")
            _matrix(layer["weights"], inputs, outputs, "MLP weights")
            _numbers(layer["bias"], outputs, "MLP bias")
        minimum = max(settings["min_train"], settings["min_mlp_train"])
    else:
        raise ValueError("unsupported model estimator")
    if bundle["train_n"] < minimum:
        raise ValueError("model training minimum is not satisfied")
    classifiers = bundle.get("logistic")
    if not isinstance(classifiers, list) or len(classifiers) != len(targets):
        raise ValueError("model logistic classifiers do not match targets")
    for target, classifier in zip(targets, classifiers):
        if not isinstance(classifier, dict) or classifier.get("target_r") != target:
            raise ValueError("model logistic action ordering is invalid")
        n = classifier.get("train_n")
        if isinstance(n, bool) or not isinstance(n, int) or not 0 <= n <= bundle["train_n"]:
            raise ValueError("model logistic train_n is invalid")
        baseline = classifier.get("baseline_p_tp")
        if baseline is not None and (not _finite(baseline) or not 0 <= baseline <= 1):
            raise ValueError("model logistic baseline is invalid")
        status = classifier.get("status")
        if status == "FITTED":
            classes = classifier.get("classes")
            if (n < settings["min_train"] or classes != [0, 1] or baseline is None
                    or not isinstance(classes, list) or any(isinstance(value, bool) for value in classes)):
                raise ValueError("model logistic classes or sample minimum are invalid")
            _numbers(classifier.get("coef"), dimension, "logistic coef")
            if not _finite(classifier.get("intercept")):
                raise ValueError("model logistic intercept is invalid")
        elif status in ("ONE_CLASS", "INSUFFICIENT_TRAINING"):
            if classifier.get("coef") is not None or classifier.get("intercept") is not None or classifier.get("classes") is not None:
                raise ValueError("unfitted logistic classifier must not contain coefficients")
            if ((status == "ONE_CLASS" and (n < settings["min_train"] or baseline is None))
                    or (status == "INSUFFICIENT_TRAINING" and (n >= settings["min_train"] or baseline is not None))):
                raise ValueError("unfitted logistic classifier status is inconsistent")
        else:
            raise ValueError("model logistic status is invalid")
    warnings_list = bundle.get("convergence_warnings")
    if not isinstance(warnings_list, list) or not all(isinstance(item, str) and len(item) <= 4000 for item in warnings_list):
        raise ValueError("model convergence warnings are invalid")
    family_counts = bundle.get("train_by_family")
    direction_counts = bundle.get("train_by_direction")
    if (not isinstance(family_counts, dict) or not family_counts or not set(family_counts).issubset(FAMILIES)
            or any(not _positive_int(n) for n in family_counts.values()) or sum(family_counts.values()) != bundle["train_n"]
            or not isinstance(direction_counts, dict) or not direction_counts or not set(direction_counts).issubset({"1", "-1"})
            or any(not _positive_int(n) for n in direction_counts.values()) or sum(direction_counts.values()) != bundle["train_n"]):
        raise ValueError("model training applicability counts are invalid")


def fit_model(records_by_target, *, config: ResearchConfig, fit_cutoff: str,
              source: dict, context_start: str, min_train=100, min_mlp_train=200,
              model="ridge", sequence_window=None, min_expected_r=0.0, seed=7,
              training_prefix_sha256: str) -> dict:
    """Fit once on outcomes completed strictly before an explicit cutoff."""
    if not isinstance(config, ResearchConfig):
        raise ValueError("config must be a ResearchConfig")
    _config(asdict(config))
    provenance = _source(source, config)
    cutoff = _stamp(fit_cutoff, "fit_cutoff")
    context = _stamp(context_start, "context_start")
    if context >= cutoff or not _digest(training_prefix_sha256):
        raise ValueError("context_start must precede cutoff and training_prefix_sha256 must be SHA-256")
    if not _positive_int(min_train) or not _positive_int(min_mlp_train):
        raise ValueError("training minimums must be positive integers")
    if isinstance(seed, bool) or not isinstance(seed, int) or not 0 <= seed <= 2 ** 32 - 1:
        raise ValueError("seed must be an integer between 0 and 2**32-1")
    if model not in ("ridge", "mlp") or not _finite(min_expected_r):
        raise ValueError("model must be ridge or mlp and min_expected_r must be finite")
    schema = _feature_schema(sequence_window)
    targets, pairs, dimension = _paired_records(records_by_target, cutoff, False, schema["mode"])
    if len(targets) > MAX_TARGETS:
        raise ValueError(f"at most {MAX_TARGETS} targets are supported")
    if sequence_window is not None and dimension is not None and dimension != 5 * sequence_window:
        raise ValueError("sequence dimension does not match declared sequence_window")
    train = [pair for pair in pairs if pair["as_of"] < cutoff
             and all(_outcome(row, cutoff)[0] is not None for row in pair["actions"].values())
             and _record_vector(pair["base"], schema) is not None]
    minimum = max(min_train, min_mlp_train) if model == "mlp" else min_train
    if len(train) < minimum:
        raise ValueError("insufficient matched completed training records")
    for pair in train:
        base = pair["base"]
        if base.get("symbol") != config.symbol or base.get("timeframe") != config.timeframe or pair["as_of"] < context:
            raise ValueError("training records do not match model scope or context_start")
        features = base.get("features")
        if (base.get("family") not in FAMILIES or not isinstance(features, dict)
                or features.get("detector_version") != DETECTOR_VERSION):
            raise ValueError("training records require the current detector feature version and known families")
    try:
        from sklearn.exceptions import ConvergenceWarning
        from sklearn.linear_model import LogisticRegression, Ridge
        from sklearn.neural_network import MLPRegressor
        from sklearn.preprocessing import StandardScaler
        import sklearn
    except ImportError as exc:
        raise ValueError("fitting requires the optional scikit-learn research dependency") from exc
    scaler = StandardScaler()
    x = scaler.fit_transform([_record_vector(pair["base"], schema) for pair in train])
    y = [[_outcome(pair["actions"][target], cutoff)[0] for target in targets] for pair in train]
    estimator = (Ridge(alpha=1.0) if model == "ridge" else
                 MLPRegressor(hidden_layer_sizes=(32, 16), max_iter=500, random_state=seed, early_stopping=False))
    convergence = []
    with warnings.catch_warnings(record=True) as caught:
        warnings.simplefilter("always", ConvergenceWarning)
        estimator.fit(x, y)
        convergence.extend(f"{model}: {item.message}" for item in caught if issubclass(item.category, ConvergenceWarning))
    if model == "ridge":
        weights = {"type": model, "alpha": 1.0, "coef": estimator.coef_.tolist(), "intercept": estimator.intercept_.tolist()}
    else:
        weights = {"type": model, "hidden_activation": estimator.activation,
                   "output_activation": estimator.out_activation_,
                   "layers": [{"weights": matrix.tolist(), "bias": bias.tolist()}
                              for matrix, bias in zip(estimator.coefs_, estimator.intercepts_)]}
    logistic = []
    for target in targets:
        indices = [index for index, pair in enumerate(train) if pair["actions"][target]["label"] in RESOLVED_LABELS]
        labels = [int(train[index]["actions"][target]["label"] == "TP_FIRST") for index in indices]
        status = ("INSUFFICIENT_TRAINING" if len(indices) < min_train else
                  "ONE_CLASS" if len(set(labels)) < 2 else "FITTED")
        classifier_data = {"target_r": target, "train_n": len(indices), "status": status,
                           "baseline_p_tp": (sum(labels) + 1) / (len(labels) + 2) if len(labels) >= min_train else None,
                           "classes": None, "coef": None, "intercept": None}
        if status == "FITTED":
            with warnings.catch_warnings(record=True) as caught:
                warnings.simplefilter("always", ConvergenceWarning)
                classifier = LogisticRegression(max_iter=1000, random_state=seed).fit(x[indices], labels)
                convergence.extend(f"logistic target={target}: {item.message}" for item in caught
                                   if issubclass(item.category, ConvergenceWarning))
            classifier_data.update(classes=classifier.classes_.tolist(), coef=classifier.coef_[0].tolist(),
                                   intercept=float(classifier.intercept_[0]))
        logistic.append(classifier_data)
    families, directions = {}, {}
    for pair in train:
        family, direction = pair["base"]["family"], str(pair["base"]["direction"])
        families[family] = families.get(family, 0) + 1
        directions[direction] = directions.get(direction, 0) + 1
    bundle = {
        "schema_version": SCHEMA_VERSION, "kind": KIND, "research_version": RESEARCH_VERSION,
        "detector_version": DETECTOR_VERSION, "feature_schema": schema, "sequence_window": sequence_window,
        "scope": "RESEARCH_ADVISORY", "execution_allowed": False, "source_gate": "VERIFIED",
        "config": asdict(config), "source": provenance, "code_sha256": _code_hashes(),
        "context_start": context.isoformat(), "fit_cutoff": cutoff.isoformat(),
        "training_prefix_sha256": training_prefix_sha256,
        "train_end": max(_time(row["label_end"]) for pair in train for row in pair["actions"].values()).isoformat(),
        "train_as_of_start": min(pair["as_of"] for pair in train).isoformat(),
        "train_as_of_end": max(pair["as_of"] for pair in train).isoformat(),
        "train_n": len(train), "train_by_family": families, "train_by_direction": directions,
        "training_settings": {"min_train": min_train, "min_mlp_train": min_mlp_train, "seed": seed},
        "targets_r": targets, "min_expected_r": float(min_expected_r), "sklearn_version": sklearn.__version__,
        "scaler": {"mean": scaler.mean_.tolist(), "scale": scaler.scale_.tolist()},
        "estimator": weights, "logistic": logistic, "convergence_warnings": convergence,
        "probability_note": "uncalibrated TP-before-stop forecast; timeout is zero, ambiguity excluded; not net-profit probability",
        "validation_note": "source verification and numerical portability do not establish predictive or trading performance",
    }
    bundle["model_id"] = hashlib.sha256(_canonical(bundle)).hexdigest()
    validate_model(bundle)
    return bundle


def _dot(left, right):
    try:
        value = math.fsum(a * b for a, b in zip(left, right))
    except (ValueError, OverflowError):
        return None
    return value if math.isfinite(value) else None


def _net_r(bundle, vector):
    estimator = bundle["estimator"]
    if estimator["type"] == "ridge":
        values = [_dot(coef, vector) for coef in estimator["coef"]]
        return [value + bias if value is not None and math.isfinite(value + bias) else None
                for value, bias in zip(values, estimator["intercept"])]
    values = vector
    for index, layer in enumerate(estimator["layers"]):
        outputs = []
        for column, bias in enumerate(layer["bias"]):
            value = _dot(values, [row[column] for row in layer["weights"]])
            if value is None or not math.isfinite(value + bias):
                return None
            outputs.append(max(0.0, value + bias) if index < len(estimator["layers"]) - 1 else value + bias)
        values = outputs
    return values


def _sigmoid(value):
    if value >= 0:
        return 1 / (1 + math.exp(-value))
    exp_value = math.exp(value)
    return exp_value / (1 + exp_value)


def predict_record(bundle: dict, record: dict) -> dict:
    """Infer from confirmation features only; the caller owns candle freshness.

    Candle replay, context-prefix verification and a current UTC freshness gate
    belong to the transport adapter. This function never reads outcome or entry
    fields and can never return permission for order submission.
    """
    validate_model(bundle)
    output = {"model_id": bundle["model_id"], "scope": "RESEARCH_ADVISORY", "execution_allowed": False,
              "source_gate": "VERIFIED", "status": "ABSTAIN", "reason": None,
              "selected_target_r": None, "expected_net_r": None, "p_tp": None, "actions": []}
    if not isinstance(record, dict):
        output["reason"] = "INVALID_RECORD"
        return output
    output.update(candidate_id=record.get("candidate_id") if isinstance(record.get("candidate_id"), str) else None,
                  as_of=record.get("as_of") if isinstance(record.get("as_of"), str) else None,
                  family=record.get("family") if isinstance(record.get("family"), str) else None,
                  direction=record.get("direction") if _finite(record.get("direction")) else None)
    config = bundle["config"]
    if record.get("symbol") != config["symbol"] or record.get("timeframe") != config["timeframe"]:
        output["reason"] = "SCOPE_MISMATCH"
        return output
    if not isinstance(record.get("candidate_id"), str) or not record["candidate_id"]:
        output["reason"] = "MISSING_CANDIDATE_ID"
        return output
    try:
        confirmation = _stamp(record.get("as_of"), "record as_of")
    except ValueError:
        output["reason"] = "INVALID_CONFIRMATION"
        return output
    if confirmation < _time(bundle["fit_cutoff"]):
        output["reason"] = "BEFORE_FIT_CUTOFF"
        return output
    family, direction = record.get("family"), record.get("direction")
    if (not isinstance(family, str) or family not in bundle["train_by_family"]
            or isinstance(direction, bool) or direction not in (-1, 1) or str(direction) not in bundle["train_by_direction"]):
        output["reason"] = "UNSEEN_FAMILY_OR_DIRECTION"
        return output
    features = record.get("features")
    if not isinstance(features, dict) or features.get("detector_version") != DETECTOR_VERSION:
        output["reason"] = "FEATURE_VERSION_MISMATCH"
        return output
    vector = _record_vector(record, bundle["feature_schema"])
    if vector is None:
        output["reason"] = "MISSING_SEQUENCE_FEATURES"
        return output
    scaled = [(value - center) / scale for value, center, scale in
              zip(vector, bundle["scaler"]["mean"], bundle["scaler"]["scale"])]
    if not all(math.isfinite(value) for value in scaled):
        output["reason"] = "NONFINITE_FEATURES"
        return output
    expected = _net_r(bundle, scaled)
    if expected is None or any(value is None for value in expected):
        output["reason"] = "NONFINITE_PREDICTION"
        return output
    for target, net_r, classifier in zip(bundle["targets_r"], expected, bundle["logistic"]):
        probability = None
        if classifier["status"] == "FITTED":
            score = _dot(classifier["coef"], scaled)
            if score is not None and math.isfinite(score + classifier["intercept"]):
                probability = _sigmoid(score + classifier["intercept"])
        probability_status = ("NONFINITE_PREDICTION" if classifier["status"] == "FITTED" and probability is None
                              else classifier["status"])
        output["actions"].append({"target_r": target, "expected_net_r": net_r, "p_tp": probability,
                                  "probability_status": probability_status})
    best = max(output["actions"], key=lambda action: action["expected_net_r"])
    output["expected_net_r"] = best["expected_net_r"]
    if best["expected_net_r"] <= bundle["min_expected_r"]:
        output["reason"] = "EXPECTED_NET_R_NOT_ABOVE_THRESHOLD"
        return output
    output.update(status="SELECTED", reason="MAX_EXPECTED_NET_R", selected_target_r=best["target_r"], p_tp=best["p_tp"])
    return output
