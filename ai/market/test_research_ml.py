"""Tests for temporal isolation and exploratory research model scoring."""
from datetime import datetime, timedelta, timezone
from importlib.util import find_spec
import unittest

from .research.ml import walk_forward_ml


BASE = datetime(2024, 1, 1, tzinfo=timezone.utc)


def observation(index, *, label=None, end=None):
    timestamp = BASE + timedelta(days=index)
    label = label or ("TP_FIRST" if index % 2 else "SL_FIRST")
    return {"candidate_id": str(index), "symbol": "TEST", "timeframe": "M15",
            "family": "SWEEP_RECLAIM", "direction": 1, "as_of": timestamp.isoformat(),
            "label_end": (end or timestamp + timedelta(minutes=15)).isoformat(),
            "label": label, "net_r": 2.0 if label == "TP_FIRST" else -1.0,
            "features": {"body_ratio": float(index % 3) / 3, "sweep_depth_atr": float(index)}}


@unittest.skipUnless(find_spec("sklearn"), "optional scikit-learn not installed")
class ResearchMLTests(unittest.TestCase):
    def run_model(self, rows, **kwargs):
        return walk_forward_ml(rows, min_train=4, min_mlp_train=4, test_size=2, **kwargs)

    def test_purge_same_timestamp_exclusions_and_scoring(self):
        rows = [observation(i) for i in range(12)]
        rows[0]["label_end"] = (BASE + timedelta(days=4)).isoformat()
        rows[5] = observation(5, label="AMBIGUOUS")
        rows[5]["net_r"] = None
        rows[6]["as_of"] = rows[5]["as_of"]
        result = self.run_model(rows)
        self.assertEqual(result["splits"][0]["purged_overlap_n"], 1)
        self.assertEqual(result["splits"][0]["status"], "INSUFFICIENT_TRAINING")
        predictions = {row["candidate_id"]: row for row in result["predictions"]}
        self.assertEqual(predictions["5"]["split_id"], predictions["6"]["split_id"])
        self.assertFalse(predictions["5"]["scored"])
        for split in result["splits"]:
            if split["train_end"]:
                self.assertLess(datetime.fromisoformat(split["train_end"]), datetime.fromisoformat(split["test_start"]))
        for model in ("linear_net_r", "logistic_p_tp", "mlp_p_tp"):
            scored = [r for r in result["predictions"] if r["scored"] and r[model] is not None]
            self.assertEqual(result["metrics"][model]["n"], len(scored))

    def test_future_outcomes_and_unknown_features_cannot_change_current_predictions(self):
        rows = [observation(i) for i in range(12)]
        changed = [dict(row, features=dict(row["features"])) for row in rows]
        for row in changed[4:]:
            row.update(label="TP_FIRST", net_r=999, exit_price=10000)
            row["features"]["future_profit"] = 1e9
        before, after = self.run_model(rows), self.run_model(changed)
        first = {row["candidate_id"]: row for row in before["predictions"]}
        second = {row["candidate_id"]: row for row in after["predictions"]}
        for index in ("4", "5"):
            for key in ("linear_net_r", "logistic_p_tp", "mlp_p_tp", "baseline_net_r", "baseline_p_tp"):
                self.assertEqual(first[index][key], second[index][key])

    def test_single_class_and_no_training_are_explicit(self):
        rows = [observation(i, label="TP_FIRST") for i in range(8)]
        result = self.run_model(rows)
        self.assertEqual(result["splits"][0]["classifier_status"], "ONE_CLASS")
        self.assertIsNotNone(result["predictions"][0]["linear_net_r"])
        self.assertIsNone(result["predictions"][0]["logistic_p_tp"])
        self.assertEqual(result["metrics"]["logistic_p_tp"]["n"], 0)
        for row in rows:
            row.update(label="CENSORED", net_r=None)
        result = self.run_model(rows)
        self.assertEqual(result["status"], "INSUFFICIENT_EVIDENCE")
        self.assertEqual(result["metrics"]["linear_net_r"]["n"], 0)

    def test_mlp_requires_its_own_minimum_and_baseline_shares_rows(self):
        rows = [observation(i) for i in range(10)]
        result = walk_forward_ml(rows, min_train=4, min_mlp_train=200, test_size=2)
        self.assertTrue(all(split["mlp_status"] == "INSUFFICIENT_TRAINING" for split in result["splits"]))
        self.assertEqual(result["metrics"]["mlp_p_tp"]["n"], 0)
        scored = [row for row in result["predictions"] if row["scored"] and row["logistic_p_tp"] is not None]
        baseline = sum((row["baseline_p_tp"] - row["y"]) ** 2 for row in scored) / len(scored)
        self.assertAlmostEqual(result["metrics"]["logistic_p_tp"]["baseline_brier"], baseline)

    def test_scope_and_timestamp_validation(self):
        with self.assertRaisesRegex(ValueError, "one symbol"):
            self.run_model([observation(0), dict(observation(1), symbol="OTHER")])
        with self.assertRaisesRegex(ValueError, "label_end precedes"):
            self.run_model([observation(2, end=BASE)])

    def test_holdout_is_sealed_and_development_hides_late_outcomes(self):
        rows = [observation(i) for i in range(12)]
        cutoff = (BASE + timedelta(days=8)).isoformat()
        rows[6]["label_end"] = cutoff
        rows[7].update(label="CENSORED", label_end=None, net_r=None)
        result = self.run_model(rows, holdout_cutoff=cutoff)
        self.assertEqual(result["holdout"]["status"], "SEALED")
        self.assertEqual(result["holdout"]["records"], 4)
        self.assertEqual(result["holdout"]["predictions"], [])
        self.assertEqual(result["holdout"]["metrics"], {})
        self.assertIsNone(result["holdout"]["split"])
        predictions = {row["candidate_id"]: row for row in result["predictions"]}
        self.assertTrue(set(predictions).isdisjoint({"8", "9", "10", "11"}))
        self.assertIsNone(predictions["6"]["label"])
        self.assertIsNone(predictions["6"]["net_r"])
        self.assertFalse(predictions["6"]["scored"])
        self.assertIsNone(predictions["7"]["label"])
        self.assertEqual(result["exclusions"]["UNAVAILABLE_AT_CUTOFF"], 2)
        changed = [dict(row) for row in rows]
        for row in changed[8:]:
            row.update(label="TP_FIRST", net_r=9999)
        self.assertEqual(result, self.run_model(changed, holdout_cutoff=cutoff))

    def test_holdout_fit_is_frozen_and_purges_cutoff_boundary(self):
        rows = [observation(i) for i in range(12)]
        cutoff = (BASE + timedelta(days=8)).isoformat()
        rows[6]["label_end"] = cutoff
        result = self.run_model(rows, holdout_cutoff=cutoff, evaluate_holdout=True, min_holdout=4)
        holdout = result["holdout"]
        self.assertEqual(holdout["status"], "HOLDOUT_EVALUATED")
        self.assertEqual(holdout["split"]["train_n"], 7)
        self.assertEqual(holdout["split"]["purged_overlap_n"], 1)
        self.assertLess(datetime.fromisoformat(holdout["split"]["train_end"]), datetime.fromisoformat(cutoff))
        self.assertEqual(holdout["metrics"]["linear_net_r"]["n"], 4)
        changed = [dict(row) for row in rows]
        for row in changed[8:]:
            row.update(label="TP_FIRST", net_r=9999)
        after = self.run_model(changed, holdout_cutoff=cutoff, evaluate_holdout=True, min_holdout=4)
        self.assertEqual(result["predictions"], after["predictions"])
        for before, later in zip(holdout["predictions"], after["holdout"]["predictions"]):
            for key in ("linear_net_r", "logistic_p_tp", "mlp_p_tp", "baseline_net_r", "baseline_p_tp"):
                self.assertEqual(before[key], later[key])

    def test_holdout_insufficient_cases_and_validation(self):
        rows = [observation(i) for i in range(8)]
        cutoff = (BASE + timedelta(days=7)).isoformat()
        result = self.run_model(rows, holdout_cutoff=cutoff, evaluate_holdout=True, min_holdout=2)
        self.assertEqual(result["holdout"]["status"], "INSUFFICIENT_SCORED_HOLDOUT")
        early = self.run_model(rows, holdout_cutoff=BASE.isoformat(), evaluate_holdout=True)
        self.assertEqual(early["holdout"]["status"], "INSUFFICIENT_TRAINING")
        late = self.run_model(rows, holdout_cutoff=(BASE + timedelta(days=20)).isoformat(), evaluate_holdout=True)
        self.assertEqual(late["holdout"]["status"], "NO_HOLDOUT_RECORDS")
        with self.assertRaisesRegex(ValueError, "requires holdout_cutoff"):
            self.run_model(rows, evaluate_holdout=True)
        with self.assertRaisesRegex(ValueError, "timezone-aware"):
            self.run_model(rows, holdout_cutoff="2024-01-01T00:00:00")


if __name__ == "__main__":
    unittest.main()
