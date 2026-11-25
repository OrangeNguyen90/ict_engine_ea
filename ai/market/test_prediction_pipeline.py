"""Synthetic train -> frozen inference -> MT5 wire, without a terminal/account."""
from contextlib import redirect_stdout
import csv
from datetime import datetime, timedelta, timezone
from importlib.util import find_spec
import io
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from .research.predict import fit_from_csv, history_digest, infer_from_csv, load_model, main, save_model


@unittest.skipUnless(find_spec("sklearn"), "optional scikit-learn not installed")
class PredictionPipelineTests(unittest.TestCase):
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
        self.cutoff = (self.start + timedelta(days=8)).isoformat()
        self.now = self.start + timedelta(days=11, minutes=15 * 18)
        self.write_source()

    def write_source(self, *, coverage=True, verified_bid=True, broker="TEST_BROKER"):
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
            "coverage_verified": coverage, "broker": broker, "server": "TEST_SERVER",
        }
        Path(str(self.csv) + ".meta.json").write_text(json.dumps(metadata), encoding="utf-8")

    def fit(self, **options):
        return fit_from_csv(self.csv, fit_cutoff=self.cutoff, targets=[1, 2, 3],
                            commission_r=0.05, slippage_ticks=1, horizon_bars=1,
                            min_train=4, min_mlp_train=4, **options)

    def test_neural_frozen_bundle_latest_candle_and_wire_round_trip(self):
        from .research.prediction_bridge import atomic_write_snapshot, parse_snapshot, serialize_snapshot
        bundle = self.fit(model="mlp", sequence_window=8)
        model_file = Path(self.directory.name) / "model.json"
        save_model(model_file, bundle)
        loaded = load_model(model_file, expected_model_id=bundle["model_id"])
        with patch("market.research.predict.evaluate_candidates", side_effect=AssertionError("inference cannot label outcomes")):
            snapshot = infer_from_csv(loaded, self.csv, now=self.now)
        self.assertIn(snapshot["status"], ("SELECTED", "ABSTAIN"))
        text = serialize_snapshot(snapshot)
        self.assertEqual(len(text.strip().split(";")), 22)
        self.assertIn(";RESEARCH_ADVISORY;0;VERIFIED;END", text)
        parsed = parse_snapshot(text, expected_model_id=bundle["model_id"], symbol="SYNTHETIC",
                                timeframe="M15", as_of=self.now, now=self.now)
        self.assertEqual(parsed["status"], snapshot["status"])
        output = Path(self.directory.name) / "ict_ml_prediction.csv"
        atomic_write_snapshot(output, snapshot)
        self.assertEqual(output.read_text(encoding="ascii"), text)
        with self.assertRaises(FileExistsError):
            save_model(model_file, bundle)
        with self.assertRaisesRegex(ValueError, "pinned model"):
            load_model(model_file, expected_model_id="0" * 64)

    def test_training_prefix_and_broker_cannot_silently_change(self):
        bundle = self.fit()
        self.rows[0][4] = 100.1
        self.write_source()
        with self.assertRaisesRegex(ValueError, "TRAINING_HISTORY_CHANGED"):
            infer_from_csv(bundle, self.csv, now=self.now)
        self.rows[0][4] = 100
        self.write_source(broker="OTHER_BROKER")
        with self.assertRaisesRegex(ValueError, "broker differs"):
            infer_from_csv(bundle, self.csv, now=self.now)

    def test_forming_or_future_bar_changes_do_not_change_prediction(self):
        bundle = self.fit(sequence_window=8)
        before = infer_from_csv(bundle, self.csv, now=self.now)
        self.rows[-1][1:5] = [1000, 2000, 1, 1500]
        self.write_source()
        after = infer_from_csv(bundle, self.csv, now=self.now)
        self.assertEqual(before, after)

    def test_unverified_coverage_and_bid_block_frozen_export(self):
        self.write_source(coverage=False)
        with self.assertRaisesRegex(ValueError, "coverage"):
            self.fit()
        self.write_source(verified_bid=False)
        with self.assertRaisesRegex(ValueError, "verified Bid"):
            self.fit()

    def test_missing_context_and_stale_source_are_rejected(self):
        bundle = self.fit()
        self.rows = self.rows[19:]
        self.write_source()
        with self.assertRaisesRegex(ValueError, "CONTEXT_START_MISMATCH"):
            infer_from_csv(bundle, self.csv, now=self.now)
        # Refit to this shorter, explicitly new context; current export still
        # cannot supply today's candle on a later UTC day.
        shorter = self.fit()
        with self.assertRaisesRegex(ValueError, "DATA_STALE"):
            infer_from_csv(shorter, self.csv, now=self.now + timedelta(days=1))

    def test_cli_fit_records_model_pin_and_refuses_overwrite(self):
        output = Path(self.directory.name) / "cli_model.json"
        argv = ["fit", "--csv", str(self.csv), "--output", str(output),
                "--fit-cutoff", self.cutoff, "--targets", "1", "2", "3",
                "--commission-r", "0.05", "--slippage-ticks", "1",
                "--horizon-bars", "1", "--min-train", "4"]
        stdout = io.StringIO()
        with redirect_stdout(stdout):
            self.assertEqual(main(argv), 0)
        printed = json.loads(stdout.getvalue())
        self.assertEqual(printed["model_id"], load_model(output)["model_id"])
        self.assertFalse(printed["execution_allowed"])


class ModelFileTests(unittest.TestCase):
    def test_duplicate_and_nonfinite_json_are_rejected_before_model_use(self):
        with TemporaryDirectory() as directory:
            path = Path(directory) / "model.json"
            for invalid in ('{"x":1,"x":2}', '{"x":NaN}', '{"x":Infinity}'):
                path.write_text(invalid, encoding="ascii")
                with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                    load_model(path)

    def test_history_fingerprint_only_covers_closed_fit_prefix(self):
        from .research.types import Bar
        start = datetime(2024, 1, 1, tzinfo=timezone.utc)
        bars = [Bar(start + timedelta(minutes=15 * i), 100, 101, 99, 100, 0.01) for i in range(3)]
        cutoff = (start + timedelta(minutes=30)).isoformat()
        self.assertEqual(history_digest(bars, fit_cutoff=cutoff, timeframe_seconds=900),
                         history_digest(bars[:2], fit_cutoff=cutoff, timeframe_seconds=900))


if __name__ == "__main__":
    unittest.main()
