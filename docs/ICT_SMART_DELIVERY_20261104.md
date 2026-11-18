# ICT Smart Decision Support — implementation and validation, 2026-11-04

The existing engine was extended in place. **Build verification is complete;
runtime and visual acceptance are incomplete.** No expert was attached to the
user's running terminal, and no order was opened, modified or closed.

See the [pre-change module audit](ICT_SMART_AUDIT_20261104.md),
[SHA256 source/binary manifest](ICT_SMART_BUILD_20261104.csv) and
[fresh isolated Tester log](ICT_SMART_TESTER_20261104.log).
This delivery updates the 2026-11-03 baseline and its formerly outstanding TP2.
The current request authorizes this advisory upgrade; older Phase 4 planning
gates remain relevant to operational acceptance, not to this implementation.

## Implemented behavior

- [Standalone EA](../Experts/ICTDecisionSupportEA.mq5) initializes every scoring
  field from shared defaults before applying inputs. Default weights total 100,
  moderate threshold is 65 and strong threshold is 80. Strong threshold and
  FVG-only / OB-only / FVG-or-OB mode are configurable in both EA and service.
- [Decision engine](../Include/ICTDecisionEngine.mqh) requires closed daily and
  configured HTF/structure/setup history. Defaults are D1/H4/H1/M15/M5.
  Opposing non-neutral daily and HTF biases veto a plan. Opposing LTF bias also
  vetoes unless an aligned confirmed MSS resolves that reversal. Neutral daily
  bias alone is not treated as conflict. Monthly/weekly bias remains optional.
- Independent BUY/SELL evidence uses the same directional, active FVG/OB
  finders used by planning. Opposite-side zones cannot conceal eligible zones.
  OB displacement and premium/discount evidence work without an FVG.
- [Priority gate](../Include/ICTConfluenceScore.mqh) requires complete mandatory
  evidence, an eligible zone, data quality, passing plan/risk gates and agreement
  between score direction and plan direction. Both sides above threshold veto
  priority. Scores never override missing evidence, invalid SL, RR, spread,
  protection or calculator failures.
- Directional bias, setup state, invalidation and `entry_confirmed` are separate
  fields. Conservative policy: actionable priority still requires a validated
  entry plan; forming setups retain NO TRADE and their bias/state. PRIORITY and
  ENTRY CONFIRMED are advisory labels and never issue an order.
- TP1 is the nearest eligible liquidity level; TP2 is the next **distinct**
  level in the same direction, ranked from prior day/week/month and confirmed
  swing levels. Missing TP2 stays unavailable. RR/cash risk are checked against
  TP1, so a farther TP2 cannot rescue an invalid TP1 RR.
- [OB detector](../Include/OrderBlockDetector.mqh) now accepts optional direction
  and active-only arguments while preserving legacy defaults. Its extracted
  chronological lifecycle is shared with the existing validator and fixtures;
  duplicate OB detection code was removed from the decision engine. Missing or
  malformed requested lifecycle data cannot leave the block confirmed.
- [Panel](../Include/ICTDecisionRenderer.mqh) adds bounded height and pagination,
  draggable background, optional market/ICT/plan groups, range and location,
  entry zone, TP2, SL distance, risk amount and separate entry confirmation.
  Existing confirmed/missing evidence, veto reasons and disclaimer remain.
- [Chart renderer](../Include/ChartAnalysisRenderer.mqh) hides inactive FVG by
  default and adds EQH/EQL. The EA adds scoped entry-zone and TP2 objects.
  Existing OB/SMT/BSL/SSL/BOS/MSS/premium/discount overlays are reused.
  Object prefixes include chart ID; cleanup operates only in that namespace.
- [Calculation service](../Experts/RiskCalculationService.mq5) retains existing
  bridge keys and additionally publishes priority, entry confirmation, zone,
  TP2 and readable missing conditions. The legacy indicator also rejects
  future-dated service/protection timestamps.
- [Session helper](../Include/ICTSessionManager.mqh) uses live UTC normally.
  In Tester, unknown broker UTC offset disables session evidence. An explicit
  offset converts simulated broker time before applying New York DST rules.

## Preserved risk/execution boundary

[RiskCalculator](../Include/RiskCalculator.mqh),
[PositionMonitor](../Include/PositionMonitor.mqh),
[ProtectionPersistence](../Include/ProtectionPersistence.mqh),
[EmergencyController](../Include/EmergencyController.mqh) and
[RiskProtectionEA](../Experts/RiskProtectionEA.mq5) were not changed.
The existing requirement for a healthy, enabled, unlocked protection controller
before ENTRY READY remains. This upgrade does not arm protection.

Risk remains configurable per trade; estimated adverse slippage and costs feed
the broker-aware calculator, with minimum RR 2. The existing emergency rule is
loss on any **one position** divided by saved reference capital, default 3%,
followed by account-wide close/cancel when armed under existing configuration.
Ticket verification, logged retcodes and bounded retries remain in the separate
execution controller. No new execution module or automatic entry was added.

## Build and test evidence

MetaEditor 5 build 6295 compiled **all 14 workspace MQL5 programs**, each with
**0 errors and 0 warnings**, on 2026-11-04. Final-source hashes were compared
against staged compiler inputs, including every shared header. The resulting
EX5 files were copied back beside their workspace sources.

| Sources | Fresh build evidence |
| --- | --- |
| ICTDecisionSupportEA | [compile log](ICTDecisionSupportEA.smart.compile.log) |
| RiskCalculationService | [compile log](RiskCalculationService.smart.compile.log) |
| SmartRiskDashboard | [compile log](SmartRiskDashboard.smart.compile.log) |
| RiskProtectionEA, TradingAdvisoryEA | Individual `*.smart.compile.log` files |
| ICTDecisionTests, ICTDetectorTests | [decision log](ICTDecisionTests.smart.compile.log), [detector log](ICTDetectorTests.smart.compile.log) |
| EmergencyExecutionTestEA, OBSMTEmptyProbeEA, OBSMTProbeEA, Phase3ProbeEA, ProtectionPolicyTestEA, ProtectionPolicyTests, ResetProtectionState | Individual `*.smart.compile.log` files; compile only, no execution |

VS Code diagnostics reported no errors. Source inspection found trade close/
cancel calls only in the existing emergency controller, with no new-order calls
in production advisory paths.

Updated [decision fixtures](../Tests/ICTDecisionTests.mq5) cover all 512 evidence
masks with corrected weights, 65-point boundary, BUY/SELL/WAIT, dual-side veto,
missing-data/combined-hard-gate veto, wrong-side plan, missing MSS/zone,
mandatory SMT absence, OB-only selection, context conflict, distinct target
ranking, replay offset configuration and quote freshness. The combined gate
fixtures test decision gating; they do not exercise real broker SL/margin/RR.

Updated [detector fixtures](../Tests/ICTDetectorTests.mq5) retain chronological
prefix/pivot/FVG/liquidity cases, correct the invalidated gap-over expectation,
and add OB prefix exclusion, mitigation, later invalidation and expiry.

Both fixtures were **attempted** via the existing isolated portable runner:

| Configuration | Observed result |
| --- | --- |
| `ict_decision.ini` | 2026-11-04 11:17:56 broker/local log: tester not started because the account is not specified |
| `ict_detector.ini` | 2026-11-04 11:18:31 broker/local log: same pre-initialization failure |

Trading, DLL, remote and cloud settings were disabled. No account credentials
were copied or requested. Neither fixture reached OnInit/OnTester; **there is
no runtime PASS claim**, and no assertions or performance statistics resulted.

## Reproduce and use

From the workspace root in PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File Tests/CompileICT.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File Tests/RunICTTests.ps1 -Mode Run -Config ict_decision.ini
powershell -NoProfile -ExecutionPolicy Bypass -File Tests/RunICTTests.ps1 -Mode Run -Config ict_detector.ini
```

[CompileICT.ps1](../Tests/CompileICT.ps1) builds every consumer in the prepared
portable runtime and publishes successful binaries beside original sources.
The existing runner deliberately forbids account/parameter overrides. To get
runtime evidence, use these compiled fixtures manually in a demo/test terminal
with a configured tester account, keeping trading disabled.

Install the usual Experts/Include/Indicators layout. The standalone EA needs
its own chart because MT5 allows one EA per chart. Do not replace a working
calculation/protection EA on its existing chart. New panel settings are
`Dashboard_Height`, `Dashboard_Market_Group`, `Dashboard_ICT_Group`, and
`Dashboard_Plan_Group`; existing width/font/corner/position settings remain.
Select and drag the panel background to move it; paging preserves visible text.
`Show_Inactive_FVG` and existing `Show_Inactive_Order_Blocks` show the latest
historical context only. Default is active-only; this is not a full history
browser. `Entry_Zone_Mode` and `Strong_Priority_Score` control entry-zone policy
and strong classification. Equivalent service inputs start with `Decision_`.

For chronological Tester replay, set `Tester_Broker_UTC_Offset_Minutes` (or the
service equivalent) for the broker offset valid during that replay interval.
Default `9999` means unknown; mandatory Session then blocks readiness. Split
intervals across broker DST/offset changes; automatic broker DST inference is
not implemented.

## Outstanding acceptance

- Runtime execution of the updated fixtures and complete BUY/SELL/NO TRADE
  paths with actual broker risk calculations.
- Missing-symbol, stale/misaligned SMT and conflicting-timeframe replay against
  real synchronized history. Existing SMT validation was retained, not newly
  runtime-certified.
- Visual checks for dragging, pagination, group visibility, overlay scope and
  small/large charts on Forex, Gold and an actual broker index symbol.
- End-to-end chronological sweep → MSS → zone → retest replay. Structure still
  reports latest-closed-bar BOS/MSS as in the baseline; historical event storage
  is not introduced. Snapshot timestamps describe observations, not a stored
  immutable event ledger.
- IFVG is close-through inversion evidence already present in the FVG lifecycle;
  a separate IFVG retest entry strategy remains outside this implementation.
- Phase 2 restart/Netting/disconnection/rejection/partial-close acceptance stays
  outstanding. No execution behavior was changed or exercised here.

These limits prevent full Phase H acceptance. They do not affect the observed
compile result; no win probability, win rate or profitability claim is made.
