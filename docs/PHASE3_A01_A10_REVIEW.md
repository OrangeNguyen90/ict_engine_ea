# Phase 3 A01–A10 review

This is a source and existing-evidence review, not a Strategy Tester or demo acceptance run. On review, an MT5 terminal was running; the prepared Tester configuration requests terminal shutdown, so it was not launched into that session. The existing OB/SMT probe report does not exercise the Phase 3 acceptance cases.

| Case | Source observation | Acceptance status and remaining evidence |
| --- | --- | --- |
| A01 | The advisor defaults to NO TRADE and checks connection, protection state, heartbeat and health before analysis. The dashboard independently checks protection before drawing a ready plan. | Partial source evidence. Exercise absent, stale, unhealthy and locked states and verify the panel and plan lines. |
| A02 | Missing structure data returns NO TRADE with an insufficient-data reason. Other missing inputs have separate failure paths. | Not accepted. Run the prepared probe and test missing data in each required timeframe. |
| A03 | Unaligned bias returns NO TRADE; missing aligned closed-bar BOS returns WAIT. | Not accepted. Replay both scenarios and check the displayed plan. |
| A04 | An absent, wrong-direction or mitigated FVG, or a gap outside premium/discount, returns WAIT. | Not accepted. Exercise mitigated and premium/discount cases. |
| A05 | Missing sweep or missing closed trigger confirmation returns WAIT. | Not accepted. Exercise both scenarios. |
| A06 | Spread and price-zone gates precede CalculateRisk; the latter applies the other numerical gates. | Not accepted. Exercise spread, quote age, stop, RR, volume and margin failures independently. |
| A07 | READY is assigned only after all preceding conditions and CalculateRisk succeed. | Not accepted. A full valid fixture or historical replay and displayed values are still required. |
| A08 | Advisor checks protection on each refresh; dashboard requires fresh advice and healthy protection to draw plan lines. Service deinitialization clears timestamps. | Partial source evidence. Test READY-to-locked, price exit, service stop and stale transitions on a chart. |
| A09 | Structure and FVG use closed bars; liquidity reads the previous D1 bar and closed trigger bars. | Not accepted. Reload and inspect Forex, Gold and actual broker index histories, including revisions and broker time zones. |
| A10 | No order execution calls were found in the advisor, dashboard, calculation service and their advisory path; the separate emergency controller can close or delete orders. | Not accepted. Compare order/deal history before and after an isolated Tester or demo run. |

The prepared [Phase3ProbeEA](../Tests/Phase3ProbeEA.mq5) checks only selected A01, A02 and A08 conditions plus observed exposure; its successful execution alone cannot pass all variants or visual requirements. Preserve the user's active terminal and use a separately configured Tester session with `ShutdownTerminal=0`, or run the probe manually in Strategy Tester. Record symbol, broker, dates, build, logs and chart evidence. No case above is marked PASS without its required runtime evidence.
