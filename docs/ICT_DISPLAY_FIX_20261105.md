# ICT display fix — 2026-11-05

Later UI update: [readable left dashboard with eye toggle](ICT_DASHBOARD_UI_20261105.md). This supersedes the standalone panel defaults/version described below.

The supplied US30 screenshot shows `Stale/future LTF close or invalid symbol tick` and no valid range snapshot. The range renderer intentionally removes its overlays when the snapshot is invalid. Changing the visible chart timeframe does not change the default H4/M15/M5 analysis inputs.

The installed terminal's Experts log additionally records at 09:27:19 that `ICTDecisionSupportEA (US30,H4)` rejected its dashboard/scoring/alert inputs. The terminal log confirms initialization failed with code 32767 and the EA was removed. The old combined error does not identify which input was invalid; no particular input value has been established from this log.

## Changes

- Range history is checked against the broker's last received quote time (`TimeCurrent`), replacing the PC-dependent estimate (`TimeTradeServer`). Missing broker time, future candles, history older than two LTF periods, and invalid tick size still reject analysis. Existing live quote, risk and protection gates are unchanged.
- Each history failure now has a distinct reason; stale/future reasons include the LTF, candle close and broker quote time.
- Invalid snapshots show `DATA BLOCKED` near the top of the range panel. Missing confirmation time displays `unavailable` instead of an epoch date. Configured timeframes are retained even before a range is available.
- Standalone EA initialization reports the actual values for invalid dashboard/scoring inputs and separate cooldown/mandatory-SMT errors. Range reason/status changes are logged without printing every timer refresh.
- Standalone EA version is 1.01. Default panel Y is 70 to clear the one-click trading controls. Saved chart inputs retain their values until reset or edited.

## Use

Use the rebuilt [standalone EA binary](../Experts/ICTDecisionSupportEA.ex5). Reattach it to US30, open Inputs and use Reset to restore valid defaults if the existing configuration was edited. Keep `Enable_IRL_ERL=true`, `Range_HTF=H4`, `Range_MTF=M15`, `Range_LTF=M5`, and `Range_Auto_Trading=false`. Set `Dashboard_Y=70` when retaining older saved settings. The visible chart may use H4 or another timeframe.

The standalone EA supplies its own panel and overlays. A separate risk indicator may show its calculation service as offline when this standalone EA occupies the chart; that indicator status does not indicate whether the standalone range engine is running.

## Validation

Compile evidence uses `docs/*.display_fix.compile.log`. The updated range fixture adds seven checks for valid close time, the exact age boundary, stale/future history, absent broker time, invalid tick size, and absent candle time.

All 16 programs compiled with zero errors and warnings. VS Code reported no errors in the changed MQL files. The rebuilt standalone EA, calculation service and dashboard indicator binaries were copied to their existing installed MT5 locations and verified against the workspace binaries by SHA-256. Previous binaries were backed up under `Tests/.display-fix-backup/20261105_093709`. The installed terminal did not produce a fresh standalone startup/status log after the copy; reattachment is still required to establish which version and inputs are active.

Compilation is not runtime acceptance. These new assertions have not been executed, and the resulting chart has not been visually verified. The Windows automation helper was unavailable (`Computer Use native pipe is unavailable`), so current chart inputs could not be inspected or reset through the UI. Earlier isolated Tester attempts are already documented as blocked before EA initialization by the missing tester account; they do not constitute PASS evidence for this fix.

Clock semantics: official [TimeCurrent reference](https://www.mql5.com/en/docs/dateandtime/timecurrent) and [TimeTradeServer reference](https://www.mql5.com/en/docs/dateandtime/timetradeserver).
