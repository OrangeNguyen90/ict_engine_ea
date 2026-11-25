"""Frozen model portability, causal fit isolation and applicability tests."""
import builtins
from copy import deepcopy
from datetime import datetime, timedelta, timezone
import hashlib
from importlib.util import find_spec
import json
import unittest
from unittest.mock import patch
import warnings

from .research.candidates import DETECTOR_VERSION
from .research.ml import _vector
from .research.portable_model import fit_model, predict_record, validate_model
from .research.rr import _outcome
from .research.types import ResearchConfig
from .research.validation import _time


BASE = datetime(2024, 1, 1, tzinfo=timezone.utc)
CUTOFF = (BASE + timedelta(days=8)).isoformat()


def config():
    return ResearchConfig("TEST", "M15", 900, 0.1, 0.1, horizon_bars=2,
                          commission_r=0.05, slippage_ticks=0)


def source():
    return {"symbol": "TEST", "timeframe": "M15", "timeframe_seconds": 900,
            "point": 0.1, "tick_size": 0.1, "price_type": "bid",
            "price_type_historically_verified": True,
            "csv_sha256": "a" * 64, "metadata_sha256": "b" * 64,
            "quality": {"coverage_verified": True, "export_complete": True},
            "export_metadata": {"broker": "Synthetic test broker", "server": "fixture",
                                "source": "synthetic unit-test fixture"}}


def observations(count=12):
    return {target: [
        {"candidate_id": str(index), "symbol": "TEST", "timeframe": "M15",
         "family": "SWEEP_RECLAIM", "direction": 1, "target_r": target,
         "as_of": (BASE + timedelta(days=index)).isoformat(),
         "label_end": (BASE + timedelta(days=index, minutes=15)).isoformat(),
         "label": "TP_FIRST" if index % 2 else "TIMEOUT",
         "net_r": target if index % 2 else 0.2,
         "conservative_net_r": target if index % 2 else 0.2,
         "features": {"detector_version": DETECTOR_VERSION, "atr": 1.0,
                      "body_ratio": index % 3 / 3, "sweep_depth_atr": index / 10},
         "sequence_features": [index / 10, 0.2, -0.1, index / 20, 0.01] * 2}
        for index in range(count)] for target in (1.0, 3.0)}


def rehash(bundle):
    """Exercise schema validation independently of the integrity check."""
    material = {key: value for key, value in bundle.items() if key != "model_id"}
    bundle["model_id"] = hashlib.sha256(json.dumps(material, sort_keys=True, separators=(",", ":"),
                                                   ensure_ascii=True, allow_nan=False).encode("utf-8")).hexdigest()
    return bundle


@unittest.skipUnless(find_spec("sklearn"), "optional scikit-learn not installed")
class PortableModelTests(unittest.TestCase):
    def fit(self, rows=None, **options):
        settings = {"config": config(), "fit_cutoff": CUTOFF, "source": source(),
                    "context_start": (BASE - timedelta(days=1)).isoformat(),
                    "min_train": 4, "min_mlp_train": 4, "seed": 7,
                    "training_prefix_sha256": "c" * 64}
        settings.update(options)
        return fit_model(observations() if rows is None else rows, **settings)

    def parity(self, model, sequence_window=None):
        from sklearn.linear_model import LogisticRegression, Ridge
        from sklearn.neural_network import MLPRegressor
        from sklearn.preprocessing import StandardScaler
        from sklearn.exceptions import ConvergenceWarning

        rows = observations()
        # Different action censoring is excluded once per setup; ambiguity has
        # a conservative regression utility and is omitted only by its classifier.
        rows[3.0][4].update(label="AMBIGUOUS", net_r=None, conservative_net_r=-1.0)
        rows[3.0][6]["label_end"] = CUTOFF
        bundle = self.fit(rows, model=model, sequence_window=sequence_window)
        targets = sorted(rows)
        indices = [index for index in range(8)
                   if all(_outcome(rows[target][index], _time(CUTOFF))[0] is not None for target in targets)]
        vector = (lambda row: row["sequence_features"] + _vector(row)[-5:]) if sequence_window else _vector
        scaler = StandardScaler().fit([vector(rows[1.0][index]) for index in indices])
        x = scaler.transform([vector(rows[1.0][index]) for index in indices])
        x_test = scaler.transform([vector(rows[1.0][8])])
        y = [[_outcome(rows[target][index], _time(CUTOFF))[0] for target in targets] for index in indices]
        estimator = (Ridge(alpha=1.0) if model == "ridge" else
                     MLPRegressor(hidden_layer_sizes=(32, 16), max_iter=500, random_state=7, early_stopping=False))
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", ConvergenceWarning)
            expected = estimator.fit(x, y).predict(x_test)[0]
        result = predict_record(json.loads(json.dumps(bundle, allow_nan=False)), rows[1.0][8])
        for target_index, (action, expected_r) in enumerate(zip(result["actions"], expected)):
            self.assertAlmostEqual(action["expected_net_r"], float(expected_r), places=10)
            classifier_indices = [position for position, index in enumerate(indices)
                                  if rows[targets[target_index]][index]["label"] != "AMBIGUOUS"]
            labels = [int(rows[targets[target_index]][indices[position]]["label"] == "TP_FIRST")
                      for position in classifier_indices]
            expected_p = LogisticRegression(max_iter=1000, random_state=7).fit(x[classifier_indices], labels).predict_proba(x_test)[0, 1]
            self.assertAlmostEqual(action["p_tp"], float(expected_p), places=10)
        self.assertEqual(bundle["train_n"], 7)
        self.assertEqual(bundle["scaler"]["mean"], scaler.mean_.tolist())
        self.assertEqual(bundle["scaler"]["scale"], scaler.scale_.tolist())
        self.assertFalse(result["execution_allowed"])
        self.assertEqual(bundle["scope"], "RESEARCH_ADVISORY")
        self.assertEqual(bundle["source_gate"], "VERIFIED")
        return bundle, result

    def test_ridge_and_logistic_match_sklearn_after_json_roundtrip(self):
        self.parity("ridge")

    def test_sequence_mlp_and_logistic_match_sklearn_after_json_roundtrip(self):
        self.parity("mlp", sequence_window=2)

    def test_future_and_cutoff_boundary_outcomes_cannot_change_model(self):
        rows = observations()
        rows[3.0][6]["label_end"] = CUTOFF
        before = self.fit(rows)
        changed = deepcopy(rows)
        changed[3.0][6].update(label={"unavailable": True}, net_r=float("nan"), conservative_net_r=-999.0)
        for records in changed.values():
            for row in records[8:]:
                row.update(label={"unread": True}, label_end="invalid", net_r=float("nan"),
                           features={"future": float("inf")}, direction=None, family=None,
                           target_r="unread", sequence_features=[float("nan")])
        self.assertEqual(before, self.fit(changed))
        self.assertEqual(before["train_n"], 7)
        self.assertLess(_time(before["train_end"]), _time(CUTOFF))

    def test_inference_uses_no_sklearn_numpy_or_pickle_and_ignores_outcomes(self):
        rows = observations()
        bundle = self.fit(rows)
        first = predict_record(bundle, rows[1.0][8])
        changed = deepcopy(rows[1.0][8])
        changed.update(label={"unknown": True}, label_end="invalid", net_r=float("nan"),
                       entry=1e99, exit_price=-1e99, conservative_net_r=float("inf"))
        changed["features"]["future_profit"] = float("nan")
        original_import = builtins.__import__

        def guarded_import(name, *args, **kwargs):
            if name.split(".")[0] in {"sklearn", "numpy", "scipy", "pickle", "joblib"}:
                raise AssertionError("portable inference imported a model runtime")
            return original_import(name, *args, **kwargs)

        with patch("builtins.__import__", guarded_import):
            second = predict_record(bundle, changed)
        self.assertEqual(first, second)
        json.dumps(second, allow_nan=False)

    def test_unverified_or_different_source_cannot_fit(self):
        for path, value in (("price_type", "last"), ("price_type_historically_verified", False),
                            ("symbol", "OTHER"), ("point", 0.01), ("csv_sha256", "bad")):
            provenance = source()
            provenance[path] = value
            with self.subTest(path=path), self.assertRaises(ValueError):
                self.fit(source=provenance)
        for name in ("coverage_verified", "export_complete"):
            provenance = source()
            provenance["quality"][name] = False
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, "verified"):
                self.fit(source=provenance)
        for name in ("broker", "server"):
            for value in (None, "", "   "):
                provenance = source()
                if value is None:
                    del provenance["export_metadata"][name]
                else:
                    provenance["export_metadata"][name] = value
                with self.subTest(identity=name, value=value), self.assertRaisesRegex(ValueError, "nonempty"):
                    self.fit(source=provenance)
        malformed = self.fit()
        malformed["source"]["export_metadata"] = {}
        with self.assertRaisesRegex(ValueError, "nonempty"):
            validate_model(rehash(malformed))

    def test_insufficient_training_and_unseen_schema_cannot_fit(self):
        with self.assertRaisesRegex(ValueError, "insufficient"):
            self.fit(min_train=20)
        with self.assertRaisesRegex(ValueError, "insufficient"):
            self.fit(model="mlp", min_mlp_train=20)
        for field, value in (("family", "UNKNOWN"), ("symbol", "OTHER")):
            rows = observations()
            for records in rows.values():
                records[0][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.fit(rows)
        rows = observations()
        for records in rows.values():
            records[0]["features"]["detector_version"] = "changed"
        with self.assertRaisesRegex(ValueError, "detector feature version"):
            self.fit(rows)

    def test_tampering_or_code_version_drift_is_rejected(self):
        bundle = self.fit()
        changed = deepcopy(bundle)
        changed["estimator"]["coef"][0][0] += 0.5
        with self.assertRaisesRegex(ValueError, "digest mismatch"):
            validate_model(changed)
        for field, value in (("detector_version", "changed"), ("research_version", "changed"),
                             ("scope", "EXECUTION"), ("execution_allowed", True), ("source_gate", "UNVERIFIED")):
            changed = deepcopy(bundle)
            changed[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                validate_model(rehash(changed))
        changed = deepcopy(bundle)
        changed["code_sha256"]["candidates.py"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "code fingerprint"):
            validate_model(rehash(changed))

    def test_valid_digest_does_not_bypass_shape_or_feature_validation(self):
        bundle = self.fit()
        changes = []
        changed = deepcopy(bundle)
        changed["scaler"]["scale"][0] = 0.0
        changes.append(changed)
        changed = deepcopy(bundle)
        changed["estimator"]["coef"][0].pop()
        changes.append(changed)
        changed = deepcopy(bundle)
        changed["feature_schema"]["numeric_features"].reverse()
        changes.append(changed)
        changed = deepcopy(bundle)
        changed["source"]["quality"]["coverage_verified"] = False
        changes.append(changed)
        changed = deepcopy(bundle)
        changed["logistic"][0]["classes"] = [1, 0]
        changes.append(changed)
        changed = deepcopy(bundle)
        changed["train_end"] = CUTOFF
        changes.append(changed)
        for index, changed in enumerate(changes):
            with self.subTest(index=index), self.assertRaises(ValueError):
                validate_model(rehash(changed))
        changed = deepcopy(bundle)
        changed["scaler"]["mean"][0] = float("nan")
        with self.assertRaisesRegex(ValueError, "finite JSON"):
            validate_model(changed)

    def test_missing_sequence_and_bad_scope_abstain(self):
        rows = observations()
        bundle = self.fit(rows, sequence_window=2)
        for values in (None, [0.0], [float("nan")] * 10):
            record = deepcopy(rows[1.0][8])
            record["sequence_features"] = values
            self.assertEqual(predict_record(bundle, record)["reason"], "MISSING_SEQUENCE_FEATURES")
        for field, value, reason in (("symbol", "OTHER", "SCOPE_MISMATCH"),
                                     ("timeframe", "H1", "SCOPE_MISMATCH"),
                                     ("candidate_id", "", "MISSING_CANDIDATE_ID"),
                                     ("as_of", "2024-01-01", "INVALID_CONFIRMATION"),
                                     ("as_of", BASE.isoformat(), "BEFORE_FIT_CUTOFF"),
                                     ("family", "FVG_FIRST_RETEST", "UNSEEN_FAMILY_OR_DIRECTION"),
                                     ("direction", -1, "UNSEEN_FAMILY_OR_DIRECTION")):
            record = deepcopy(rows[1.0][8])
            record[field] = value
            with self.subTest(field=field):
                result = predict_record(bundle, record)
                self.assertEqual(result["status"], "ABSTAIN")
                self.assertEqual(result["reason"], reason)
        record = deepcopy(rows[1.0][8])
        record["features"]["detector_version"] = "changed"
        self.assertEqual(predict_record(bundle, record)["reason"], "FEATURE_VERSION_MISMATCH")

    def test_nonfinite_inference_is_json_safe_and_cannot_select(self):
        bundle = self.fit()
        # Finite payload values can still overflow on an extreme input.
        bundle["estimator"]["coef"] = [[1e308] * bundle["feature_schema"]["dimension"] for _ in bundle["targets_r"]]
        bundle = rehash(bundle)
        record = observations()[1.0][8]
        record["features"]["sweep_depth_atr"] = 1e308
        result = predict_record(bundle, record)
        self.assertEqual(result["status"], "ABSTAIN")
        self.assertIn(result["reason"], {"NONFINITE_FEATURES", "NONFINITE_PREDICTION"})
        json.dumps(result, allow_nan=False)
        record["direction"] = float("nan")
        result = predict_record(bundle, record)
        self.assertIsNone(result["direction"])
        json.dumps(result, allow_nan=False)

    def test_tie_and_threshold_policy_match_frozen_rr_contract(self):
        rows = observations()
        for records in rows.values():
            for row in records:
                row.update(label="TIMEOUT", net_r=0.5, conservative_net_r=0.5)
        bundle = self.fit(rows)
        selected = predict_record(bundle, rows[1.0][8])
        self.assertEqual(selected["selected_target_r"], 1)
        self.assertEqual(selected["reason"], "MAX_EXPECTED_NET_R")
        self.assertIsNone(selected["p_tp"])
        self.assertEqual(bundle["logistic"][0]["status"], "ONE_CLASS")
        abstained = predict_record(self.fit(rows, min_expected_r=0.5), rows[1.0][8])
        self.assertEqual(abstained["status"], "ABSTAIN")
        self.assertEqual(abstained["reason"], "EXPECTED_NET_R_NOT_ABOVE_THRESHOLD")


if __name__ == "__main__":
    unittest.main()
