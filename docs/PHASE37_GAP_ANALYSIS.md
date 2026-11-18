# Phase 3.7 gap analysis

Status: preliminary source audit; Phase 3.7 is **not complete or validated**.
Existing compiled files and historical test reports are not evidence that the
current working tree passes a new compilation or terminal test.

## Existing architecture and evidence

- `RiskProtectionEA.mq5` runs account protection independently; the indicator
  does not execute orders. `RiskCalculationService.mq5` publishes advisory and
  market-context values using terminal global variables. The dashboard reads
  them on the same chart and checks freshness and protection status before
  displaying a ready plan. `TradingAdvisoryEA.mq5` is a separate advisory EA.
  MT5 allows one EA per chart: use separate charts for protection and the
  calculation service; attach the dashboard to the service's chart because
  the advisory bridge key includes ChartID. Do not use the standalone advisory
  EA as a replacement for the calculation service.
- `MarketStructure.mqh` returns recent and previous pivot prices/times and a
  latest-closed-bar close-based break; `LiquidityDetector.mqh` returns prior
  day levels and latest closed-candle sweeps. `FVGDetector.mqh` returns one
  selected gap with first-touch state. `OrderBlockDetector.mqh` returns one
  candidate or confirmed block with formation and confirmation bar times.
  SMT data includes matched primary swing coordinates and confirmation time.
- The dashboard already draws context levels, one FVG, a risk-gated setup,
  one OB and up to two SMT signals. OB and SMT have existing renderers.
  Drawing objects are not the protection EA's decision source.

## Gaps and risks

| Area | Existing | Missing or not established |
| --- | --- | --- |
| Structure | Two recent highs/lows, current BOS and heuristic MSS | Historical event stream, HH/HL/LH/LL labels, pivot confirmation timestamps, configurable wick/close BOS, separately validated MSS semantics |
| Liquidity | Prior-day levels, equal-level flags, same-bar sweep | Pool history, configurable return confirmation, sweep/breakout classification and historical rendering |
| FVG | One gap and first-touch flag | Multiple zones, midpoint, fill thresholds, invalidation, lifecycle history and rendering controls |
| OB | One block, scoring/validation and renderer | Multiple historical zones, durable transitions, HTF/nested classification and visibility limits |
| SMT | Two optional comparisons and renderer | Historical signal collection and independently selectable visibility per comparison; confirmed non-repaint requires terminal testing |
| Premium/discount | Current midpoint of latest structure swings | Full zone rendering, range change event history and HTF/LTF presentation |
| Trading zones | Existing ICT confluence snapshot | Configurable multi-signal zone intersection, temporal validity, priority and watch-zone rendering |
| Trade setup | Entry/SL/TP overlay and risk-gated advisory | TP2, risk/reward regions and complete display/input controls |
| Alerts | Logging and existing protection mechanisms | Opt-in event alerts, per-event cooldown and chart markers |
| Dashboard | Risk, advice and ICT views | Collapsible groups, full requested context and zone inventory |
| IPC | Timestamp and chart-specific global-variable keys | Explicit schema version, atomic snapshot/version check, comprehensive symbol/timeframe identity and stale-data validation |
| Verification | Existing historical tests and reports | Current-tree compilation, visual integration, replay/no-lookahead and performance tests |

Bar times in MQL rates are candle **open** timestamps. A closed-bar event must
not be treated as available at that timestamp: confirmation availability is
at the following bar/open or actual close, including session gaps. Existing
snapshots cannot establish replay-safe historical signal availability. The
current MSS heuristic is a break opposite to the current inferred bias, not
independent evidence of a fully qualified MSS.

The dashboard previously used timestamp-suffixed BOS and sweep object names,
but its cleanup used unsuffixed names. That allowed unbounded accumulation and
stale markers. The current change uses one bounded object per event category;
it does not claim historical retention.

## Required next work

Define immutable as-of event/lifecycle records and IPC schema; implement and
test detectors against closed-bar replay before adding multi-zone renderers,
watch-zone scoring and opt-in alerts. Preserve existing protection execution
and risk gates. Compile in MetaEditor, then run visual and Strategy Tester
checks including missing history, two comparison symbols, timeframe changes,
object ownership, stale IPC, long histories and protection regressions.
