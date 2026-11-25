"""Source-backed wiring of the RR study; all price paths below are synthetic."""
import csv
from datetime import datetime, timedelta, timezone
from importlib.util import find_spec
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from .research.run import _rr_settings, build_report


class RRSettingsTests(unittest.TestCase):
    def test_action_grid_is_canonical_and_invalid_settings_fail_before_io(self):
        self.assertEqual(_rr_settings([3, 1, 2], "ridge", 0, None), [1.0, 2.0, 3.0])
        for grid in ([1], [1, 1], [0, 2], [True, 2], [1, float("nan")]):
            with self.subTest(grid=grid), self.assertRaises(ValueError):
                build_report("does-not-exist.csv", rr_targets=grid)
        for options in ({"rr_model": "mlp"}, {"rr_sequence_window": 8},
                        {"rr_targets": [1, 2], "rr_sequence_window": 1},
                        {"rr_targets": [1, 2], "rr_min_expected_r": float("inf")}):
            with self.subTest(options=options), self.assertRaises(ValueError):
                build_report("does-not-exist.csv", **options)
        with self.assertRaisesRegex(ValueError, "requires evaluate mode"):
            build_report("does-not-exist.csv", rr_targets=[1, 2])


@unittest.skipUnless(find_spec("sklearn"), "optional scikit-learn not installed")
class RRIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.directory = TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.csv = Path(self.directory.name) / "SYNTHETIC_M15.csv"
        self.start = datetime(2024, 1, 1, tzinfo=timezone.utc)
        self.rows = []
        for day in range(12):
            candles = [(100, 100.5, 99.5, 100)] * 15
            candles += [(100, 103.2, 99.8, 103), (103, 104, 102, 103.5),
                        (102.2, 103, 101.5, 102.8)]
            candles += [(102.8, 108 if day % 2 else 103,
                         102 if day % 2 else 100, 102.8)]
            for index, values in enumerate(candles):
                stamp = self.start + timedelta(days=day, minutes=15 * index)
                self.rows.append([stamp.isoformat(), *values, 10, 1])
        self.write_source()
        self.arguments = dict(
            mode="evaluate", include_ml=True, commission_r=0.05, slippage_ticks=1,
            horizon_bars=1, min_train=4, test_size=4, min_mlp_train=4,
            min_family_train=1, min_oos=2, bootstrap_samples=10,
            rr_targets=[1, 2, 3], rr_sequence_window=8)

    def write_source(self, verified_bid=True):
        with self.csv.open("w", encoding="utf-8", newline="") as stream:
            writer = csv.writer(stream)
            writer.writerow(["timestamp", "open", "high", "low", "close", "volume", "spread_points"])
            writer.writerows(self.rows)
        metadata = {
            "schema_version": 1, "csv_file": self.csv.name,
            "csv_bytes": self.csv.stat().st_size, "count": len(self.rows),
            "symbol": "SYNTHETIC", "timeframe": "M15", "timeframe_seconds": 900,
            "price_type": "bid", "price_type_historically_verified": verified_bid,
            "point": 0.01, "tick_size": 0.01, "complete": True,
            "actual_first": self.rows[0][0], "actual_last": self.rows[-1][0],
            "effective_end": (datetime.fromisoformat(self.rows[-1][0]) + timedelta(minutes=15)).isoformat(),
            "coverage_verified": False,
        }
        Path(str(self.csv) + ".meta.json").write_text(json.dumps(metadata), encoding="utf-8")

    def test_sequence_neural_policy_and_trial_identity_are_wired_end_to_end(self):
        report = build_report(self.csv, rr_model="mlp", **self.arguments)
        rr = report["rr_study"]
        self.assertEqual(rr["settings"]["feature_mode"], "sequence")
        self.assertEqual(rr["settings"]["model"], "mlp")
        self.assertGreater(len(rr["predictions"]), 0)
        self.assertTrue(any(any(action["expected_net_r"] is not None for action in row["actions"])
                            for row in rr["predictions"]))
        self.assertEqual(rr["source_gate"], "UNVERIFIED_SOURCE")
        self.assertFalse(rr["usable_for_shadow"])
        self.assertIn("rr.py", report["code_sha256"])
        self.assertIn("sequences.py", report["code_sha256"])
        json.dumps(report, allow_nan=False)
        ridge = build_report(self.csv, **self.arguments)
        self.assertNotEqual(ridge["trial_id"], report["trial_id"])
        reordered = build_report(self.csv, **dict(self.arguments, rr_targets=[3, 1, 2]))
        self.assertEqual(reordered["trial_id"], ridge["trial_id"])
        self.assertEqual(reordered["rr_study"], ridge["rr_study"])

    def test_sealed_holdout_is_not_computed_and_opening_keeps_development_fixed(self):
        cutoff = (self.start + timedelta(days=8)).isoformat()
        arguments = dict(self.arguments, holdout_cutoff=cutoff, min_holdout=2)
        sealed = build_report(self.csv, **arguments)
        rr = sealed["rr_study"]
        self.assertEqual(rr["holdout"]["status"], "SEALED")
        self.assertIsNone(rr["holdout"]["records"])
        self.assertEqual(rr["holdout"]["predictions"], [])
        opened = build_report(self.csv, evaluate_holdout=True, **arguments)
        for field in ("predictions", "splits", "metrics"):
            self.assertEqual(rr[field], opened["rr_study"][field])
        held = opened["rr_study"]["holdout"]
        self.assertGreater(len(held["predictions"]), 0)
        self.assertLess(datetime.fromisoformat(held["split"]["train_end"]),
                        datetime.fromisoformat(cutoff))
        self.assertTrue(all(datetime.fromisoformat(row["as_of"]) >= datetime.fromisoformat(cutoff)
                            for row in held["predictions"]))

    def test_unverified_historical_bid_still_blocks_rr_evaluation(self):
        self.write_source(verified_bid=False)
        with self.assertRaisesRegex(ValueError, "verified Bid"):
            build_report(self.csv, **self.arguments)


if __name__ == "__main__":
    unittest.main()
