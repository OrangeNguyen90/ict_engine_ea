"""Source integrity checks for the offline research export."""

from datetime import datetime, timedelta, timezone
from contextlib import redirect_stderr, redirect_stdout
import csv
import io
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from .research.data import load_dataset
from .research.run import build_report, main


class ResearchDataTests(unittest.TestCase):
    def setUp(self):
        self.directory = TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.csv = Path(self.directory.name) / "US500_M15.csv"
        self.csv.write_text(
            "timestamp,open,high,low,close,volume,spread_points\n"
            "2024-01-01T00:00:00,100,101,99,100,10,2\n"
            "2024-01-01T00:15:00,100,102,99,101,12,3\n",
            encoding="utf-8",
        )
        self.metadata = Path(str(self.csv) + ".meta.json")
        self.sidecar = {
            "schema_version": 1, "csv_file": self.csv.name,
            "csv_bytes": self.csv.stat().st_size, "count": 2,
            "symbol": "US500", "timeframe": "M15", "timeframe_seconds": 900,
            "price_type": "bid", "price_type_historically_verified": True,
            "point": 0.01, "tick_size": 0.01, "complete": True,
            "effective_end": "2024-01-01T00:30:00",
            "actual_first": "2024-01-01T00:00:00",
            "actual_last": "2024-01-01T00:15:00",
            "coverage_verified": False,
        }
        self.save_metadata()

    def save_metadata(self):
        self.metadata.write_text(json.dumps(self.sidecar), encoding="utf-8")

    def load(self, **options):
        return load_dataset(self.csv, utc_offset_minutes=0, **options)

    def test_verified_bid_export_loads_with_reproducible_cutoff(self):
        bars, manifest = self.load()
        self.assertEqual(len(bars), 2)
        self.assertEqual(manifest["quality"]["as_of_utc"],
                         datetime(2024, 1, 1, 0, 30, tzinfo=timezone.utc).isoformat())
        self.assertEqual(manifest["quality"]["zero_spread_bars"], 0)

    def test_unknown_price_cannot_be_overridden_to_verified_bid(self):
        self.sidecar.update(price_type="unknown", price_type_historically_verified=False)
        self.save_metadata()
        with self.assertRaisesRegex(ValueError, "price type"):
            self.load(price_type="bid")
        with self.assertRaisesRegex(ValueError, "verified Bid"):
            self.load()
        bars, manifest = self.load(require_verified_bid=False)
        self.assertEqual(len(bars), 2)
        self.assertEqual(manifest["price_type"], "unknown")

    def test_bid_label_without_historical_verification_is_audit_only(self):
        self.sidecar["price_type_historically_verified"] = False
        self.save_metadata()
        with self.assertRaisesRegex(ValueError, "verified Bid"):
            self.load()
        self.assertEqual(len(self.load(require_verified_bid=False)[0]), 2)

    def test_sidecar_must_match_source_file(self):
        for key, value in (("csv_file", "other.csv"), ("csv_bytes", 1),
                           ("count", 1), ("actual_last", "2024-01-02T00:00:00")):
            with self.subTest(key=key):
                original = self.sidecar[key]
                self.sidecar[key] = value
                self.save_metadata()
                with self.assertRaises(ValueError):
                    self.load()
                self.sidecar[key] = original

    def test_incomplete_source_needs_explicit_audit_override(self):
        self.sidecar["complete"] = False
        self.save_metadata()
        with self.assertRaisesRegex(ValueError, "incomplete"):
            self.load(require_verified_bid=False)
        _, manifest = self.load(require_verified_bid=False, allow_partial=True)
        self.assertFalse(manifest["quality"]["export_complete"])

    def test_audit_and_evaluation_keep_unverified_source_visible(self):
        audit = build_report(self.csv, utc_offset_minutes=0)
        self.assertEqual(audit["status"], "AUDIT_ONLY")
        self.assertEqual(audit["counts"]["bars"], 2)
        self.assertEqual(len(audit["source"]["csv_sha256"]), 64)
        self.assertFalse(audit["usable_for_shadow"])
        with self.assertRaisesRegex(ValueError, "explicit commission_r"):
            build_report(self.csv, utc_offset_minutes=0, mode="evaluate")
        evaluation = build_report(self.csv, utc_offset_minutes=0, mode="evaluate",
                                  commission_r=0.05, slippage_ticks=1)
        self.assertEqual(evaluation["status"], "EXPLORATORY_SOURCE_UNVERIFIED")
        self.assertEqual(evaluation["config"]["target_r"], 2.0)
        self.assertEqual(evaluation["counts"]["candidates"], 0)
        self.assertFalse(evaluation["usable_for_shadow"])

    def test_cli_creates_new_report_and_refuses_overwrite(self):
        output = Path(self.directory.name) / "audit.json"
        argv = ["--csv", str(self.csv), "--utc-offset-minutes", "0",
                "--output", str(output)]
        with redirect_stdout(io.StringIO()):
            self.assertEqual(main(argv), 0)
        self.assertEqual(json.loads(output.read_text(encoding="utf-8"))["status"],
                         "AUDIT_ONLY")
        with redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as raised:
                main(argv)
        self.assertEqual(raised.exception.code, 2)

    def test_ml_integration_preserves_source_gate_and_trial_identity(self):
        from importlib.util import find_spec
        if find_spec("sklearn") is None:
            self.skipTest("optional scikit-learn not installed")
        arguments = dict(utc_offset_minutes=0, mode="evaluate",
                         commission_r=0.05, slippage_ticks=1)
        baseline = build_report(self.csv, **arguments)
        result = build_report(self.csv, include_ml=True, **arguments)
        self.assertNotEqual(baseline["trial_id"], result["trial_id"])
        self.assertEqual(result["ml"]["status"], "INSUFFICIENT_EVIDENCE")
        self.assertEqual(result["source_gate"], "UNVERIFIED_SOURCE")
        self.assertFalse(result["usable_for_shadow"])
        self.assertIn("scikit-learn", result["ml_dependencies"])
        with self.assertRaisesRegex(ValueError, "evaluate mode"):
            build_report(self.csv, utc_offset_minutes=0, include_ml=True)

    def test_end_to_end_synthetic_bars_produce_out_of_sample_model_scores(self):
        from importlib.util import find_spec
        if find_spec("sklearn") is None:
            self.skipTest("optional scikit-learn not installed")
        start = datetime(2024, 1, 1, tzinfo=timezone.utc)
        rows = []
        for day in range(12):
            candles = [(100, 100.5, 99.5, 100)] * 15
            candles += [(100, 103.2, 99.8, 103), (103, 104, 102, 103.5),
                        (102.2, 103, 101.5, 102.8)]
            candles += [(102.8, 108 if day % 2 else 103,
                         102 if day % 2 else 100, 102.8)]
            for index, values in enumerate(candles):
                stamp = start + timedelta(days=day, minutes=15 * index)
                rows.append([stamp.isoformat(), *values, 10, 1])
        with self.csv.open("w", encoding="utf-8", newline="") as stream:
            writer = csv.writer(stream)
            writer.writerow(["timestamp", "open", "high", "low", "close", "volume", "spread_points"])
            writer.writerows(rows)
        self.sidecar.update(csv_bytes=self.csv.stat().st_size, count=len(rows),
                            actual_first=rows[0][0], actual_last=rows[-1][0],
                            effective_end=(datetime.fromisoformat(rows[-1][0]) + timedelta(minutes=15)).isoformat())
        self.save_metadata()
        report = build_report(self.csv, mode="evaluate", include_ml=True,
                              commission_r=0.05, slippage_ticks=1, horizon_bars=1,
                              min_train=4, test_size=4, min_mlp_train=4,
                              min_family_train=1, min_oos=2, bootstrap_samples=10)
        self.assertGreaterEqual(report["counts"]["candidates"], 10)
        self.assertGreater(report["ml"]["metrics"]["linear_net_r"]["n"], 0)
        self.assertGreater(report["ml"]["metrics"]["logistic_p_tp"]["n"], 0)
        self.assertGreater(report["ml"]["metrics"]["mlp_p_tp"]["n"], 0)
        self.assertEqual(report["status"], "EXPLORATORY_SOURCE_UNVERIFIED")
        arguments = dict(mode="evaluate", include_ml=True, commission_r=0.05,
                         slippage_ticks=1, horizon_bars=1, min_train=4, test_size=4,
                         min_mlp_train=4, min_family_train=1, min_oos=2,
                         bootstrap_samples=10, min_holdout=2,
                         holdout_cutoff=(start + timedelta(days=8)).isoformat())
        sealed = build_report(self.csv, **arguments)
        self.assertEqual(sealed["ml"]["holdout"]["status"], "SEALED")
        self.assertEqual(sealed["ml"]["holdout"]["predictions"], [])
        for outcome in sealed["outcomes"]:
            self.assertLess(datetime.fromisoformat(outcome["as_of"]), start + timedelta(days=8))
            if outcome["label_end"] is not None:
                self.assertLessEqual(datetime.fromisoformat(outcome["label_end"]), start + timedelta(days=8))
        final = build_report(self.csv, evaluate_holdout=True, **arguments)
        held = final["ml"]["holdout"]
        self.assertEqual(held["status"], "HOLDOUT_EVALUATED")
        self.assertGreaterEqual(held["metrics"]["logistic_p_tp"]["n"], 2)
        self.assertLess(datetime.fromisoformat(held["split"]["train_end"]), start + timedelta(days=8))
        self.assertTrue(all(datetime.fromisoformat(row["as_of"]) >= start + timedelta(days=8)
                            for row in held["predictions"]))
        common = held["calibration"]["common_rows"]
        self.assertEqual(common["logistic_p_tp"]["counts"]["included"],
                         common["mlp_p_tp"]["counts"]["included"])
        self.assertEqual(final["outcomes"], sealed["outcomes"])


if __name__ == "__main__":
    unittest.main()
