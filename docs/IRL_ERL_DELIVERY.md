# ICT Internal & External Range Liquidity — delivery

Date: 2026-11-04. Implementation extends the existing advisory system.
**Operational acceptance is pending runtime, visual and real-history evidence.**
The attachment is a specification, not proof of correctness or performance.
See the [audit and pre-implementation design](IRL_ERL_DESIGN.md).

## Files and architecture

| Source | Responsibility |
| --- | --- |
| [ICTRangeTypes.mqh](../Include/ICTRangeTypes.mqh) — new | Shared configuration, range/level/zone/snapshot/event types, state/reason enums, geometry gate |
| [ICTRangeEngine.mqh](../Include/ICTRangeEngine.mqh) — new | Pure range selection, membership, liquidity lifecycle, IRL classification/ranking, rotation reducer, live chronological adapter, bounded history/CSV |
| [ICTRangeInputs.mqh](../Include/ICTRangeInputs.mqh) — new | Identical named configuration inputs for standalone EA and calculation service |
| [ICTRangeBridge.mqh](../Include/ICTRangeBridge.mqh) — new | Schema-versioned binary snapshot, bounded lengths/counts, account/chart scope, odd/even sequence commit and freshness checks |
| [ICTRangeRenderer.mqh](../Include/ICTRangeRenderer.mqh) — new | Scoped range/IRL/ERL/target/rotation objects and draggable paged dashboard |
| [FVGDetector.mqh](../Include/FVGDetector.mqh) — extended | Shared candidate formation/lifecycle helper `SRMPFVGAtRates`; existing finder delegates to it |
| [OrderBlockDetector.mqh](../Include/OrderBlockDetector.mqh) — extended | Existing algorithm exposed as `SRMPFindOrderBlockFromRates`; original symbol/timeframe API preserved |
| [ICTConfluenceScore.mqh](../Include/ICTConfluenceScore.mqh) — extended | Range-mode score weights IRL quality continuously, retaining legacy scoring API/defaults |
| [ICTDecisionEngine.mqh](../Include/ICTDecisionEngine.mqh) — extended | `ICTAnalyzeRangeDecision` applies existing protection, quote, spread, daily loss and risk calculator before score approval |
| [ICTDecisionSupportEA.mq5](../Experts/ICTDecisionSupportEA.mq5) — integrated | Owns range engine, publishes authoritative snapshot, renders layers and uses existing optional alert manager |
| [RiskCalculationService.mq5](../Experts/RiskCalculationService.mq5) — integrated | Same engine and decision path; publishes snapshot for the indicator |
| [SmartRiskDashboard.mq5](../Indicators/SmartRiskDashboard.mq5) — integrated | Reads service snapshot, never independently selects IRL/ERL or calls the risk calculator |
| [ICTRangeTests.mq5](../Tests/ICTRangeTests.mq5) — new | Chronological deterministic fixtures, geometry/membership/coverage and transport checks |
| [ICTRangeReplayEA.mq5](../Tests/ICTRangeReplayEA.mq5) — new | Tester-only real-history probe and paper ledger; no trading requests |
| [CompileICT.ps1](../Tests/CompileICT.ps1), [RunICTTests.ps1](../Tests/RunICTTests.ps1) — extended | Separate build log tags and explicit whitelist for new test programs |
| [ict_range.ini](../Tests/ict_range.ini) and six `ict_range_<symbol>_<month>.ini` files — new | Disabled-trading fixture and September/October Forex/Gold/index replay configurations |

Flow: **closed broker data → shared range engine → existing decision/risk
calculator → one chart-scoped snapshot → indicator and dashboard**.
The standalone EA uses the same engine/API. No new production trading EA exists.
Disable `Enable_IRL_ERL` to retain the previous standalone/service decision path;
disable `Show_IRL_ERL` in the indicator to return to its earlier overlay view.

## Range and liquidity rules

The HTF range uses the latest confirmed opposite high/low swing pair from the
existing structure detector, representing one low→high or high→low leg. It does
not use rolling-window extrema. Both right-hand confirmation bars must have
closed by the LTF observation. HTF structural bias is distinct from leg direction.
Neutral or opposing HTF bias prevents actionable rotation.

RangeID comprises symbol, HTF and source pivot times. New confirmed endpoints
create a new version. Backward endpoints or revised observed OHLC fail closed.
Retired ranges retain original bounds and confirmation times; a completed target
is not relabeled as a failed setup when a later range replaces it.

Each level and zone has an owning RangeID. Boundary BSL/SSL are external boundary
pools. Prior D/W/M and confirmed minor/equal swing levels are classified by
position: external, boundary, internal or crossing. A PDH inside the range is an
internal pool, not ERL. A zone crossing a boundary is not eligible IRL. FVG/OB/
Breaker are explicitly PD arrays; they are not measured resting-order liquidity.

The project's existing session definition is a completed **broker D1 session**.
Its high/low aliases PDH/PDL and is not duplicated as an extra pool. Separate
London/New York session-high/low aggregation is not implemented. Existing New
York kill-zone/DST logic can still supply optional decision-score evidence.

Liquidity reducer states: UNTOUCHED, APPROACHING, SWEPT, BREAKOUT, CONSUMED,
INVALIDATED. A sweep requires excursion **strictly greater** than the configured
noise threshold and a closed reclaim. A single outside close is a candidate;
consecutive outside closes or directional displacement can confirm continuation.
An outside close alone is never labeled a reversal.

Pool consumption survives refreshes and source-identical range boundary changes.
A level whose activation predates retained LTF coverage is conservatively
INVALIDATED for target selection: the engine cannot assert it is untouched.
This particularly limits weekly/monthly targets after first attachment/restart.
It can become known from observations if the EA runs across a new period boundary.
There is no invented historical touch state or fallback target.

## IRL and rotation

MTF supplies FVG/OB/Breaker arrays, LTF supplies liquidity/reaction observations.
The existing three-candle FVG geometry and partial/full/close-through lifecycle
are reused. Minimum size combines broker tick and MTF rolling true-range scale.
The middle candle is checked against a prior-only 14-bar true-range mean and body
fraction. This is a documented rolling ATR-style mean, not Wilder's smoothing.

OB retains existing displacement + prior-structure-break qualification and
lifecycle. A breaker requires a previously qualified OB, its later invalidation,
and an opposite confirmed MTF break. It is not simply the last opposite candle.
The candidate set is bounded: up to 12 recent FVG candidates plus the two OB-side
searches, within the configured lookback/zone age. It is not an exhaustive PD-array
database. Crossed or inactive candidates cannot become entry arrays.

IRL quality uses structure 20, premium/discount 20, array confluence 20,
displacement 15, freshness 15 (partial touch 5), and HTF alignment 10. Fully
mitigated/invalidated arrays have no eligible quality. Selection requires an
internal, same-owner zone in the scenario's discount/premium location.

Reversal: ERL sweep → **later** aligned MTF MSS → qualified IRL → closed directional
reaction → unconsumed ERL targeting. Continuation uses aligned BOS instead of
pretending a sweep happened. Breakout, failed sweep, expired/invalid arrays,
neutral/conflicting structure, target reached and consolidation are separate
outcomes. A closed touch plus directional close beyond zone midpoint defines
reaction; this does not claim knowledge of the candle's intrabar tick order.

State transitions are retained once per newly observed closed LTF bar with
trigger, confirmation time, RangeID, SignalID, direction, OHLC, invalidation,
entry-zone bounds and target. Same-bar refresh does not shift confirmation time.
The reducer may confirm candidate/sweep or touch/reaction on the same closed bar;
it does not invent intervening ticks or require all ten states in every scenario.

TP1 and TP2 rank distinct unconsumed same-range ERL in the scenario direction.
Targets are conditional. The entry is a **proposed tick-rounded zone midpoint**
after reaction, not an executed fill or guaranteed executable market price.
Stop lies beyond scenario invalidation plus configured tick buffer. Gross RR
geometry must pass first; the existing broker calculator then checks net RR
after slippage/cost reserves, broker lot/stop constraints and free margin.

## Score, risk and execution boundary

Range-mode hard gates precede numerical score approval. The existing nine weight
inputs remain configurable. HTF, liquidity event, structure, displacement, SMT and
session retain their weight groups. The FVG+OB+Premium/Discount weights (default
30) form the IRL-quality group and contribute `round(group_weight × quality/100)`.
Legacy mode still uses its original binary evidence-weight score.

The default moderate/strong thresholds remain 65/80. SMT/session add optional
evidence; missing intermarket history adds no SMT points. Explicit existing
mandatory settings can block approval. Continuation does not receive sweep points
unless a confirmed external breakout supplied the liquidity event. Scores and
IRL quality are rule confluence, not calibrated win probabilities.

Risk amount, volume and net RR remain unavailable until risk gates can be
calculated. Healthy enabled/unlocked protection with saved reference is still
required by the production decision path. The upgrade does **not** arm protection.
BUY/SELL on the range panel means an advisory proposal; no execution occurs.

The following modules are intentionally unchanged and have a recorded
[hash baseline](IRL_ERL_PROTECTION_BASELINE.csv): RiskCalculator, PositionMonitor,
ProtectionPersistence, EmergencyController and RiskProtectionEA. The default
per-position 3% of saved reference still triggers configured account-wide close/
cancel when armed. Reference capital, retries, ticket/result checks and retcode
logging were not modified. Netting/Hedging execution acceptance is not newly
established by this upgrade.

## Configuration and use

1. Compile/install the existing Experts/Include/Indicators layout. Put the
   calculation service and indicator on the same chart with matching Instance_ID.
   Alternatively use standalone ICTDecisionSupportEA on its own chart. There is
   one authoritative analysis producer per chart. Protection remains on its
   separate existing chart, under existing arming rules.
2. `Enable_IRL_ERL=true` selects range mode. `Range_Auto_Trading=false` is mandatory;
   setting it true fails initialization. No order-opening implementation exists.
3. Defaults are Range_HTF=H4, Range_MTF=M15, Range_LTF=M5. These range timeframes
   control this model's structure/PD arrays/reaction; older advisory timeframe
   inputs still govern the retained legacy/SMT context. Require HTF > MTF > LTF.
4. Tick thresholds use `SYMBOL_TRADE_TICK_SIZE`, not Forex pip assumptions.
   Tolerance=max(2 ticks, 0.02 LTF true-range mean); sweep penetration=max(3 ticks,
   0.05 mean). Equal threshold=3 ticks. Minimum range width=20 ticks.
   Minimum FVG=max(2 ticks, 0.05 MTF mean). Adjust these per broker symbol.
5. Lookback=240 closed bars per timeframe (allowed 80–1000). Swing left/right=2/2.
   Maximum zone age=48 **MTF bars**. Sweep expiry uses equivalent newly processed
   LTF bars. History is bounded to 64 retired ranges and 256 transitions.
6. Require_MSS applies to reversal; confirmed aligned BOS remains necessary for
   continuation. Require_Displacement and Use_OB_Confluence are configurable.
   The existing entry-zone mode selects FVG-only, OB-only or either/Breaker.
7. EA Range_Show_* and indicator Show_Range/IRL/ERL/Targets/Rotation flags control
   their local layers. Indicator configuration does not recompute the range.
   Use `Show_Advisory_Panel=false` when using the new range panel to avoid stacking
   two left panels. Existing planner controls and risk display remain available.
8. Range panel position/width/height are configurable. Select/drag its background,
   and use Next for pages. Objects have chart/instance prefixes, stable slot names,
   source IDs in metadata, and bounded counts. Cleanup is confined to that prefix.
   Historical sweep/reaction linkage is schematic; future target linkage is
   dashed and never rendered as actual future price data.
9. Existing standalone popup/push/sound/log/cooldown inputs apply. Service transition
   logging is available through Range_Log_Events; alerts remain off by default.
10. Range_Export_History writes bounded CSV history to terminal/Tester MQL5 Files
    on deinitialization, with a timestamped filename. It is an audit export, not
    a crash-durable full state journal. History is not automatically restored
    across restarts. Reattachment rebuilds only the retained lookback.

Scenario example: a closed SSL excursion and reclaim does not yield BUY. The
model waits for a later aligned MSS/displacement, a discount internal PD array,
a closed retracement/reaction, an eligible upper ERL and passing net RR/risk.
The bearish example mirrors this with BSL and premium. A confirmed external
breakout supplies continuation evidence rather than an automatic opposite trade.

## Reproduction commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File Tests/CompileICT.ps1 -LogTag irl_erl
powershell -NoProfile -ExecutionPolicy Bypass -File Tests/RunICTTests.ps1 -Mode Run -Config ict_range.ini
powershell -NoProfile -ExecutionPolicy Bypass -File Tests/RunICTTests.ps1 -Mode Run -Config ict_detector.ini
powershell -NoProfile -ExecutionPolicy Bypass -File Tests/RunICTTests.ps1 -Mode Run -Config ict_range_EURUSD_09.ini
```

The six real-history configurations cover EURUSD, XAUUSD and US30 in September
and October 2026. Verify actual broker names; US30 is not asserted to exist on
every broker. Treat October as the chronological holdout; no parameter tuning or
performance comparison has been executed. Forward/demo observation is separate.
The runner rejects account credentials, startup scripts and parameter overrides;
use an already configured demo/test terminal manually for runtime execution if
the isolated terminal lacks a tester account. Do not send account passwords in chat.

## Verification and acceptance boundary

Build logs for this delivery use `docs/<program>.irl_erl.compile.log`; binaries
are published beside sources. A final source/header/binary manifest and Tester
attempt log accompany the [verification report](IRL_ERL_VERIFICATION.md).
Compile alone cannot certify runtime or trading behavior.

Fixture coverage includes confirmed range/ID, HTF close availability, prefix
invariance, internal/external/crossing membership, owner isolation, noise vs sweep
vs breakout, sticky consumption, BUY/SELL rotation, closed reaction, distinct
targets, gross RR veto, missing data, stable event time, retired history and
snapshot pack/unpack/in-progress/truncation checks. Prior FVG/OB lifecycle and
structure fixtures remain available.

The replay EA is Tester-only and never sends an order. It has a one-position
paper ledger with proposed limit-entry crossing, quote-based modeled fill/exit,
rechecked broker risk preview, fixed 1% paper risk/2% cap, estimated cost reserve
and adverse exit slippage. It reports signals, pending invalidation, fills,
TP/SL outcomes, after-cost paper expectancy, realized paper R and modeled equity
drawdown **only if actually run and virtual trades close**. It discloses open
virtual positions. These are Tester-model/paper metrics, not broker executions.
It exercises technical range and default score/risk geometry, not production
protection arming or mandatory SMT/session workflows. No performance numbers are
available when the tester cannot initialize.

Remaining acceptance work: actual fixture PASS records; synchronized broker
replay and holdout/forward results; visual validation at several chart sizes;
history-revision/restart/coverage behavior under real broker data; spread/margin/
slippage rejection and Netting/Hedging regression. A separate London/NY session
range engine, exhaustive PD-array archive and crash-persistent restore are not
implemented. Full completion criteria in the attachment are therefore not yet
accepted, even when the final build is clean.

Transport details were checked against the primary MQL5 references for
[FileWriteArray](https://www.mql5.com/en/docs/files/filewritearray),
[FileWriteString](https://www.mql5.com/en/docs/files/filewritestring) and
[FileReadString](https://www.mql5.com/en/docs/files/filereadstring).
