# Build and test report - 2026-11-01

## MetaEditor compilation

MetaEditor 5 build 6295 generated EX5 files with **0 errors and 0 warnings** for the dashboard indicator, risk calculation and advisory service, standalone advisory EA, protection EA, reset script, and emergency execution fixture. EX5 files and compilation logs are beside their MQ5 sources.

## Strategy Tester evidence

The read-only [policy test EA](../Tests/ProtectionPolicyTestEA.mq5) ran in Strategy Tester mathematical-calculation mode. Its [log](../Tests/Reports/PolicyTester.log) records five PASS results and `failures=0`: 100/10,000 = 1% warning, 250/10,000 = 2.5% critical warning, 300/10,000 = emergency threshold, positive P/L = zero loss, and 299.99/10,000 = below the emergency threshold. The [HTML report](../Tests/Reports/SRMP_policy_test.htm) is stored with the log.

The [execution fixture](../Tests/EmergencyExecutionTestEA.mq5) ran with EURUSD M1, 2026-01-05 through 2026-01-06, on a simulated Hedging account. Its [final extracted log](../Tests/Reports/ExecutionTester.log) records fixture BUY and SELL positions opened, a pending order placed, the pending order canceled, and both positions closed. It ends with `failures=0`, `OnTester result 0`; the [HTML report](../Tests/Reports/SRMP_execution_test.htm) is also saved. An [earlier run](../Tests/Reports/ExecutionTester-first-run.log) reported one fixture assertion failure because the pending-order call returned `TRADE_RETCODE_DONE` instead of `TRADE_RETCODE_PLACED`, despite the order existing. The corrected assertion accepts either success code and requires `OrdersTotal()>0`. This test exercises the shared emergency cancel/close routine, not the production controller's threshold latch or persistence.

## Phase 3 advisory

All nine MQ5 programs, including the new Strategy Tester-only [Phase 3 probe](../Tests/Phase3ProbeEA.mq5), compiled with zero errors and warnings after the recovery changes. The dashboard clears stale advisory data after ten seconds, shows closed-bar market context and optional overlays, and hides advisory entry/stop/target data unless status is TRADE READY with healthy protection. No historical signal replay, post-fix visual chart check, or broker-specific forward validation has been completed. The [recovery report](PHASE3_FIX_REPORT.md) and [rule definitions](ADVISORY_RULES.md) document the implementation and limits.

On 2026-11-01, a user screenshot of EURUSD H1 showed the standalone `TradingAdvisoryEA` on the dashboard chart, with the calculation service absent from that chart and the protection controller stopped. The NO TRADE and blocked preview were expected for that setup. The screenshot also showed the right dashboard panel clipped by the short chart window and empty rows rendered as `Label`. The dashboard was changed to two columns with a chart-height-aware panel and blank-row text, then compiled with zero errors and warnings. The revised visual layout has not yet been confirmed in a new MT5 screenshot.

## Unverified acceptance items

- Phase 1 visual/dashboard behavior and broker-specific lot/margin calculations on EURUSD, Gold, and an index.
- Phase 2 production controller behavior for threshold-driven emergency latch, restart persistence, multiple charts, Netting, disconnection, partial fills, rejections, retry exhaustion, and pending orders created after lock.
- Phase 3 signal quality, repaint behavior under data revisions, and forward outcomes.
- Demo forward behavior and any live-account suitability. No live trading was performed by this project.

See the [Phase 1 plan](../Tests/Phase1_Test_Plan.md) and [Phase 2 plan](../Tests/Phase2_Test_Plan.md). Compilation and the limited Tester scenarios are not operational protection acceptance.
