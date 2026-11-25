"""Read-only diagnostic capture from an already running MT5 terminal.

No login, Market Watch changes, trading calls, or edits to terminal files.
Captures closed candles for production-MQL replay; no execution/P&L claims.
"""
import argparse
import csv
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "ai"))
from market.research.collect_mt5 import connect
import MetaTrader5 as mt5


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--terminal", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--symbols", nargs="+", default=[
        "EURUSD", "GBPUSD", "USDJPY", "USDCHF", "AUDUSD", "USDCAD",
        "XAUUSD", "XAGUSD", "US500", "USTEC",
    ])
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    manifest = {"captured_utc": datetime.now(timezone.utc).isoformat(),
                "source": "official MT5 copy_rates_from_pos start_pos=1",
                "scope": "CLOSED_CANDLE_DIAGNOSTIC_REPLAY", "series": []}
    info = connect(mt5, args.terminal)
    manifest["terminal_connected"] = bool(info.connected)
    manifest["package_version"] = mt5.__version__
    try:
        for symbol in args.symbols:
            spec = mt5.symbol_info(symbol)
            if spec is None or not spec.visible:
                manifest["series"].append({"symbol": symbol, "error": "not already visible"})
                continue
            for name, count in [("M5", 6000), ("M15", 6000), ("H1", 6000), ("H4", 400), ("D1", 400)]:
                rates = mt5.copy_rates_from_pos(symbol, getattr(mt5, "TIMEFRAME_" + name), 1, count)
                entry = {"symbol": symbol, "timeframe": name, "requested": count,
                         "point": spec.point, "tick_size": spec.trade_tick_size,
                         "digits": spec.digits, "count": 0 if rates is None else len(rates)}
                if rates is not None and len(rates):
                    path = args.output / (symbol + "_" + name + ".csv")
                    with path.open("w", newline="", encoding="utf-8") as handle:
                        writer = csv.writer(handle)
                        writer.writerow(["time", "open", "high", "low", "close", "tick_volume", "spread", "real_volume"])
                        for row in rates:
                            writer.writerow([int(row["time"]), float(row["open"]), float(row["high"]),
                                             float(row["low"]), float(row["close"]), int(row["tick_volume"]),
                                             int(row["spread"]), int(row["real_volume"])])
                    entry.update(file=path.name, first=int(rates[0]["time"]), last=int(rates[-1]["time"]),
                                 sha256=hashlib.sha256(path.read_bytes()).hexdigest())
                else:
                    entry["error"] = str(mt5.last_error())
                manifest["series"].append(entry)
                print(json.dumps({key: entry[key] for key in ("symbol", "timeframe", "count")}), flush=True)
    finally:
        mt5.shutdown()
    (args.output / "market_manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
