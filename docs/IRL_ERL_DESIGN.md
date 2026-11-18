# IRL/ERL audit and design — 2026-11-04

## Audit before implementation

Inventory: 4 production EAs, 1 indicator, 9 existing test programs, shared
headers, configuration files and historical reports. No Git metadata or
AGENTS.md is present in this workspace. The prior upgrade is the baseline;
its runtime tests remain blocked by a missing isolated Tester account.

| Existing source | Verified API / reuse | Gap or integration change |
| --- | --- | --- |
| `Include/MarketStructure.mqh` | `SMarketStructure`, `SRMPAnalyzeStructureFromRates` and asymmetric confirmed swings, latest BOS/MSS | No range identity/version; latest high/low is not yet a range lifecycle |
| `Include/LiquidityDetector.mqh` | `SRMPPriorPeriodEvidenceAt`, prior D/W/broker-day session, sweep evidence | No range membership, persistent per-level consumption or breakout classifier |
| `Include/FVGDetector.mqh` | `SFairValueGap`, chronological formation/lifecycle and inversion evidence | Expose one shared candidate evaluator to enumerate eligible arrays |
| `Include/OrderBlockDetector.mqh` / `OrderBlockValidator.mqh` | Displacement + break confirmation, lifecycle and direction filter | Expose existing detector over chronological rates for as-of replay; no algorithm replacement |
| `Include/ICTDecisionEngine.mqh` | `SICTDecision`, `CalculateRisk` integration, protection/quote/daily gates | Add opt-in range analysis path; preserve existing path when disabled |
| `Experts/ICTDecisionSupportEA.mq5` | Read-only analysis, existing decision panel and alerts | Own shared range engine instance; draw/publish one authoritative snapshot |
| `Experts/RiskCalculationService.mq5` | Chart-local request/response and advisory publication | Same engine/configuration and risk path; publish full snapshot |
| `Indicators/SmartRiskDashboard.mq5` | Existing planner, market overlays, timer/cache and chart prefix | Read service snapshot instead of independently determining IRL/ERL |
| `Include/AdviceBridge.mqh` | Account + chart namespace, readable text transport | Add versioned, sequence-checked range snapshot transport |
| `Include/ICTDecisionRenderer.mqh`, `DashboardComponents.mqh` | Positionable paged panel, scoped primitive renderers | Reuse primitives for range/IRL/ERL layers and status |
| Risk calculator, position monitor, persistence, emergency controller, protection EA | Broker-aware RR/cost/margin; saved reference, per-position 3% and account-wide close/cancel | Preserve source and behavior; verify hashes after implementation |

## Planned module/API boundary

- `ICTRangeTypes.mqh`: configuration, range/level/zone/event/snapshot types and reason codes.
- `ICTRangeEngine.mqh`: pure range selection, membership, level lifecycle,
  IRL ranking, rotation reducer, chronological runtime adapter and bounded history.
- `ICTRangeInputs.mqh`: identical EA/service inputs and configuration mapping.
- `ICTRangeBridge.mqh`: a single writer per chart, schema version and odd/even
  sequence commit. Readers reject stale, incomplete, wrong-symbol snapshots.
- `ICTRangeRenderer.mqh`: bounded scoped objects and paged status panel.
- Existing decision engine gains a separate callable range path; risk/execution
  stays outside the market-state engine. No new trading EA is created.
- `ICTRangeTests.mq5` and Tester configuration: pure chronological fixtures and
  bridge roundtrip, plus a real-history replay probe using the same engine.

## Deterministic rules selected before coding

HTF confirmed structural swings define context. The newest confirmed opposite
pivot pair defines one directional leg (low→high bullish; high→low bearish),
not rolling extrema. Both endpoints and right-bar confirmations must be known
at the LTF observation close. New endpoint identities create a new immutable
range version; prior versions are retired and retained in bounded history.
MTF provides PD arrays and structure events, LTF provides sweeps and reaction.
Every level/zone carries its owning RangeID. No mixed-range target selection.

Range boundary BSL/SSL are external boundary pools. D/W/M/prior broker-day
session levels are external only beyond the corresponding boundary, internal
when strictly inside, and boundary when coincident within tick tolerance.
Cross-boundary zones are explicitly CROSSING and cannot be selected as IRL.
Minor/equal swings are pools, whereas FVG/OB/Breaker are PD arrays, never
assertions about observable resting orders.

Sweep requires penetration beyond noise and a closed return through the level.
Outside closes alone create a candidate, then breakout after configurable
consecutive closes or directional displacement. Sweep and breakout do not
automatically establish reversal. Consumed/broken/swept pools cannot become
fresh targets merely because price returns or a snapshot refreshes.

Default reversal requires sweep → later MTF MSS and displacement → valid
discount/premium IRL → later closed reaction. Continuation uses aligned
confirmed BOS instead of pretending a sweep occurred. Target selection ranks
unconsumed same-range ERL in the scenario direction. Failures/expired zones,
unresolved structure and missing synchronized closed data produce explained
NO TRADE. RR after costs and the existing protection/risk gates precede score
approval. Scores remain rule confluence, not probabilities.

History is bounded in memory with CSV export, not an unlimited object/event
store. Broker history revisions are detected and fail closed until reset;
they do not rewrite previously recorded transitions. First attachment replays
only the configured bounded lookback and must disclose that coverage.

## Verification plan

Compile every affected consumer; run fixtures for range/ownership, prefix
invariance, sweep/breakout, lifecycle, bullish/bearish rotation and bridge
identity. Attempt isolated Tester with trading/DLL/cloud disabled. No runtime
PASS, market metrics or visual acceptance without actual evidence. Preserve
the protected-module hash baseline. Document tester-account/real-history and
out-of-sample limitations explicitly if execution remains unavailable.
