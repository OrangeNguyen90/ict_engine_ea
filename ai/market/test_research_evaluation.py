"""Offline execution and temporal isolation tests; no Django or database."""
from dataclasses import replace
from datetime import datetime, timedelta, timezone
import unittest

from .research.outcomes import evaluate_candidates
from .research.types import Bar, Candidate, ResearchConfig
from .research.validation import walk_forward


BASE = datetime(2024, 1, 1, tzinfo=timezone.utc)
STEP = timedelta(minutes=15)


def bar(index, opening=100.0, high=100.5, low=99.5, close=100.0, spread=0.0):
    return Bar(BASE + index * STEP, opening, high, low, close, spread)


def config(**overrides):
    return replace(ResearchConfig("TEST", "M15", 900, 0.1, 0.1,
                                  slippage_ticks=0, commission_r=0, horizon_bars=2), **overrides)


def candidate(direction=1, stop=99.0, **overrides):
    return replace(Candidate("test-1", "TEST", "M15", "SWEEP_RECLAIM", direction,
                             BASE + STEP, 0, stop, "source-1", {"at_confirmation": 1}), **overrides)


def observation(index, label="TP_FIRST", net_r=2.0, *, as_of=None, label_end=None,
                family="SWEEP_RECLAIM"):
    timestamp = as_of or BASE + timedelta(days=index)
    end = label_end or timestamp + STEP
    return {"candidate_id": f"row-{index}", "symbol": "TEST", "timeframe": "M15",
            "family": family, "as_of": timestamp.isoformat(), "label_end": end.isoformat(),
            "label": label, "net_r": net_r,
            "conservative_net_r": -1.0 if label == "AMBIGUOUS" else net_r}


class ResearchOutcomeTests(unittest.TestCase):
    def test_long_and_short_bid_ask_fills_and_costs_once(self):
        settings = config(slippage_ticks=1, commission_r=0.05, horizon_bars=1)
        long = evaluate_candidates(
            [bar(0), bar(1, high=103, low=99.8, close=102, spread=0.2)],
            [candidate(stop=99.3)], settings)[0]
        self.assertEqual(long["label"], "TP_FIRST")
        self.assertAlmostEqual(long["entry"], 100.3)
        self.assertAlmostEqual(long["risk_price"], 1.0)
        self.assertAlmostEqual(long["target"], 102.3)
        self.assertAlmostEqual(long["exit_price"], 102.2)
        self.assertAlmostEqual(long["net_r"], 1.85)
        self.assertAlmostEqual(long["planned_net_target_r"], 1.85)
        self.assertAlmostEqual(long["planned_net_stop_r"], -1.15)
        self.assertAlmostEqual(long["planned_net_reward_risk"], 1.85 / 1.15)
        short = evaluate_candidates(
            [bar(0), bar(1, high=100.5, low=97.4, close=98, spread=0.2)],
            [candidate(-1, 100.9)], settings)[0]
        self.assertEqual(short["label"], "TP_FIRST")
        self.assertAlmostEqual(short["entry"], 99.9)
        self.assertAlmostEqual(short["target"], 97.9)
        self.assertAlmostEqual(short["exit_price"], 98.0)
        self.assertAlmostEqual(short["net_r"], 1.85)

    def test_spread_already_in_prices_is_not_deducted_twice(self):
        settings = config(horizon_bars=1, commission_r=0.05)
        rows = [bar(0), bar(1, spread=0.2)]
        long = evaluate_candidates(rows, [candidate(stop=99.2)], settings)[0]
        short = evaluate_candidates(rows, [candidate(-1, 101)], settings)[0]
        self.assertEqual((long["label"], short["label"]), ("TIMEOUT", "TIMEOUT"))
        self.assertAlmostEqual(long["net_r"], -0.25)
        self.assertAlmostEqual(short["net_r"], -0.25)

    def test_both_barriers_is_ambiguous_with_separate_adverse_bound(self):
        result = evaluate_candidates([bar(0), bar(1, high=104, low=98)],
                                     [candidate(stop=99.1)],
                                     config(slippage_ticks=1, commission_r=0.05))[0]
        self.assertEqual(result["label"], "AMBIGUOUS")
        self.assertIsNone(result["net_r"])
        self.assertIsNone(result["exit_price"])
        self.assertAlmostEqual(result["conservative_net_r"], -1.15)
        self.assertAlmostEqual(result["optimistic_net_r"], 1.85)

    def test_bar_at_confirmation_does_not_enter_before_its_close(self):
        result = evaluate_candidates([bar(0, high=200, low=10), bar(1), bar(2)],
                                     [candidate()], config())[0]
        self.assertEqual(result["label"], "TIMEOUT")
        self.assertEqual(result["entry_at"], (BASE + STEP).isoformat())
        self.assertAlmostEqual(result["entry"], 100)

    def test_missing_entry_and_mid_horizon_bars_censor_unresolved(self):
        no_entry = evaluate_candidates([bar(0), bar(2)], [candidate()], config())[0]
        missing = evaluate_candidates([bar(0), bar(1), bar(3)], [candidate()], config())[0]
        incomplete = evaluate_candidates([bar(0), bar(1)], [candidate()], config())[0]
        self.assertEqual(no_entry["reason"], "missing_entry_bar")
        self.assertIsNone(no_entry["entry"])
        self.assertEqual(missing["reason"], "missing_bar_during_horizon")
        self.assertEqual(incomplete["reason"], "incomplete_horizon")
        for result in (no_entry, missing, incomplete):
            self.assertEqual(result["label"], "CENSORED")
            self.assertIsNone(result["net_r"])

    def test_later_missing_bars_do_not_erase_observed_resolution(self):
        rows = [bar(0), bar(1, high=103, close=102), bar(5)]
        result = evaluate_candidates(rows, [candidate()], config(horizon_bars=16))[0]
        self.assertEqual(result["label"], "TP_FIRST")

    def test_open_price_jumps_stop_at_worse_price_and_cap_favorable_target(self):
        stopped = evaluate_candidates(
            [bar(0), bar(1), bar(2, opening=98, high=98.5, low=97.5, close=98)],
            [candidate()], config(commission_r=0.01))[0]
        self.assertEqual(stopped["label"], "SL_FIRST")
        self.assertAlmostEqual(stopped["net_r"], -2.01)
        jumped = evaluate_candidates(
            [bar(0), bar(1), bar(2, opening=104, high=104.5, low=103.5, close=104)],
            [candidate()], config(commission_r=0.01))[0]
        self.assertEqual(jumped["label"], "TP_FIRST")
        self.assertAlmostEqual(jumped["exit_price"], 102.0)
        self.assertAlmostEqual(jumped["net_r"], 1.99)

    def test_short_stop_uses_ask_and_can_trigger_when_spread_widens(self):
        result = evaluate_candidates(
            [bar(0), bar(1), bar(2, spread=1.5)],
            [candidate(-1, 101)], config())[0]
        self.assertEqual(result["label"], "SL_FIRST")
        self.assertAlmostEqual(result["exit_price"], 101.5)
        self.assertAlmostEqual(result["net_r"], -1.5)

    def test_invalid_plans_and_no_future_data_remain_in_output(self):
        candidates = [candidate(stop=101), candidate(id="bad-time", confirmed_at=BASE),
                      candidate(id="bad-index", bar_index=9), candidate(id="valid")]
        results = evaluate_candidates([bar(0), bar(1)], candidates, config())
        self.assertEqual(len(results), len(candidates))
        self.assertEqual([row["label"] for row in results],
                         ["INVALID_PLAN", "INVALID_PLAN", "INVALID_PLAN", "CENSORED"])
        self.assertEqual([row["features"] for row in results], [item.features for item in candidates])
        results[0]["features"]["at_confirmation"] = 99
        self.assertEqual(candidates[0].features["at_confirmation"], 1)


class ResearchWalkForwardTests(unittest.TestCase):
    def evaluate(self, rows, **options):
        defaults = {"min_train": 2, "test_size": 2, "min_family_train": 1,
                    "min_oos": 2, "bootstrap_samples": 40}
        defaults.update(options)
        return walk_forward(rows, **defaults)

    def test_no_labels_means_insufficient_not_zero_probability(self):
        rows = [observation(i, "CENSORED", None) for i in range(8)]
        result = self.evaluate(rows)
        self.assertEqual(result["status"], "INSUFFICIENT_EVIDENCE")
        self.assertEqual(result["counts"]["scored_oos"], 0)
        self.assertIsNone(result["oos_metrics"]["brier"])
        self.assertTrue(all(row["p_tp"] is None for row in result["predictions"]))
        self.assertEqual(result["exclusions"], {"CENSORED": 8})
        self.assertIsNone(result["profiles"][0]["p_tp"])

    def test_all_same_time_rows_stay_together_even_across_warmup_boundary(self):
        rows = [observation(0), observation(1, as_of=BASE), observation(2, as_of=BASE)]
        rows.extend(observation(i) for i in range(3, 10))
        result = self.evaluate(rows)
        self.assertEqual(result["counts"]["warmup_records"], 3)
        predicted = {row["candidate_id"]: row for row in result["predictions"]}
        self.assertNotIn("row-1", predicted)
        duplicate = observation(20, as_of=BASE + timedelta(days=4))
        with_duplicate = self.evaluate(rows + [duplicate], test_size=1)
        predictions = {row["candidate_id"]: row for row in with_duplicate["predictions"]}
        self.assertEqual(predictions["row-4"]["split_id"], predictions["row-20"]["split_id"])
        self.assertEqual(predictions["row-4"]["p_tp"], predictions["row-20"]["p_tp"])

    def test_overlapping_or_equal_end_labels_are_purged(self):
        rows = [observation(0, label_end=BASE + timedelta(days=2)),
                observation(1), observation(2), observation(3)]
        result = self.evaluate(rows, test_size=1)
        first, second = result["predictions"]
        self.assertEqual(first["train_n"], 1)
        self.assertIsNone(first["p_tp"])
        self.assertEqual(result["splits"][0]["purged_overlap_n"], 1)
        self.assertEqual(second["train_n"], 3)
        self.assertLess(datetime.fromisoformat(second["train_end"]), datetime.fromisoformat(second["as_of"]))

    def test_predictions_do_not_change_when_own_or_future_results_change(self):
        rows = [observation(i, "TP_FIRST" if i % 2 else "SL_FIRST", 2 if i % 2 else -1)
                for i in range(12)]
        changed = [dict(row) for row in rows]
        for row in changed[4:]:
            row.update(label="TP_FIRST", net_r=20.0)
        before, after = self.evaluate(rows), self.evaluate(changed)
        initial = {row["candidate_id"]: row for row in before["predictions"]}
        modified = {row["candidate_id"]: row for row in after["predictions"]}
        for index in (2, 3, 4, 5):
            self.assertEqual(initial[f"row-{index}"]["p_tp"], modified[f"row-{index}"]["p_tp"])
            self.assertEqual(initial[f"row-{index}"]["baseline_p_tp"], modified[f"row-{index}"]["baseline_p_tp"])

    def test_ambiguity_never_enters_tp_denominator_and_stress_bound_is_visible(self):
        rows = [observation(i) for i in range(14)]
        rows[5] = observation(5, "AMBIGUOUS", None)
        rows[7] = observation(7, "CENSORED", None)
        result = self.evaluate(rows)
        profile = result["profiles"][0]
        self.assertEqual(profile["n"], 10)
        self.assertEqual(profile["wins"], 10)
        self.assertEqual(profile["p_tp"], 1.0)
        self.assertEqual(profile["excluded_forecast_labels"], {"AMBIGUOUS": 1, "CENSORED": 1})
        stress = profile["adverse_ambiguity_sensitivity"]
        self.assertEqual(stress["n"], 11)
        self.assertEqual(stress["ambiguous_n"], 1)
        self.assertLess(stress["mean_net_r"], profile["mean_net_r"])
        self.assertEqual(result["counts"]["scored_oos"], 10)

    def test_positive_expectancy_requires_multiple_day_clusters(self):
        rows = [observation(i, as_of=BASE + i * STEP) for i in range(20)]
        profile = self.evaluate(rows)["profiles"][0]
        self.assertEqual(profile["day_clusters"], 1)
        self.assertEqual(profile["support_status"], "INSUFFICIENT_EVIDENCE")
        self.assertIsNone(profile["mean_net_r_ci95"])
        self.assertIn("fewer_than_five_utc_day_clusters", profile["reasons"])

    def test_reported_brier_and_baseline_share_exact_oos_rows(self):
        rows = [observation(i, "TP_FIRST" if i % 3 else "TIMEOUT", 2 if i % 3 else 0.2)
                for i in range(14)]
        result = self.evaluate(rows)
        predictions = [row for row in result["predictions"] if row["scored"]]
        expected = sum((row["p_tp"] - row["y"]) ** 2 for row in predictions) / len(predictions)
        baseline = sum((row["baseline_p_tp"] - row["y"]) ** 2 for row in predictions) / len(predictions)
        self.assertAlmostEqual(result["oos_metrics"]["brier"], expected)
        self.assertAlmostEqual(result["oos_metrics"]["baseline_brier"], baseline)
        self.assertTrue(any(row["y"] == 0 and row["net_r"] > 0 for row in predictions))

    def test_bootstrap_is_reproducible_and_input_order_independent(self):
        rows = [observation(i, "TP_FIRST" if i % 3 else "SL_FIRST", 2 if i % 3 else -1)
                for i in range(20)]
        forward = self.evaluate(rows)
        reverse = self.evaluate(list(reversed(rows)))
        self.assertEqual(forward, reverse)

    def test_empty_and_insufficient_family_history_emit_no_fake_model(self):
        empty = self.evaluate([])
        self.assertEqual(empty["profiles"], [])
        self.assertEqual(empty["status"], "INSUFFICIENT_EVIDENCE")
        rows = [observation(i, family="rare" if i >= 4 else "common") for i in range(6)]
        result = self.evaluate(rows, min_family_train=3)
        rare = [row for row in result["predictions"] if row["family"] == "rare"]
        self.assertTrue(all(row["p_tp"] is None for row in rare))
        self.assertTrue(all(row["status"] == "INSUFFICIENT_FAMILY_TRAINING" for row in rare))

    def test_never_pool_different_symbols_or_timeframes(self):
        rows = [observation(0), dict(observation(1), symbol="OTHER")]
        with self.assertRaisesRegex(ValueError, "one symbol"):
            self.evaluate(rows)


if __name__ == "__main__":
    unittest.main()
