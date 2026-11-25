"""Tests for matched-row OOS probability evaluation."""
import math
import unittest

from .research.calibration import calibration_report


def row(p, y, baseline=0.5, scored=True):
    return {"model": p, "y": y, "baseline_p_tp": baseline, "scored": scored}


class CalibrationTests(unittest.TestCase):
    def test_matched_metrics_and_fixed_bins(self):
        rows = [row(0, 0, 0.25), row(0.25, 1, 0.5), row(1, 1, 0.75),
                row(0.8, 1, None), row(None, 1, 0.9)]
        result = calibration_report(rows, "model", bins=4, min_samples=3)
        self.assertEqual(result["status"], "DESCRIPTIVE")
        self.assertEqual(result["counts"], {"input": 5, "unscored": 0, "invalid_label": 0,
                                            "invalid_probability": 1, "invalid_baseline": 1,
                                            "included": 3})
        metrics = result["metrics"]
        self.assertEqual(metrics["n"], 3)
        self.assertAlmostEqual(metrics["brier"], 0.75 ** 2 / 3)
        self.assertAlmostEqual(metrics["baseline_brier"], (0.25 ** 2 + 0.5 ** 2 + 0.25 ** 2) / 3)
        self.assertAlmostEqual(metrics["log_loss"], -math.log(0.25) / 3, places=10)
        self.assertAlmostEqual(metrics["baseline_log_loss"], (-2 * math.log(0.75) - math.log(0.5)) / 3)
        self.assertAlmostEqual(metrics["ece"], 0.25)
        bins = result["reliability_bins"]
        self.assertEqual([item["n"] for item in bins], [1, 1, 0, 1])
        self.assertIsNone(bins[2]["observed_frequency"])
        self.assertTrue(bins[-1]["upper_inclusive"])

    def test_missing_invalid_values_and_empty_sample(self):
        rows = [row(0.5, None), row(float("nan"), 1), row(float("inf"), 0),
                row(-0.1, 1), row(1.1, 1), row(True, 1), row(0.5, float("nan")),
                row(0.5, True), row(0.5, 0, float("nan")), row(0.5, 0, 0.5, False)]
        result = calibration_report(rows, "model")
        self.assertEqual(result["status"], "NO_SCORED_ROWS")
        self.assertEqual(result["counts"]["invalid_label"], 3)
        self.assertEqual(result["counts"]["invalid_probability"], 5)
        self.assertEqual(result["counts"]["invalid_baseline"], 1)
        self.assertEqual(result["counts"]["unscored"], 1)
        self.assertIsNone(result["metrics"]["ece"])
        self.assertIsNone(result["metrics"]["baseline_log_loss"])

    def test_small_sample_endpoint_loss_is_finite_and_bins_are_stable(self):
        result = calibration_report([row(0, 1), row(1, 0), row(0.29, 1)], "model", bins=100)
        self.assertEqual(result["status"], "SMALL_SAMPLE")
        self.assertTrue(math.isfinite(result["metrics"]["log_loss"]))
        self.assertEqual(result["reliability_bins"][29]["n"], 1)
        self.assertEqual(result["reliability_bins"][0]["n"], 1)
        self.assertEqual(result["reliability_bins"][99]["n"], 1)

    def test_rejects_invalid_configuration(self):
        for kwargs in ({"bins": 0}, {"bins": 101}, {"bins": True}, {"min_samples": 0}):
            with self.subTest(kwargs=kwargs), self.assertRaises(ValueError):
                calibration_report([], "model", **kwargs)
        with self.assertRaises(ValueError):
            calibration_report([], "")


if __name__ == "__main__":
    unittest.main()
