from datetime import datetime, timedelta, timezone
from decimal import Decimal

from django.test import SimpleTestCase, TestCase

from .engine import (FVGDetectionEngine, LiquidityDetectionEngine, MarketStructureEngine,
                     PremiumDiscountEngine, SwingDetectionEngine, validate_sequence)
from .models import ICTAnalysisRun, ICTSignal, ImportBatch, MarketCandle
from .services import CandleValidationService, ICTAnalysisOrchestrator, signal_as_of


BASE = datetime(2024, 1, 1, tzinfo=timezone.utc)
COMMON = {"symbol": "TEST", "timeframe": "H1", "source": "test-fixture"}


def candle(index, high, low, close=None, opening=None):
    high, low = Decimal(str(high)), Decimal(str(low))
    close = Decimal(str(close)) if close is not None else (high + low) / 2
    opening = Decimal(str(opening)) if opening is not None else close
    return {"id": index + 1, "timestamp": BASE + timedelta(hours=index),
            "open": opening, "high": high, "low": low, "close": close}


class EngineTests(SimpleTestCase):
    def test_break_does_not_reuse_obsolete_structural_level(self):
        rows = [candle(0, 10, 5), candle(1, 12, 6), candle(2, 15, 7, 14), candle(3, 16, 8, 15)]
        swings = [{"swing_type": "high", "price": Decimal(price),
                   "pivot_time": rows[i]["timestamp"], "confirmed_at": rows[2]["timestamp"],
                   "evidence_ids": [i+1]} for i, price in enumerate([10, 12])]
        self.assertEqual(len(MarketStructureEngine().detect(rows, swings, **COMMON)), 1)

    def test_fvg_mitigation_never_regresses(self):
        rows = [candle(0, 10, 6), candle(1, 15, 9), candle(2, 18, 12),
                candle(3, 17, 11), candle(4, 17, 12)]
        gap = FVGDetectionEngine(mitigation="half").detect(rows, **COMMON)[0]
        self.assertEqual(gap["status"], "partial")
        self.assertTrue(gap["mitigated"])
        self.assertEqual(len(gap["history"]), 1)

    def test_validation_rejects_gaps_bad_ohlc_volume_and_naive_time(self):
        for rows in ([candle(0, 10, 5), candle(2, 10, 5)],
                     [dict(candle(0, 10, 5), close=Decimal(11))],
                     [dict(candle(0, 10, 5), volume=Decimal(-1))],
                     [dict(candle(0, 10, 5), timestamp=BASE.replace(tzinfo=None))]):
            with self.assertRaises(ValueError):
                CandleValidationService().validate(rows, "H1")

    def test_pivot_requires_right_bars_and_replay_is_stable(self):
        rows = [candle(i, h, l) for i, (h, l) in enumerate([(10, 5), (12, 6), (16, 8), (11, 6), (10, 4), (14, 7), (12, 6)])]
        engine = SwingDetectionEngine(1, 1)
        self.assertEqual(engine.detect(rows[:3], **COMMON), [])
        partial = engine.detect(rows[:4], **COMMON)
        self.assertEqual(len(partial), 1)
        self.assertEqual(partial[0]["swing_type"], "high")
        self.assertEqual(partial[0]["confirmed_at"], rows[3]["timestamp"] + timedelta(hours=1))
        full = engine.detect(rows, **COMMON)
        self.assertEqual(full[0], partial[0])
        self.assertEqual(full[-1]["structure_label"], "LH")

    def test_equal_pivots_are_not_swings(self):
        rows = [candle(i, h, 1) for i, h in enumerate([5, 8, 8, 5])]
        self.assertEqual(SwingDetectionEngine(1, 1).detect(rows, **COMMON), [])

    def test_structure_close_break_and_mss(self):
        rows = [candle(0, 10, 6), candle(1, 12, 7), candle(2, 11, 5),
                candle(3, 14, 8, 13), candle(4, 9, 3, 4)]
        swings = [
            {"swing_type": "high", "price": Decimal(12), "pivot_time": rows[1]["timestamp"],
             "confirmed_at": rows[2]["timestamp"], "evidence_ids": [2]},
            {"swing_type": "low", "price": Decimal(5), "pivot_time": rows[2]["timestamp"],
             "confirmed_at": rows[4]["timestamp"], "evidence_ids": [3]},
        ]
        events = MarketStructureEngine().detect(rows, swings, **COMMON)
        self.assertEqual([(e["signal_type"], e["direction"]) for e in events], [("BOS", "bullish"), ("MSS", "bearish")])
        self.assertEqual(MarketStructureEngine(min_break="2").detect(rows[:4], swings, **COMMON), [])

    def test_fvg_formation_mitigation_and_asymmetric_direction(self):
        bullish = [candle(0, 10, 6), candle(1, 15, 9), candle(2, 18, 12), candle(3, 17, 11), candle(4, 14, 8, 9)]
        gaps = FVGDetectionEngine().detect(bullish, **COMMON)
        first = next(g for g in gaps if g["formed_at"] == bullish[2]["timestamp"])
        self.assertEqual((first["lower_price"], first["upper_price"]), (Decimal(10), Decimal(12)))
        self.assertEqual(first["history"][-1]["status"], "invalidated")
        self.assertEqual(FVGDetectionEngine().detect(bullish[:2], **COMMON), [])
        bearish = [candle(0, 20, 17), candle(1, 18, 13), candle(2, 15, 11)]
        self.assertTrue(any(g["direction"] == "bearish" for g in FVGDetectionEngine().detect(bearish, **COMMON)))

    def test_liquidity_equal_levels_sweep_vs_break(self):
        rows = [candle(0, 9, 4), candle(1, 10, 5), candle(2, 9, 4),
                candle(3, 11, 5, 9), candle(4, 12, 6, 12)]
        swings = [
            {"swing_type": "high", "price": Decimal(10), "pivot_time": rows[1]["timestamp"],
             "confirmed_at": rows[2]["timestamp"], "evidence_ids": [2]},
            {"swing_type": "high", "price": Decimal("10.1"), "pivot_time": rows[2]["timestamp"],
             "confirmed_at": rows[4]["timestamp"], "evidence_ids": [3]},
        ]
        zones, events = LiquidityDetectionEngine("0.2").detect(rows, swings, **COMMON)
        self.assertEqual(zones[1]["signal_type"], "EQH")
        self.assertEqual(zones[0]["status"], "swept")
        self.assertEqual(len(events), 1)
        self.assertEqual(zones[1]["status"], "broken")

    def test_dealing_range_requires_confirmed_opposite_anchors(self):
        one = {"swing_type": "low", "price": Decimal(5), "pivot_time": BASE,
               "confirmed_at": BASE + timedelta(hours=1), "evidence_ids": [1]}
        two = {"swing_type": "high", "price": Decimal(15), "pivot_time": BASE + timedelta(hours=2),
               "confirmed_at": BASE + timedelta(hours=3), "evidence_ids": [3]}
        engine = PremiumDiscountEngine()
        self.assertEqual(engine.detect([one], **COMMON)["status"], "insufficient_structure")
        self.assertEqual(engine.detect([one, two], **COMMON)["equilibrium"], Decimal(10))

    def test_invalid_sequence_rejected(self):
        rows = [candle(0, 10, 5), candle(0, 10, 5)]
        with self.assertRaises(ValueError):
            validate_sequence(rows)

    def test_prefix_replay_matches_full_history_at_each_close(self):
        rows = [candle(i, h, l) for i, (h, l) in enumerate(
            [(10, 5), (12, 6), (16, 8), (11, 6), (10, 4), (14, 7), (12, 6)])]
        engine = SwingDetectionEngine(1, 1)
        full = engine.detect(rows, **COMMON)
        for count in range(1, len(rows) + 1):
            as_of = rows[count - 1]["timestamp"] + timedelta(hours=1)
            prefix = engine.detect(rows[:count], **COMMON)
            self.assertEqual(prefix, [s for s in full if s["confirmed_at"] <= as_of])


class PersistenceAndApiTests(TestCase):
    def analyze(self, **kwargs):
        return ICTAnalysisOrchestrator().analyze(
            symbol="TEST", timeframe="H1", data_source="test-fixture",
            left_bars=1, right_bars=1, **kwargs)

    def setUp(self):
        batch = ImportBatch.objects.create(source_file="fixture.csv", file_sha256="0" * 64, data_source="test-fixture")
        for index, (high, low) in enumerate([(10, 5), (12, 6), (16, 8), (11, 6), (10, 4), (14, 7), (12, 6)]):
            row = candle(index, high, low)
            MarketCandle.objects.create(symbol="TEST", exchange="FIXTURE", contract="", timestamp=row["timestamp"],
                                        timeframe="H1", open=row["open"], high=row["high"], low=row["low"],
                                        close=row["close"], data_source="test-fixture", provenance=batch)

    def test_run_idempotent_and_as_of_excludes_future_confirmations(self):
        orchestrator = ICTAnalysisOrchestrator()
        orchestrator.analyze(symbol="TEST", timeframe="H1", data_source="test-fixture", left_bars=1, right_bars=1)
        count = ICTSignal.objects.count()
        orchestrator.analyze(symbol="TEST", timeframe="H1", data_source="test-fixture", left_bars=1, right_bars=1)
        self.assertEqual(ICTSignal.objects.count(), count)
        response = self.client.get("/api/ict/swings/", {"symbol": "TEST", "timeframe": "H1",
                                                        "as_of": (BASE + timedelta(hours=2)).isoformat()})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["results"], [])
        later = self.client.get("/api/ict/swings/", {"symbol": "TEST", "timeframe": "H1",
                                                     "as_of": (BASE + timedelta(hours=4)).isoformat()})
        self.assertEqual(len(later.json()["results"]), 1)
        candle_response = self.client.get("/api/ict/candles/", {"symbol": "TEST", "timeframe": "H1",
                                                                "as_of": (BASE + timedelta(hours=2, minutes=30)).isoformat()})
        self.assertEqual(candle_response.json()["count"], 2)

    def test_candles_api_and_dashboard(self):
        response = self.client.get("/api/ict/candles/", {"symbol": "TEST", "timeframe": "H1", "limit": "2"})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["count"], 2)
        self.assertEqual(self.client.get("/market/").status_code, 200)
        self.assertEqual(self.client.get("/api/ict/candles/", {"symbol": "TEST", "timeframe": "BAD"}).status_code, 400)

    def test_open_candles_excluded_and_all_categories_replay(self):
        self.analyze()
        full = list(ICTSignal.objects.all())
        for count in range(1, 8):
            cutoff = BASE + timedelta(hours=count)
            ICTSignal.objects.all().delete()
            ICTAnalysisRun.objects.all().delete()
            self.analyze(as_of=cutoff)
            expected = sorted([signal_as_of(s, cutoff) for s in full if s.confirmed_at <= cutoff], key=str)
            actual = sorted([signal_as_of(s, cutoff) for s in ICTSignal.objects.filter(confirmed_at__lte=cutoff)], key=str)
            self.assertEqual(actual, expected)
            run = self.analyze(as_of=cutoff)
            self.assertEqual(run.candle_count, count)
        self.assertEqual(ICTSignal.objects.count(), len(full))

    def test_analysis_parameters_and_source_corrections_are_versioned(self):
        self.analyze()
        old = list(ICTSignal.objects.values_list("signal_key", flat=True))
        self.analyze(liquidity_tolerance="0.2")
        self.assertGreater(ICTSignal.objects.count(), len(old))
        before = ICTSignal.objects.count()
        row = MarketCandle.objects.first()
        row.open += Decimal("0.1")
        row.save()
        self.analyze()
        self.assertGreater(ICTSignal.objects.count(), before)
        self.assertEqual(ICTSignal.objects.filter(signal_key__in=old).count(), len(old))
        response = self.client.get("/api/ict/analysis/", {"symbol": "TEST", "timeframe": "H1", "limit": 2000})
        latest = ICTAnalysisRun.objects.first()
        self.assertEqual(response.json()["count"], len(latest.signal_keys))

    def test_historical_fvg_state_does_not_leak_later_mitigation(self):
        self.analyze()
        for signal in ICTSignal.objects.filter(category="fvg"):
            payload = signal_as_of(signal, signal.confirmed_at)
            self.assertEqual(payload["status"], "open")
            self.assertEqual(payload["history"], [])
            self.assertFalse(payload["mitigated"])

    def test_status_filter_applied_before_limit(self):
        self.analyze()
        response = self.client.get("/api/ict/analysis/", {
            "symbol": "TEST", "timeframe": "H1", "status": "untouched", "limit": 1})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["count"], min(1, ICTSignal.objects.filter(status="untouched").count()))
