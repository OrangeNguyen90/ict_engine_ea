# Isolated Strategy Tester attempt — 2026-11-09

Result: **NOT VERIFIED**. The isolated terminal did not start the Tester because
no account was configured. No expert assertions or market replay ran.

Command, executed from the project root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tests\RunICTTests.ps1 -Mode Run -Expert ICTUnifiedTests -TimeoutSeconds 30
```

- Source was freshly compiled: `0 errors, 0 warnings`.
- Isolated terminal PID: 14676; runner start: `2026-11-09T16:47:30.3775898+07:00`.
- MetaTrader 5 x64 build 6295; approved [configuration](../ict_unified.ini).
- Terminal: workspace test runtime, not the installed trading terminal.
- Fresh terminal journal: [20261109.log](../.terminal/logs/20261109.log).
- Fresh Tester journal: [20261109.log](../.terminal/Tester/logs/20261109.log).

Fresh log excerpt:

```text
16:47:37.273 Tester  tester not started because the account is not specified
16:47:37.273 Terminal tester didn't start
16:47:39.095 Terminal exit with code -1000012353
16:47:39.250 Terminal shutdown with -1000012353 (tester not started because the account is not specified)
NOT VERIFIED: Strategy Tester requires an account in the isolated runtime.
```

The journal also records an occupied local MCP port; the explicit Tester
termination reason is the missing account. No process/port configuration was
changed to work around it. The isolated process exited; the installed terminal
was neither closed nor configured, and no credentials/config were imported.

Runtime, multi-symbol backtests, visual inspection and screenshots remain
unverified. Initialize a disposable demo/Tester runtime explicitly, then rerun
the command and the visual cases in the [delivery report](../../docs/MASTER_MTF_DELIVERY_20261109.md).
