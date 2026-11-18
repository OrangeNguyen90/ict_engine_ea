# Project audit — 2026-11-02

## Location and scope

The selected workspace `E:/Project/ict_engine_ea` contained zero files at the start of this audit. The existing **MT5 Smart Risk Manager Pro** project was found in the neighboring folder `E:/Project/indicator_support_mt5/MT5_Smart_Risk_Manager_Pro`. After the audit and initial specification, its files were copied into this workspace for implementation. The original folder was not modified. The attached master prompt is a requested design; it is not evidence that any feature works.

## Existing components

| Component | Existing implementation | Integration implication |
| --- | --- | --- |
| Dashboard | `Indicators/SmartRiskDashboard.mq5` | Already draws planned prices and advisory context. Reuse its rendering and bridge; keep analysis optional. |
| Calculation service | `Experts/RiskCalculationService.mq5`, `Include/RiskCalculator.mqh`, `RiskBridge.mqh` | Owns broker-aware risk, volume, margin, quote, cost and RR checks. MQL5 indicators cannot call `OrderCalcProfit`/`OrderCalcMargin`; preserve service boundary. |
| Protection | `Experts/RiskProtectionEA.mq5`, `PositionMonitor.mqh`, `EmergencyController.mqh`, `ProtectionPersistence.mqh` | Account-wide per-position 3% reference-capital emergency policy with persistent lock and close-all behavior. Keep independent from ICT score and signal state. |
| Existing advisory | `TradeAdvisor.mqh`, `MarketStructure.mqh`, `LiquidityDetector.mqh`, `FVGDetector.mqh`, `AdviceBridge.mqh`, `MarketContext.mqh` | Closed-bar H4/H1/M15/M5 model already exists. Extend by versioned evidence and state records; avoid duplicate detectors. |
| OB and SMT | `OrderBlockDetector.mqh`, `OrderBlockValidator.mqh`, `OrderBlockScoring.mqh`, `SMTDivergenceDetector.mqh`, `SMTSignalValidator.mqh`, `SymbolCorrelationEngine.mqh` | Reuse and inspect semantics before adding alternatives. SMT correlation is configurable and must be checked against aligned bars. |
| Visualization | `ChartAnalysisRenderer.mqh`, `OrderBlockRenderer.mqh`, `SMTChartRenderer.mqh` | Reuse object lifecycle and namespace. |

The neighboring project contains 35 `.mq5`/`.mqh` files. The README describes the planner and advisory as non-executing; only the protection EA sends emergency cancel/close requests. MT5 permits one EA per chart, so the dashboard and calculation service share a chart while protection runs on another.

## Baseline and conflicts

- Existing advisory is a narrow, experimental PDH/PDL sweep + BOS + FVG model. Its READY condition is stricter and narrower than the attached proposal. A new decision model should be versioned and compared against this baseline; it must not silently change READY behavior.
- Existing advisory states are `NO TRADE`, `WAIT`, `TRADE READY`. The proposed eight-state model needs explicit mapping and stale-state invalidation.
- Existing OB scoring is separate from the proposed 100-point overall setup score. Neither score is a win probability.
- Existing risk preview defaults to 1% per trade, caps at 2%, and requires RR at least 2. The 3% protection threshold is an emergency trigger, not an entry risk budget.
- `Docs/TEST_REPORT.md` reports clean MetaEditor builds and limited Hedging fixtures as of 2026-11-01. This audit did not rerun compilation or tests.
- `Docs/OPEN_ISSUES.md` says Phase 3 acceptance A01–A10 lacks post-fix runtime PASS evidence. Production threshold latch, restart, Netting, disconnection, rejection, partial fill, broker-specific calculations, and visual overlays remain unaccepted.
- `Docs/PHASE4_IMPLEMENTATION_PLAN.md` states Phase 4 implementation must wait for Phase 3 acceptance. There is no evidence in the inspected reports that this gate has passed.

## Decision

The user subsequently authorized proceeding through the final phase and deferring runtime tests. That overrides the earlier Phase 4 sequencing gate for development, but does not establish runtime acceptance. The copied project is now the implementation base. The next engineering evidence remains the A01–A10 runtime report and broker symbol checks, followed by new decision-model replay and backtests.

## Inspected sources

- `E:/Project/indicator_support_mt5/MT5_Smart_Risk_Manager_Pro/README.md`
- `.../Docs/ADVISORY_RULES.md`
- `.../Docs/TEST_REPORT.md`
- `.../Docs/OPEN_ISSUES.md`
- `.../Docs/PHASE4_IMPLEMENTATION_PLAN.md`
- `.../Docs/PHASE4_TEST_REPORT.md`
- `.../Include/TradeAdvisor.mqh`
- `.../Experts/RiskProtectionEA.mq5`
- `.../Experts/RiskCalculationService.mq5`
- `.../Indicators/SmartRiskDashboard.mq5`
