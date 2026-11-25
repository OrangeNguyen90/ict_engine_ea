"""Read-only export through the official optional MetaTrader5 Python package.

Only attaches after verifying the requested terminal is already running. No
login, account changes, Market Watch changes, or trading calls are performed.
"""
import argparse
import csv
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import subprocess

from .data import file_digest, parse_time
from .types import TIMEFRAME_SECONDS


def running_terminal_paths():
    if os.name != "nt":
        raise ValueError("MT5 collection requires Windows and an already running terminal")
    command = ("@(Get-Process -Name terminal64 -ErrorAction SilentlyContinue | "
               "Select-Object -ExpandProperty Path) | ConvertTo-Json -Compress")
    result = subprocess.run(["powershell.exe", "-NoProfile", "-Command", command],
                            capture_output=True, text=True, timeout=15, check=True)
    paths = json.loads(result.stdout) if result.stdout.strip() else []
    return [paths] if isinstance(paths, str) else paths


def connect(module, terminal):
    terminal = Path(terminal).resolve()
    paths = running_terminal_paths()
    if not any(Path(path).resolve() == terminal for path in paths if path):
        raise ValueError("requested terminal is not running; open it normally before collection")
    if not module.initialize(str(terminal), timeout=10000):
        raise ValueError(f"MT5 IPC connection failed: {module.last_error()}")
    info = module.terminal_info()
    if info is None or Path(info.path).resolve() != terminal.parent:
        module.shutdown()
        raise ValueError("connected terminal path differs from requested terminal")
    if not info.connected:
        module.shutdown()
        raise ValueError("terminal is not connected to its broker")
    return info


def probe(module, terminal, symbol):
    info = connect(module, terminal)
    try:
        instrument = module.symbol_info(symbol)
        if instrument is None:
            raise ValueError("symbol unavailable in the current terminal")
        return {"connected": True, "terminal_path": info.path, "maxbars": info.maxbars,
                "symbol": symbol, "visible": instrument.visible,
                "chart_mode": instrument.chart_mode, "point": instrument.point,
                "tick_size": instrument.trade_tick_size, "digits": instrument.digits,
                "package_version": module.__version__}
    finally:
        module.shutdown()


def collect(module, *, terminal, symbol, timeframe, start, end, output,
            server_label="connected-terminal", chunk_days=30):
    if timeframe not in TIMEFRAME_SECONDS or chunk_days < 1:
        raise ValueError("unsupported timeframe or invalid chunk length")
    if start.tzinfo is None or end.tzinfo is None or end <= start:
        raise ValueError("start/end must be timezone aware and increasing")
    output = Path(output)
    sidecar = Path(str(output) + ".meta.json")
    if output.exists() or sidecar.exists():
        raise ValueError("output already exists; choose a new export filename")
    info = connect(module, terminal)
    try:
        spec = module.symbol_info(symbol)
        if spec is None or not spec.visible:
            raise ValueError("symbol must already be visible in Market Watch")
        if spec.chart_mode != getattr(module, "SYMBOL_CHART_MODE_BID", 0):
            raise ValueError("collector currently requires Bid chart mode")
        api_tf = getattr(module, "TIMEFRAME_" + timeframe)
        delta = timedelta(seconds=TIMEFRAME_SECONDS[timeframe])
        now = datetime.now(timezone.utc)
        end = min(end.astimezone(timezone.utc), now)
        start = start.astimezone(timezone.utc)
        if end <= start:
            raise ValueError("requested interval contains no historical time")
        rows, chunks, errors = {}, [], []
        cursor = start
        while cursor < end:
            edge = min(cursor + timedelta(days=chunk_days), end)
            result = module.copy_rates_range(symbol, api_tf, cursor, edge - timedelta(microseconds=1))
            count = 0 if result is None else len(result)
            chunks.append({"start": cursor.isoformat(), "end_exclusive": edge.isoformat(), "rows": count})
            if result is None:
                errors.append({"start": cursor.isoformat(), "error": list(module.last_error())})
            else:
                for row in result:
                    stamp = datetime.fromtimestamp(int(row["time"]), timezone.utc)
                    if stamp < start or stamp >= end or stamp + delta > end or stamp + delta > now:
                        continue
                    values = tuple(float(row[key]) for key in ("open", "high", "low", "close"))
                    record = (stamp.isoformat(), *values, int(row["tick_volume"]), int(row["spread"]))
                    key = int(row["time"])
                    if key in rows and rows[key] != record:
                        raise ValueError("broker revised overlapping export rows; retry a fresh export")
                    rows[key] = record
            cursor = edge
        if not rows:
            raise ValueError(f"no closed history returned: {module.last_error()}")
        ordered = [rows[key] for key in sorted(rows)]
        output.parent.mkdir(parents=True, exist_ok=True)
        with output.open("x", encoding="utf-8", newline="") as stream:
            writer = csv.writer(stream)
            writer.writerow(["timestamp", "open", "high", "low", "close", "volume", "spread_points"])
            writer.writerows(ordered)
        first, last = parse_time(ordered[0][0]), parse_time(ordered[-1][0])
        # Calendar is not verified: this is an extraction status, not a
        # completeness claim about every scheduled exchange trading minute.
        boundary_ok = first <= start + timedelta(days=7) and last >= end - timedelta(days=7)
        metadata = {"schema_version": 1, "csv_file": output.name, "csv_sha256": file_digest(output),
                    "symbol": symbol, "timeframe": timeframe,
                    "timeframe_seconds": TIMEFRAME_SECONDS[timeframe], "count": len(ordered),
                    "broker": info.company, "server": server_label,
                    "source": "official MetaTrader5 Python copy_rates_range",
                    "package_version": module.__version__, "timestamp_basis": "UTC_API_documented",
                    "price_type": "bid", "price_type_historically_verified": False,
                    "point": spec.point, "tick_size": spec.trade_tick_size,
                    "digits": spec.digits, "requested_start": start.isoformat(),
                    "requested_end_exclusive": end.isoformat(), "actual_first": first.isoformat(),
                    "actual_last": last.isoformat(), "complete": not errors and boundary_ok,
                    "complete_scope": "API extraction and coarse boundary check, not calendar coverage",
                    "coverage_verified": False, "terminal_maxbars": info.maxbars,
                    "commission_history": "unknown", "contract_history": "not verified",
                    "chunks": chunks, "errors": errors,
                    "exported_at": datetime.now(timezone.utc).isoformat()}
        with sidecar.open("x", encoding="utf-8") as stream:
            json.dump(metadata, stream, ensure_ascii=False, indent=2, allow_nan=False)
        return {"csv": str(output), "metadata": str(sidecar), "count": len(ordered),
                "first": first.isoformat(), "last": last.isoformat(), "complete": metadata["complete"],
                "copy_errors": len(errors)}
    finally:
        module.shutdown()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--terminal", required=True)
    parser.add_argument("--symbol", default="US500")
    parser.add_argument("--timeframe", choices=TIMEFRAME_SECONDS, default="M15")
    parser.add_argument("--start")
    parser.add_argument("--end")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--server-label", default="connected-terminal")
    parser.add_argument("--probe", action="store_true")
    args = parser.parse_args(argv)
    try:
        import MetaTrader5 as mt5
        if args.probe:
            result = probe(mt5, args.terminal, args.symbol)
        else:
            if not args.start or not args.end or not args.output:
                parser.error("collection requires --start, --end and --output")
            result = collect(mt5, terminal=args.terminal, symbol=args.symbol, timeframe=args.timeframe,
                             start=parse_time(args.start), end=parse_time(args.end), output=args.output,
                             server_label=args.server_label)
        print(json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False))
        return 0
    except (ImportError, OSError, ValueError, subprocess.SubprocessError) as exc:
        parser.exit(2, f"Research export failed: {exc}\n")


if __name__ == "__main__":
    raise SystemExit(main())
