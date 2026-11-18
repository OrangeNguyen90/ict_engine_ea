# Open issues and unverified limits - 2026-11-01

Latest status: [2026-11-04 ICT Smart delivery](ICT_SMART_DELIVERY_20261104.md). Advisory implementation has advanced under the current user request; runtime and visual acceptance remain open. Entries below describe the historical baseline and must be read with the newer report.

1. **Phase 3 acceptance:** A01–A10 have no post-fix runtime PASS evidence. The [Tester probe](../Tests/Phase3ProbeEA.mq5) is compiled and ready, but its report has not been produced while the user's MT5 session remains open. A probe covers only part of the visual and execution requirements.
2. **Chart rendering:** The revised two-column dashboard and market overlays need screenshots at multiple chart heights and widths. Compact panels may still need text shortening on small displays.
3. **Confirmed history:** BOS/sweep markers use candle-time names during a chart session. A broker history reload, chart reattachment and revision case have not been visually validated. A FVG zone and the latest swing levels update as new confirmed bars arrive; they are current context, not immutable historical signal markers.
4. **Market coverage:** No post-fix broker-specific A09 or numeric-gate evidence exists for EURUSD, XAUUSD and the broker's actual index symbol. `US30` in the prepared Tester config must be verified against the broker symbol list before use.
5. **Full READY path:** The current strict conjunction of H1 BOS, M5 previous-day sweep and M5 close trigger may be rare. No executed A07 case has yet shown TRADE READY with valid lot/margin/RR and no order placement.
6. **Phase 2 production behavior:** The 3% threshold latch, restart persistence, Netting, disconnect, rejection, partial close and retry exhaustion paths remain unaccepted. The passing Hedging execution fixture tests the shared cancel/close routine only.
7. **Phase 4:** Implementation and tests are intentionally pending the user's Phase 3 gate. See the [plan](PHASE4_IMPLEMENTATION_PLAN.md) and [test report](PHASE4_TEST_REPORT.md).

No result above is a guarantee of maximum realized loss or trading performance. No live-account test is planned.
