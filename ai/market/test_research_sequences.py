"""Closed-window, gap and normalization contracts for sequence research."""

from copy import deepcopy
from dataclasses import replace
from datetime import datetime, timedelta, timezone
import unittest

from .research.sequences import attach_sequences
from .research.types import Bar


BASE = datetime(2024, 1, 1, tzinfo=timezone.utc)
STEP = timedelta(minutes=15)


def candles():
    values = [(100, 102, 99, 101, 0.2), (101, 104, 100, 103, 0.4),
              (103, 105, 102, 104, 0.6), (104, 106, 103, 105, 0.8)]
    return [Bar(BASE + index * STEP, *values) for index, values in enumerate(values)]


def observation(index=2, **changes):
    return {"candidate_id": f"sequence-{index}", "as_of": (BASE + (index + 1) * STEP).isoformat(),
            "family": "SWEEP_RECLAIM", "direction": 1, "features": {"atr": 2.0},
            "label": "TP_FIRST", "net_r": 2.0, **changes}


class ResearchSequenceTests(unittest.TestCase):
    def attach(self, records, bars=None, window=2):
        return attach_sequences(records, candles() if bars is None else bars,
                                window=window, timeframe_seconds=900)

    def test_normalizes_closed_candles_with_confirmation_atr(self):
        result = self.attach([observation()])[0]
        self.assertEqual(result["sequence_status"], "READY")
        expected = [-1.5, 0.0, -2.0, -0.5, 0.2, -0.5, 0.5, -1.0, 0.0, 0.3]
        self.assertEqual(len(result["sequence_features"]), 10)
        for actual, wanted in zip(result["sequence_features"], expected):
            self.assertAlmostEqual(actual, wanted)

    def test_future_entry_candle_changes_do_not_change_past_window(self):
        bars = candles()
        expected = self.attach([observation()], bars[:3])[0]["sequence_features"]
        bars[3] = replace(bars[3], open=10000, high=20000, low=1, close=15000,
                          spread=1000, volume=999999)
        self.assertEqual(self.attach([observation()], bars)[0]["sequence_features"], expected)

    def test_price_reflection_and_opposite_direction_preserve_geometry(self):
        bars = candles()
        reflected = [replace(bar, open=300 - bar.open, high=300 - bar.low,
                             low=300 - bar.high, close=300 - bar.close) for bar in bars]
        long = self.attach([observation()], bars)[0]["sequence_features"]
        short = self.attach([observation(direction=-1)], reflected)[0]["sequence_features"]
        self.assertEqual(long, short)

    def test_scaling_prices_spread_and_atr_preserves_geometry(self):
        bars = [replace(bar, open=bar.open * 3, high=bar.high * 3, low=bar.low * 3,
                        close=bar.close * 3, spread=bar.spread * 3) for bar in candles()]
        original = self.attach([observation()])[0]["sequence_features"]
        scaled = self.attach([observation(features={"atr": 6.0})], bars)[0]["sequence_features"]
        for before, after in zip(original, scaled):
            self.assertAlmostEqual(before, after)

    def test_insufficient_prefix_is_missing_instead_of_zero_padded(self):
        result = self.attach([observation(index=0)], window=2)[0]
        self.assertIsNone(result["sequence_features"])
        self.assertEqual(result["sequence_status"], "INSUFFICIENT_HISTORY")

    def test_missing_confirmation_does_not_use_a_nearby_or_future_candle(self):
        record = observation(as_of=(BASE + 2 * STEP + timedelta(seconds=1)).isoformat(),
                             bar_index=1)
        result = self.attach([record])[0]
        self.assertIsNone(result["sequence_features"])
        self.assertEqual(result["sequence_status"], "MISSING_CONFIRMATION_BAR")

    def test_gap_invalidates_crossing_window_but_not_new_contiguous_segment(self):
        bars = candles()
        bars[2] = replace(bars[2], time=BASE + 4 * STEP)
        bars[3] = replace(bars[3], time=BASE + 5 * STEP)
        results = self.attach([observation(index=4), observation(index=5)], bars)
        self.assertIsNone(results[0]["sequence_features"])
        self.assertEqual(results[0]["sequence_status"], "GAP_IN_WINDOW")
        self.assertEqual(results[1]["sequence_status"], "READY")
        self.assertEqual(len(results[1]["sequence_features"]), 10)

    def test_invalid_or_missing_atr_never_uses_future_data_to_estimate_scale(self):
        for atr in (None, 0.0, -1.0, float("nan"), float("inf"), True, "2"):
            with self.subTest(atr=atr):
                result = self.attach([observation(features={"atr": atr})])[0]
                self.assertIsNone(result["sequence_features"])
                self.assertEqual(result["sequence_status"], "INVALID_ATR")
        result = self.attach([observation(features=None)])[0]
        self.assertEqual(result["sequence_status"], "INVALID_ATR")

    def test_output_is_independent_copy_and_does_not_use_outcomes(self):
        source = observation(entry=1000000, net_r=-999, label="CENSORED",
                             features={"atr": 2.0, "future_price": 999999})
        untouched = deepcopy(source)
        result = self.attach([source])[0]
        self.assertEqual(source, untouched)
        self.assertEqual(result["sequence_features"], self.attach([observation()])[0]["sequence_features"])
        result["features"]["atr"] = 99
        self.assertEqual(source["features"]["atr"], 2.0)

    def test_invalid_direction_and_invalid_bar_are_explicitly_missing(self):
        for direction in (0, None, True, "1"):
            result = self.attach([observation(direction=direction)])[0]
            self.assertEqual(result["sequence_status"], "INVALID_DIRECTION")
            self.assertIsNone(result["sequence_features"])
        bars = candles()
        bars[1] = replace(bars[1], spread=float("nan"))
        result = self.attach([observation()], bars)[0]
        self.assertEqual(result["sequence_status"], "INVALID_BAR_VALUES")
        self.assertIsNone(result["sequence_features"])

    def test_rejects_bad_settings_and_nonchronological_bar_timestamps(self):
        for name in ("window", "timeframe_seconds"):
            for value in (0, -1, True, 1.5):
                with self.subTest(name=name, value=value), self.assertRaises(ValueError):
                    attach_sequences([], [], **{"window": 2, "timeframe_seconds": 900, name: value})
        bars = candles()
        with self.assertRaises(ValueError):
            self.attach([observation()], [bars[1], bars[0]])
        with self.assertRaises(ValueError):
            self.attach([observation()], [replace(bars[0], time=BASE.replace(tzinfo=None))])
