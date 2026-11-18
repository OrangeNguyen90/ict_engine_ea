# Phase 3 recovery report - 2026-11-01

## Findings and changes

The [gap analysis](GAP_ANALYSIS.md) separates configuration, display, integration, algorithm and validation gaps. The earlier NO TRADE screenshot was caused by a chart running the standalone log-only [TradingAdvisoryEA](../Experts/TradingAdvisoryEA.mq5) in place of [RiskCalculationService](../Experts/RiskCalculationService.mq5), with the protection EA stopped. The attached `ResetProtectionState.log` is a compile log only.

The calculation service now publishes a separate market-context snapshot about every five seconds. [MarketContext](../Include/MarketContext.mqh) analyzes closed H4/H1 swings, H1 BOS/MSS, H1 ATR, M15 FVG/mitigation, previous-day levels, equal swings and the latest closed M5 sweep. The [dashboard](../Indicators/SmartRiskDashboard.mq5) displays the context even when the trade recommendation is NO TRADE, and draws non-draggable swing, equilibrium, liquidity, FVG and advisory Entry/SL/TP objects. Confirmed BOS and sweep markers use bar-time-based names during the chart session; the BOS marker uses the break level captured on its confirmed candle. The service records a broker-history revision if a swing, BOS, FVG or sweep at the same timestamp changes price. Overlay extension to the current chart edge is visual only; it is not signal confirmation.

The [advisor](../Include/TradeAdvisor.mqh) now requires explicit protection health data and rejects invalid risk limits above 2% or minimum RR below 2. Its underlying closed-bar rules and broker-based calculator remain otherwise unchanged. The emergency 3% threshold, account-wide cancel/close action, and persistent lock were not modified in this Phase 3 recovery.

The standalone [advisory EA](../Experts/TradingAdvisoryEA.mq5) now reevaluates every five seconds while logging only bar/status/reason transitions. This avoids leaving a five-minute-old READY message unqualified after the quote or protection state changes. It remains log-only and cannot feed the dashboard.

The shared [risk calculator](../Include/RiskCalculator.mqh) and dashboard input validation now reject a minimum RR below 2.0. This prevents a preview configured with a weaker threshold from appearing valid. The existing protection threshold and emergency account-wide action are unchanged.

## Evidence and acceptance

All nine MQ5 programs in the project compile with zero errors and zero warnings in MetaEditor 5 build 6295 after the RR validation change. This is a build result, not a runtime PASS. The Strategy Tester-only [Phase 3 probe](../Tests/Phase3ProbeEA.mq5) is prepared to record A01/A02/A08, reason distributions, data availability, observed READY/WAIT/NO TRADE, revision observations and zero open exposure. It has not yet produced a Tester report.

The demo terminal log on 2026-11-01 records the protection EA being removed from its chart, followed by the service/advisor reporting `Protection offline, unhealthy or locked`. This is runtime evidence for the configuration diagnosis, but it does not satisfy the full A01 visual and transition checks. The updated binaries must be reloaded in MT5 to test the current source version.

A static search found no `OrderSend`, `CTrade`, buy/sell, position-modify/close or order-delete calls in the indicator, calculation service, standalone advisory EA, advisor or market-context module. This supports the read-only design but does not replace the A10 runtime order-history check.

| Test | Status | Evidence needed |
| --- | --- | --- |
| A01–A02 | Not run after fix | Tester probe log and chart state. |
| A03–A07 | Not run | Historical/probe cases including at least one complete READY path and numeric gate failures. |
| A08 | Not run after fix | Locked/stale service transitions and visual disappearance. |
| A09 | Not run | Historical reload and broker data revision review on Forex, Gold and index symbols. |
| A10 | Not run | Tester/demo order history before and after advisor/indicator attachment. |

Phase 3 is **not accepted** until the A01–A10 evidence is captured and reviewed. The [Phase 4 plan](PHASE4_IMPLEMENTATION_PLAN.md) is a plan only; no Phase 4 trading code has been added.
