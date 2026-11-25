"""Contract checks for the optional read-only MT5 history collector."""

from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from .research.collect_mt5 import collect


class FakeMT5:
    __version__ = "test"
    SYMBOL_CHART_MODE_BID = 0
    TIMEFRAME_M15 = 15

    def __init__(self, stamp):
        self.stamp = stamp
        self.shutdown_calls = 0

    def symbol_info(self, symbol):
        return SimpleNamespace(visible=True, chart_mode=0, point=0.1,
                               trade_tick_size=0.1, digits=1)

    def copy_rates_range(self, symbol, timeframe, start, end):
        return [{"time": int(self.stamp.timestamp()), "open": 100, "high": 101,
                 "low": 99, "close": 100, "tick_volume": 10, "spread": 2}]

    def last_error(self):
        return (0, "ok")

    def shutdown(self):
        self.shutdown_calls += 1


class CollectorTests(unittest.TestCase):
    def test_requested_end_must_include_complete_last_bar(self):
        start = datetime(2024, 1, 1, tzinfo=timezone.utc)
        module = FakeMT5(start)
        info = SimpleNamespace(company="Test Broker", maxbars=10000)
        with TemporaryDirectory() as directory, patch(
                "market.research.collect_mt5.connect", return_value=info):
            early = Path(directory) / "early.csv"
            with self.assertRaisesRegex(ValueError, "no closed history"):
                collect(module, terminal="unused", symbol="US500", timeframe="M15",
                        start=start, end=start + timedelta(minutes=14), output=early)
            self.assertFalse(early.exists())
            complete = Path(directory) / "complete.csv"
            receipt = collect(module, terminal="unused", symbol="US500", timeframe="M15",
                              start=start, end=start + timedelta(minutes=15), output=complete)
            metadata = json.loads(Path(receipt["metadata"]).read_text(encoding="utf-8"))
            self.assertEqual(receipt["count"], 1)
            self.assertFalse(metadata["price_type_historically_verified"])
        self.assertEqual(module.shutdown_calls, 2)


if __name__ == "__main__":
    unittest.main()
