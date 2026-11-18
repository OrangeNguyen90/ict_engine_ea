# Phase A — ICT Smart Decision Support audit (2026-11-04)

Inspected the complete source/configuration inventory under Experts, Include,
Indicators, Tests and docs before modifying implementation. No AGENTS.md was
found in this workspace or its parent directories. This folder has no Git
metadata. Existing compile logs are historical evidence only; “present” below
does not imply a fresh runtime PASS.

| Module | Present / source and entry point | Operational evidence | Upgrade needed | New module |
| --- | --- | --- | --- | --- |
| ICT DecisionSupport | `Experts/ICTDecisionSupportEA.mq5`: `ICTRefresh`, `OnInit` | Historical compile; not runtime accepted | Initialize all scoring defaults, expose strong threshold/zone selection, panel controls | No |
| Market Structure | `Include/MarketStructure.mqh`: `SMarketStructure`, `SRMPAnalyzeStructureFromRates`, `SRMPAnalyzeStructure` | Closed chronological bars; confirmed left/right pivots; prefix fixtures | Require D1/H4/H1 data and reject severe conflict; preserve latest-bar BOS behavior | No |
| BOS/MSS | Same structure module; `bos_direction`, `mss`, `bos_time` | Latest closed candle only | Keep source and confirmation timestamps distinct | No |
| Liquidity | `Include/LiquidityDetector.mqh`: `SLiquidityState`, `SRMPAnalyzeLiquidity`, `SRMPFindRecentSweep` | Prior day/week/broker-session and local sweep helpers | Directional sweep selection, EQH/EQL chart labels, ranked targets | No |
| FVG/IFVG | `Include/FVGDetector.mqh`: `SFairValueGap`, `SRMPUpdateFVGEvidence`, `SRMPFindFVGFromRates` | Active/partial/full/invalidated lifecycle and inversion evidence | Reuse directional active finder; hide inactive by default. IFVG remains inversion evidence, not an entry signal | No |
| Order Block | `Include/OrderBlockDetector.mqh`, `OrderBlockValidator.mqh`, `OrderBlockScoring.mqh`, `OrderBlockRenderer.mqh` | `SOrderBlock`, `SRMPFindOrderBlock`, lifecycle validation and scoring exist | Remove duplicate directional detection algorithm by extending existing finder; use same active zones in evidence and planning | No |
| SMT | `Include/SymbolCorrelationEngine.mqh`, `SMTSignalValidator.mqh`, `SMTDivergenceDetector.mqh`, `SMTChartRenderer.mqh` | Timestamp-joined returns, measured regime and pivot-close confirmation | Preserve missing-symbol/stale alignment veto; disclose optional missing SMT | No |
| Premium/Discount | `Include/MarketContext.mqh`: `SMarketContextSnapshot`, `SRMPAnalyzeMarketContext` | Closed confirmed swing range and equilibrium | Explicit decision range and location; score OB-only PD too | No |
| Smart Decision Engine | `Include/ICTDecisionEngine.mqh`: `SICTDecision`, `ICTAnalyzeDecisionCore`, `ICTCollectEvidence`, `ICTAnalyzeDecision` | Already exists; independent evidence, chronology and risk gates | Required-evidence gate, selected-side consistency, TP2, mandatory daily context, explicit entry confirmation | No duplicate engine |
| Smart Dashboard | `Include/ICTDecisionRenderer.mqh`: `ICTRenderDashboard`; `Indicators/SmartRiskDashboard.mq5`: `ShowDecision` | Position/width/font inputs and paging exist; screenshots pending | Bounded height, draggable panel, group inputs, TP2/SL distance/zone | No |
| Smart Risk Manager | `Include/RiskCalculator.mqh`: `CalculateRisk`; `PositionMonitor.mqh`: `SRMPWorstPosition`; `ProtectionPersistence.mqh`; `EmergencyController.mqh`: `SRMPProcessEmergency`; `Experts/RiskProtectionEA.mq5` | Existing broker-aware calculations, persistent per-position threshold, account-wide ticket close/cancel with logs/retries | Reuse unchanged; expose decision veto and estimated risk | No |
| Service/transport | `Experts/RiskCalculationService.mq5`: `AnalyzeAndPublishDecision`, `PublishDecision`; `Include/AdviceBridge.mqh` | Numeric snapshot and bounded readable text | Publish additional decision fields without removing existing keys | No |
| Alerts | `Include/ICTAlertManager.mqh`: `CICTAlertManager::Update` | Optional popup/push/sound/log and cooldown | Retain advisory-only defaults | No |

Dependency flow: EA/service → decision engine → structure/liquidity/FVG/OB/SMT,
confluence/session and existing risk calculator/persistence. Renderer consumes
decision records and existing chart primitives. Protection alone imports the
emergency execution controller. The legacy `TradeAdvisor.mqh` and
`ICTConfluenceEngine.mqh` remain available to Phase 3 consumers.

## Baseline defects found

- Standalone EA assigns weights but omits `strong_score` and `entry_zone_mode` initialization.
- Decision fixtures still expect 70/10 defaults and incorrect displacement/FVG weights.
- Existing fields `target2` / `take_profit2` are never populated.
- Score priority can select the opposite side of the only risk-validated plan.
- `required` is displayed but not enforced as a complete mask before readiness.
- Directional evidence uses generic newest-side finders, unlike zone planning.
- Daily structure is optional, and no explicit daily-vs-HTF veto exists.
- Default overlay draws inactive FVG; EQH/EQL and entry-zone/TP2 are missing.

## Validation boundary

Compile every MQL5 consumer after shared header changes. Update deterministic
fixtures against actual defaults, masks, direction gates and target ranking.
Attempt isolated Tester runs with trading disabled; require fresh assertion and
completion evidence for any PASS claim. Historical chronological replay,
broker-symbol coverage and visual acceptance remain separate acceptance work
if the isolated terminal cannot start without a tester account.
