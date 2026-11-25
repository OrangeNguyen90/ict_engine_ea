"""Tests for paired reward/risk actions, temporal isolation and abstention."""
from copy import deepcopy
from datetime import datetime, timedelta, timezone
from importlib.util import find_spec
import json
import unittest
from unittest.mock import patch

from .research.rr import walk_forward_rr


BASE = datetime(2024, 1, 1, tzinfo=timezone.utc)


def observations(count=12, utilities=None):
    utilities = utilities or {1.0: 0.25, 3.0: 0.75}
    return {target: [
        {"candidate_id": str(index), "symbol": "TEST", "timeframe": "M15",
         "family": "SWEEP_RECLAIM", "direction": 1,
         "as_of": (BASE + timedelta(days=index)).isoformat(),
         "label_end": (BASE + timedelta(days=index, minutes=15)).isoformat(),
         "label": "TIMEOUT", "net_r": utility, "conservative_net_r": utility,
         "target_r": target, "features": {"body_ratio": 0.5, "atr": 1.0},
         "sequence_features": [0.0, 0.2, -0.1, 0.1, 0.01] * 2}
        for index in range(count)] for target, utility in utilities.items()}


def decision(row):
    """Only data that must be fixed before the observation's outcome."""
    return (row["selected_target_r"], row["expected_net_r"], row["p_tp"], row["reason"],
            row["train_n"], row["train_end"],
            [(action["expected_net_r"], action["p_tp"], action["baseline_net_r"])
             for action in row["actions"]])


@unittest.skipUnless(find_spec("sklearn"), "optional scikit-learn not installed")
class ResearchRRTests(unittest.TestCase):
    def evaluate(self, rows, **options):
        settings = {"min_train": 4, "test_size": 2, "min_mlp_train": 4,
                    "bootstrap_samples": 20}
        settings.update(options)
        return walk_forward_rr(rows, **settings)

    def test_positive_timeouts_beat_larger_target_with_gap_losses(self):
        rows = observations(utilities={1.0: 0.4, 3.0: -2.3})
        for row in rows[3.0]:
            row["label"] = "SL_FIRST"
        result = self.evaluate(rows)
        self.assertTrue(all(row["selected_target_r"] == 1 for row in result["predictions"]))
        self.assertAlmostEqual(result["metrics"]["mean_net_r"], 0.4)
        self.assertTrue(all(row["y"] == 0 for row in result["predictions"]))
        self.assertTrue(all(row["p_tp"] is None for row in result["predictions"]))
        self.assertAlmostEqual(result["metrics"]["fixed_target_baselines"][1]["mean_net_r"], -2.3)
        self.assertFalse(result["usable_for_shadow"])
        json.dumps(result, allow_nan=False)

    def test_current_and_future_outcomes_cannot_change_current_decisions(self):
        rows = observations()
        changed = deepcopy(rows)
        for target, records in changed.items():
            for row in records[4:]:
                row.update(label="TP_FIRST" if target == 1 else "SL_FIRST",
                           net_r=1000.0 if target == 1 else -1000.0, exit_price=1e9)
                row["features"]["future_profit"] = 1e9
        before = self.evaluate(rows)
        after = self.evaluate(changed)
        for first, second in zip(before["predictions"][:2], after["predictions"][:2]):
            self.assertEqual(decision(first), decision(second))

    def test_purge_requires_every_action_to_resolve_before_batch_start(self):
        rows = observations()
        rows[3.0][0]["label_end"] = (BASE + timedelta(days=4)).isoformat()
        for records in rows.values():
            records[5]["as_of"] = records[4]["as_of"]
        result = self.evaluate(rows, test_size=1)
        first = result["splits"][0]
        self.assertEqual(first["train_n"], 3)
        self.assertEqual(first["purged_overlap_n"], 1)
        self.assertEqual(first["status"], "INSUFFICIENT_TRAINING")
        indexed = {row["candidate_id"]: row for row in result["predictions"]}
        self.assertEqual(indexed["4"]["split_id"], indexed["5"]["split_id"])
        self.assertEqual(indexed["4"]["reason"], "INSUFFICIENT_TRAINING")
        for split in result["splits"]:
            if split["train_end"] is not None:
                self.assertLess(datetime.fromisoformat(split["train_end"]),
                                datetime.fromisoformat(split["test_start"]))

    def test_unknown_other_action_excludes_training_and_matched_scoring(self):
        rows = observations(utilities={1.0: 0.8, 3.0: 0.2})
        rows[3.0][0].update(label="CENSORED", label_end=None, net_r=None)
        rows[3.0][7].update(label="CENSORED", label_end=None, net_r=None)
        result = self.evaluate(rows)
        self.assertEqual(result["splits"][0]["train_n"], 3)
        indexed = {row["candidate_id"]: row for row in result["predictions"]}
        row = indexed["7"]
        self.assertEqual(row["selected_target_r"], 1)
        self.assertTrue(row["selected_outcome_known"])
        self.assertFalse(row["common_scored"])
        self.assertFalse(row["scored"])
        self.assertIsNone(row["net_r"])
        self.assertEqual(result["metrics"]["selected_excluded_due_to_other_actions"], 1)
        self.assertEqual(result["exclusions_by_target"][1]["excluded"], {"CENSORED": 2})
        for baseline in result["metrics"]["fixed_target_baselines"]:
            self.assertEqual(baseline["n"], result["metrics"]["n"])

    def test_fitted_split_without_observable_test_actions_is_insufficient(self):
        rows = observations()
        for records in rows.values():
            for row in records[4:]:
                row.update(label="CENSORED", label_end=None, net_r=None)
        result = self.evaluate(rows)
        self.assertEqual(result["splits"][0]["status"], "FITTED")
        self.assertEqual(result["status"], "INSUFFICIENT_EVIDENCE")
        self.assertTrue(all(item["n"] == 0 for item in result["metrics"]["forecast_metrics"]))

    def test_invalid_labels_and_nonfinite_utilities_remain_excluded(self):
        rows = observations()
        rows[3.0][6].update(label={"invalid": True})
        rows[3.0][7].update(net_r=float("nan"))
        rows[3.0][8].update(label="AMBIGUOUS", conservative_net_r=True)
        result = self.evaluate(rows)
        excluded = result["metrics"]["outcomes_by_target"][1]["excluded"]
        self.assertEqual(excluded["INVALID_LABEL"], 1)
        self.assertEqual(excluded["NONFINITE_NET_R"], 1)
        self.assertEqual(excluded["NONFINITE_CONSERVATIVE_NET_R"], 1)
        self.assertTrue(all(not row["common_scored"] for row in result["predictions"]
                            if row["candidate_id"] in {"6", "7", "8"}))
        json.dumps(result, allow_nan=False)

    def test_ambiguity_uses_adverse_utility_in_training_and_evaluation(self):
        rows = observations(utilities={1.0: 0.2, 3.0: 3.0})
        for row in rows[3.0]:
            row.update(label="TP_FIRST")
        rows[3.0][3].update(label="AMBIGUOUS", net_r=None, conservative_net_r=-1.0)
        rows[3.0][4].update(label="AMBIGUOUS", net_r=None, conservative_net_r=-4.0)
        result = self.evaluate(rows)
        first = result["predictions"][0]
        self.assertEqual(first["selected_target_r"], 3)
        self.assertAlmostEqual(first["expected_net_r"], 2.0)
        self.assertTrue(first["scored"])
        self.assertEqual(first["net_r"], -4.0)
        self.assertEqual(first["label"], "AMBIGUOUS")
        self.assertIsNone(first["y"])
        self.assertIsNone(first["p_tp"])
        self.assertGreater(result["metrics"]["ambiguous_selected_adverse_n"], 0)
        self.assertEqual(result["splits"][0]["classifier_by_target"][1]["train_n"], 3)

    def test_ties_choose_smaller_target_and_order_is_deterministic(self):
        rows = observations(utilities={3.0: 0.5, 1.0: 0.5})
        result = self.evaluate(rows)
        reversed_rows = {target: list(reversed(records)) for target, records in reversed(list(rows.items()))}
        self.assertEqual(result, self.evaluate(reversed_rows))
        self.assertTrue(all(row["selected_target_r"] == 1 for row in result["predictions"]))

    def test_fixed_threshold_requires_strictly_greater_expectancy(self):
        result = self.evaluate(observations(utilities={1.0: 0.5, 3.0: 0.5}), min_expected_r=0.5)
        self.assertTrue(all(row["status"] == "ABSTAIN" for row in result["predictions"]))
        self.assertTrue(all(row["reason"] == "EXPECTED_NET_R_NOT_ABOVE_THRESHOLD" for row in result["predictions"]))
        self.assertEqual(result["metrics"]["n"], 0)
        self.assertIsNone(result["metrics"]["mean_net_r"])

    def test_mlp_has_independent_training_minimum_and_fixed_model_smoke(self):
        missing = self.evaluate(observations(8), model="mlp", min_mlp_train=200)
        self.assertTrue(all(split["status"] == "INSUFFICIENT_TRAINING" for split in missing["splits"]))
        self.assertTrue(all(row["selected_target_r"] is None for row in missing["predictions"]))
        fitted = self.evaluate(observations(6), model="mlp")
        self.assertEqual(fitted["splits"][0]["status"], "FITTED")
        self.assertTrue(all(action["expected_net_r"] is not None for action in fitted["predictions"][0]["actions"]))
        self.assertIsInstance(fitted["splits"][0]["convergence_warnings"], list)

    def test_sealed_holdout_labels_and_features_are_unread(self):
        rows = observations()
        cutoff = (BASE + timedelta(days=8)).isoformat()
        before = self.evaluate(rows, holdout_cutoff=cutoff, feature_mode="sequence")
        changed = deepcopy(rows)
        for target, records in changed.items():
            for row in records[8:]:
                row.update(label={"unknown": target}, label_end="invalid", net_r=float("nan"),
                           features={"changed": target}, family=None, direction=None, target_r="unknown",
                           sequence_features=[float("nan")] * int(target))
        after = self.evaluate(changed, holdout_cutoff=cutoff, feature_mode="sequence")
        self.assertEqual(before, after)
        self.assertEqual(before["holdout"]["status"], "SEALED")
        self.assertEqual(before["holdout"]["predictions"], [])
        self.assertEqual(before["holdout"]["metrics"], {})
        self.assertIsNone(before["holdout"]["split"])

    def test_cutoff_boundary_hides_late_action_and_holdout_fit_is_frozen(self):
        rows = observations()
        cutoff = (BASE + timedelta(days=8)).isoformat()
        rows[3.0][6]["label_end"] = cutoff
        result = self.evaluate(rows, holdout_cutoff=cutoff, evaluate_holdout=True, min_holdout=4)
        self.assertEqual(result["holdout"]["status"], "HOLDOUT_EVALUATED")
        self.assertEqual(result["holdout"]["split"]["train_n"], 7)
        self.assertLess(datetime.fromisoformat(result["holdout"]["split"]["train_end"]),
                        datetime.fromisoformat(cutoff))
        indexed = {row["candidate_id"]: row for row in result["predictions"]}
        late = indexed["6"]["actions"][1]
        self.assertIsNone(late["label"])
        self.assertIsNone(late["label_end"])
        self.assertIsNone(late["evaluation_net_r"])
        self.assertEqual(late["outcome_exclusion"], "UNAVAILABLE_AT_CUTOFF")
        changed = deepcopy(rows)
        changed[3.0][6].update(label="TP_FIRST", net_r=999.0)
        for target, records in changed.items():
            for row in records[8:]:
                row.update(label="TP_FIRST", net_r=9999.0 if target == 1 else -9999.0)
        after = self.evaluate(changed, holdout_cutoff=cutoff, evaluate_holdout=True, min_holdout=4)
        self.assertEqual(result["predictions"], after["predictions"])
        for first, second in zip(result["holdout"]["predictions"], after["holdout"]["predictions"]):
            self.assertEqual(decision(first), decision(second))

    def test_holdout_minimum_counts_scored_policy_rows(self):
        rows = observations(9)
        cutoff = (BASE + timedelta(days=8)).isoformat()
        result = self.evaluate(rows, holdout_cutoff=cutoff, evaluate_holdout=True, min_holdout=2)
        self.assertEqual(result["holdout"]["status"], "INSUFFICIENT_SCORED_HOLDOUT")
        early = self.evaluate(rows, holdout_cutoff=BASE.isoformat(), evaluate_holdout=True)
        self.assertEqual(early["holdout"]["status"], "INSUFFICIENT_TRAINING")
        late = self.evaluate(rows, holdout_cutoff=(BASE + timedelta(days=20)).isoformat(), evaluate_holdout=True)
        self.assertEqual(late["holdout"]["status"], "NO_HOLDOUT_RECORDS")

    def test_sequence_missing_windows_abstain_and_do_not_train(self):
        rows = observations()
        for records in rows.values():
            records[0]["sequence_features"] = None
            records[4]["sequence_features"] = None
        result = self.evaluate(rows, feature_mode="sequence")
        self.assertEqual(result["settings"]["sequence_dimension"], 10)
        self.assertEqual(result["splits"][0]["train_n"], 3)
        self.assertEqual(result["predictions"][0]["reason"], "MISSING_SEQUENCE_FEATURES")
        self.assertEqual(result["counts"]["missing_features"], 2)
        changed = deepcopy(rows)
        for records in changed.values():
            for row in records:
                row["features"]["signal_close"] = 1e9
                row["features"]["zone_lower"] = -1e9
        after = self.evaluate(changed, feature_mode="sequence")
        for first, second in zip(result["predictions"], after["predictions"]):
            self.assertEqual(decision(first), decision(second))

    def test_sequence_dimensions_are_validated_without_opening_holdout(self):
        rows = observations()
        for records in rows.values():
            records[2]["sequence_features"] = [0.0] * 5
        with self.assertRaisesRegex(ValueError, "consistent dimension"):
            self.evaluate(rows, feature_mode="sequence")
        rows = observations()
        for records in rows.values():
            records[8]["sequence_features"] = [0.0] * 5
        cutoff = (BASE + timedelta(days=8)).isoformat()
        self.evaluate(rows, feature_mode="sequence", holdout_cutoff=cutoff)
        with self.assertRaisesRegex(ValueError, "holdout sequence dimension"):
            self.evaluate(rows, feature_mode="sequence", holdout_cutoff=cutoff, evaluate_holdout=True)

    def test_nonfinite_inference_abstains_and_remains_json_serializable(self):
        class NonfiniteRegressor:
            def __init__(self, **kwargs):
                pass

            def fit(self, x, y):
                return self

            def predict(self, x):
                return [[float("nan"), 0.5] for _ in x]

        with patch("sklearn.linear_model.Ridge", NonfiniteRegressor):
            result = self.evaluate(observations())
        self.assertTrue(all(row["reason"] == "NONFINITE_PREDICTION" for row in result["predictions"]))
        self.assertTrue(all(row["expected_net_r"] is None for row in result["predictions"]))
        json.dumps(result, allow_nan=False)

    def test_probability_scores_share_binary_rows_and_timeouts_are_zero(self):
        rows = observations(16)
        for target, records in rows.items():
            for index, row in enumerate(records):
                row.update(label="TP_FIRST" if index % 2 else "TIMEOUT",
                           net_r=target if index % 2 else 0.2)
                row["features"]["body_ratio"] = float(index % 2)
        result = self.evaluate(rows)
        for target_index, report in enumerate(result["metrics"]["calibration"]["by_target"]):
            included = [row["actions"][target_index] for row in result["predictions"]
                        if row["common_scored"] and row["actions"][target_index]["p_tp"] is not None]
            self.assertEqual(report["metrics"]["n"], len(included))
            expected = sum((row["p_tp"] - row["y"]) ** 2 for row in included) / len(included)
            baseline = sum((row["baseline_p_tp"] - row["y"]) ** 2 for row in included) / len(included)
            self.assertAlmostEqual(report["metrics"]["brier"], expected)
            self.assertAlmostEqual(report["metrics"]["baseline_brier"], baseline)
            self.assertTrue(any(row["y"] == 0 and row["evaluation_net_r"] > 0 for row in included))
        selected = result["metrics"]["calibration"]["selected_policy"]
        self.assertEqual(selected["metrics"]["n"], result["metrics"]["n"])

    def test_pairing_and_action_metadata_are_validated(self):
        cases = []
        missing = observations()
        missing[3.0].pop()
        cases.append((missing, "same candidate ids"))
        duplicate = observations()
        duplicate[3.0].append(deepcopy(duplicate[3.0][0]))
        cases.append((duplicate, "unique"))
        for field, value, message in (("as_of", BASE.isoformat(), "confirmation"),
                                      ("family", "BREAK_RETEST", "family"),
                                      ("direction", -1, "direction"),
                                      ("features", {"atr": 100.0}, "features"),
                                      ("target_r", 2.0, "action key"),
                                      ("label_end", BASE.isoformat(), "precedes")):
            changed = observations()
            changed[3.0][1][field] = value
            cases.append((changed, message))
        for rows, message in cases:
            with self.subTest(message=message), self.assertRaisesRegex(ValueError, message):
                self.evaluate(rows)

    def test_configuration_and_empty_input(self):
        for options in ({"model": "best"}, {"feature_mode": "unknown"}, {"seed": -1},
                        {"bootstrap_samples": 1}, {"min_expected_r": float("nan")},
                        {"evaluate_holdout": True}, {"holdout_cutoff": "2024-01-01T00:00:00"}):
            with self.subTest(options=options), self.assertRaises(ValueError):
                self.evaluate(observations(), **options)
        with self.assertRaisesRegex(ValueError, "at least two"):
            self.evaluate({1.0: []})
        empty = self.evaluate({1.0: [], 3.0: []})
        self.assertEqual(empty["status"], "INSUFFICIENT_EVIDENCE")
        self.assertEqual(empty["metrics"]["n"], 0)
        self.assertEqual(empty["family_summaries"], [])


if __name__ == "__main__":
    unittest.main()
