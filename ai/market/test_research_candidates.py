"""Offline, standard-library checks of the research detector definitions."""

from dataclasses import replace
from datetime import datetime, timedelta, timezone
import unittest

from .research.candidates import detect_candidates
from .research.types import Bar, ResearchConfig


BASE = datetime(2024, 1, 1, tzinfo=timezone.utc)
STEP = timedelta(minutes=15)


def series(values):
    return [Bar(BASE + index * STEP, opening, high, low, close, 0.1)
            for index, (opening, high, low, close) in enumerate(values)]


def reflected(bars):
    return [replace(bar, open=200 - bar.open, high=200 - bar.low,
                    low=200 - bar.high, close=200 - bar.close) for bar in bars]


def config(**changes):
    baseline = ResearchConfig(
        symbol="TEST", timeframe="M15", timeframe_seconds=900,
        tick_size=0.1, point=0.1, atr_period=2, pivot_left=1, pivot_right=1,
    )
    return replace(baseline, **changes)


SWEEP = [
    (10, 11, 9, 10), (10, 10.5, 8, 9),
    (9, 10, 8.8, 9.5), (9.5, 10, 7.5, 9.2),
    (9.2, 10, 7, 9), (9, 10, 6.8, 9.2),
]
BREAK = [
    (10, 11, 9, 10), (11, 12, 10, 11.5),
    (11, 11.8, 10.2, 11), (11, 14, 10.8, 13.5),
    (13, 14, 12.5, 13.8), (12.2, 13.5, 11.95, 13),
    (12.2, 13.5, 11.9, 13),
]
FVG = [
    (10, 10.5, 9.5, 10), (10, 10.5, 9.5, 10),
    (10, 10.5, 9.5, 10), (10, 13.2, 9.8, 13),
    (13, 14, 12, 13.5), (12.2, 13, 11.5, 12.8),
    (12.2, 13, 11.3, 12.8),
]


class CandidateDetectorTests(unittest.TestCase):
    def family(self, bars, family, settings=None):
        return [event for event in detect_candidates(bars, settings or config())
                if event.family == family]

    def test_prefix_replay_is_exact_for_all_families_and_directions(self):
        for family, fixture in (("SWEEP_RECLAIM", SWEEP),
                                ("BREAK_RETEST", BREAK),
                                ("FVG_FIRST_RETEST", FVG)):
            for bars in (series(fixture), reflected(series(fixture))):
                full = detect_candidates(bars, config())
                self.assertTrue(any(event.family == family for event in full))
                for prefix_length in range(1, len(bars) + 1):
                    with self.subTest(family=family, prefix_length=prefix_length,
                                      opening=bars[0].open):
                        partial = detect_candidates(bars[:prefix_length], config())
                        expected = [event for event in full if event.bar_index < prefix_length]
                        self.assertEqual(partial, expected)

    def test_price_reflection_preserves_symmetric_rules_and_stops(self):
        for family, fixture in (("SWEEP_RECLAIM", SWEEP),
                                ("BREAK_RETEST", BREAK),
                                ("FVG_FIRST_RETEST", FVG)):
            bars = series(fixture)
            bullish = self.family(bars, family)
            bearish = self.family(reflected(bars), family)
            self.assertEqual(len(bullish), 1)
            self.assertEqual(len(bearish), 1)
            self.assertEqual(bullish[0].direction, 1)
            self.assertEqual(bearish[0].direction, -1)
            self.assertEqual(bullish[0].bar_index, bearish[0].bar_index)
            self.assertAlmostEqual(bearish[0].stop, 200 - bullish[0].stop)

    def test_sweep_uses_confirmed_pivot_once(self):
        events = self.family(series(SWEEP), "SWEEP_RECLAIM")
        self.assertEqual([event.bar_index for event in events], [3])
        self.assertEqual(events[0].features["level"], 8)
        self.assertAlmostEqual(events[0].stop, 7.4)
        self.assertEqual(events[0].confirmed_at, BASE + 4 * STEP)

    def test_pivot_confirmation_cannot_use_event_bar(self):
        # Bar 3 invalidates the would-be pivot at bar 1 before its two right
        # bars have closed; its own low cannot both confirm and sweep that pivot.
        self.assertEqual(self.family(series(SWEEP[:4]), "SWEEP_RECLAIM",
                                     config(pivot_right=2)), [])

    def test_break_requires_a_later_retest_and_consumes_contact_once(self):
        bars = series(BREAK)
        self.assertEqual(self.family(bars[:4], "BREAK_RETEST"), [])
        self.assertEqual(self.family(bars[:5], "BREAK_RETEST"), [])
        events = self.family(bars, "BREAK_RETEST")
        self.assertEqual([event.bar_index for event in events], [5])
        self.assertEqual(events[0].features["level"], 12)
        self.assertEqual(events[0].features["age_bars"], 2)
        self.assertAlmostEqual(events[0].stop, 11.85)

    def test_break_failed_first_contact_is_not_recycled(self):
        bars = series(BREAK)
        bars[5] = replace(bars[5], open=13.2, close=12.2)
        self.assertEqual(self.family(bars, "BREAK_RETEST"), [])

    def test_break_close_through_level_invalidates_retest(self):
        bars = series(BREAK)
        bars[4] = replace(bars[4], open=13, low=11, close=11.5)
        self.assertEqual(self.family(bars, "BREAK_RETEST"), [])

    def test_fvg_formation_candle_cannot_retest_its_own_gap(self):
        bars = series(FVG)
        self.assertEqual(self.family(bars[:5], "FVG_FIRST_RETEST"), [])
        events = self.family(bars, "FVG_FIRST_RETEST")
        self.assertEqual([event.bar_index for event in events], [5])
        self.assertEqual(events[0].features["zone_lower"], 10.5)
        self.assertEqual(events[0].features["zone_upper"], 12)
        self.assertEqual(events[0].features["impulse_body_atr"], 3)
        self.assertAlmostEqual(events[0].stop, 10.4)

    def test_fvg_rejected_first_touch_is_not_recycled(self):
        bars = series(FVG)
        bars[5] = replace(bars[5], open=12.8, close=12)
        self.assertEqual(self.family(bars, "FVG_FIRST_RETEST"), [])

    def test_fvg_full_traversal_is_not_a_reaction(self):
        for low in (10.5, 10, 9):
            bars = series(FVG)
            bars[5] = replace(bars[5], low=low)
            self.assertEqual(self.family(bars, "FVG_FIRST_RETEST"), [])

    def test_fvg_requires_pre_displacement_atr_and_impulse_body(self):
        bars = series(FVG)
        self.assertEqual(self.family(bars, "FVG_FIRST_RETEST",
                                     config(atr_period=4)), [])
        bars[3] = replace(bars[3], open=12.8)
        self.assertEqual(self.family(bars, "FVG_FIRST_RETEST"), [])

    def test_setup_expiry_applies_before_late_break_or_gap_retest(self):
        self.assertEqual(self.family(series(BREAK), "BREAK_RETEST",
                                     config(max_setup_bars=1)), [])
        bars = series(FVG[:5] + [(13, 14, 12.5, 13.8), FVG[5]])
        self.assertEqual(self.family(bars, "FVG_FIRST_RETEST",
                                     config(max_setup_bars=1)), [])

    def test_time_gap_resets_pools_gaps_breaks_and_atr(self):
        for family, fixture, gap_index in (
            ("SWEEP_RECLAIM", SWEEP, 3),
            ("BREAK_RETEST", BREAK, 5),
            ("FVG_FIRST_RETEST", FVG, 5),
        ):
            bars = series(fixture)
            bars = [replace(bar, time=bar.time + STEP) if index >= gap_index else bar
                    for index, bar in enumerate(bars)]
            with self.subTest(family=family):
                self.assertEqual(self.family(bars, family), [])

    def test_appending_discontinuous_data_does_not_rewrite_earlier_events(self):
        first = series(SWEEP)
        later = [replace(bar, time=bar.time + timedelta(days=7))
                 for bar in series(FVG)]
        prior = detect_candidates(first, config())
        replay = detect_candidates(first + later, config())
        self.assertEqual(prior, [event for event in replay if event.bar_index < len(first)])

    def test_no_setup_without_atr_warmup_and_no_future_features(self):
        self.assertEqual(detect_candidates(series(SWEEP), config(atr_period=20)), [])
        for event in detect_candidates(series(FVG), config()):
            self.assertTrue(all("mss" not in name.lower() and "outcome" not in name.lower()
                                for name in event.features))


if __name__ == "__main__":
    unittest.main()
