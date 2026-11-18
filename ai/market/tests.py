import csv
import tempfile
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from pathlib import Path

from django.test import TestCase

from .data import import_market_file, parse_timestamp, resample_candles, validate_ohlcv
from .models import ImportBatch, MarketCandle
from .timeframes import detect_missing_candles


class MarketDataTests(TestCase):
    def test_ohlcv_validation_rejects_bad_ranges_and_volume(self):
        with self.assertRaises(ValueError):
            validate_ohlcv({"open": 10, "high": 9, "low": 8, "close": 9})
        with self.assertRaises(ValueError):
            validate_ohlcv({"open": 10, "high": 11, "low": 8, "close": 9, "volume": -1})
        self.assertEqual(validate_ohlcv({"open": 10, "high": 11, "low": 8, "close": 9})["open"], Decimal("10"))

    def test_csv_import_incremental_and_provenance(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "candles.csv"
            with path.open("w", newline="", encoding="utf-8") as stream:
                writer = csv.DictWriter(stream, fieldnames=["timestamp", "open", "high", "low", "close", "volume"])
                writer.writeheader()
                writer.writerow({"timestamp": "2024-01-01T00:00:00Z", "open": 10, "high": 12, "low": 9, "close": 11, "volume": 5})
                writer.writerow({"timestamp": "bad", "open": 1, "high": 2, "low": 0, "close": 1, "volume": 1})
            batch = import_market_file(path, symbol="EURUSD", exchange="FX", timeframe="H1", data_source="fixture")
            self.assertEqual((batch.rows_read, batch.rows_created, len(batch.warnings)), (2, 1, 1))
            candle = MarketCandle.objects.get()
            self.assertEqual(candle.timestamp, datetime(2024, 1, 1, tzinfo=timezone.utc))
            self.assertEqual(candle.provenance, batch)
            repeated = import_market_file(path, symbol="EURUSD", exchange="FX", timeframe="H1", data_source="fixture")
            self.assertEqual(repeated.rows_skipped, 1)
            self.assertEqual(MarketCandle.objects.count(), 1)

    def test_timestamp_conversion_and_dst_rejection(self):
        self.assertEqual(parse_timestamp("2024-01-01 08:00:00", "America/New_York").hour, 13)
        with self.assertRaises(ValueError):
            parse_timestamp("2024-03-10 02:30:00", "America/New_York")
        with self.assertRaises(ValueError):
            parse_timestamp("2024-11-03 01:30:00", "America/New_York")

    def test_resampling_requires_complete_bucket_and_preserves_ohlcv(self):
        base = datetime(2024, 1, 1, tzinfo=timezone.utc)
        rows = [{"timestamp": base + timedelta(hours=i), "open": Decimal(i + 1),
                 "high": Decimal(i + 2), "low": Decimal(i), "close": Decimal(i + 1),
                 "volume": Decimal(2)} for i in range(4)]
        result = resample_candles(rows, "H4")
        self.assertEqual(len(result), 1)
        self.assertEqual((result[0]["open"], result[0]["close"], result[0]["volume"]), (Decimal(1), Decimal(4), Decimal(8)))
        self.assertEqual(resample_candles(rows[:-1], "H4"), [])

    def test_missing_candles_are_reported_not_created(self):
        stamps = [datetime(2024, 1, 1, hour=h, tzinfo=timezone.utc) for h in (0, 1, 3)]
        self.assertEqual(detect_missing_candles(stamps, "H1"), [stamps[1].replace(hour=2)])
        self.assertEqual(MarketCandle.objects.count(), 0)


class MarketFoundationApiTests(TestCase):
    def test_existing_phase_one_api_and_dashboard_still_render(self):
        dashboard = self.client.get("/")
        self.assertEqual(dashboard.status_code, 200)
        self.assertContains(dashboard, "Chưa có nến OHLCV thực")
        self.assertEqual(self.client.get("/api/videos/").status_code, 200)
        self.assertContains(self.client.get("/market/"), "Chưa có dữ liệu giá")

    def test_market_migration_adds_empty_tables_only(self):
        self.assertEqual(MarketCandle.objects.count(), 0)
        self.assertEqual(ImportBatch.objects.count(), 0)
