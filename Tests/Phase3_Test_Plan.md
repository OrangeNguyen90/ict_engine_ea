# Phase 3 advisory test plan

All cases use a demo account or Strategy Tester. The advisor and calculation service must never open or modify a trade.

| ID | Scenario | Expected result | Status |
| --- | --- | --- | --- |
| A01 | Protection EA absent, stale, unhealthy, or locked | NO TRADE; entry plan hidden | Code review only |
| A02 | Insufficient H4/H1/M15/M5 closed history | NO TRADE with data reason | Not run |
| A03 | H4/H1 biases disagree or H1 BOS absent | NO TRADE or WAIT; no entry plan | Not run |
| A04 | M15 FVG mitigated or outside premium/discount | WAIT; no entry plan | Not run |
| A05 | Previous-day sweep absent or M5 close trigger absent | WAIT; no entry plan | Not run |
| A06 | Setup valid but spread, quote, stop, RR, lot, or margin gate fails | WAIT/NO TRADE; no entry plan | Not run |
| A07 | All closed-bar and numeric gates pass | TRADE READY with entry zone, SL, TP, lot, risk, reward, RR, invalidation, and reasons | Not run |
| A08 | Service stops, price leaves zone, or protection locks | Ready plan disappears within refresh/staleness interval | Not run |
| A09 | Reload historical chart with different broker symbols and time zones | No use of open candles; previous completed D1 level documented | Not run |
| A10 | Attach advisor and observe trade history | Zero advisor-originated orders | Not run |

Compile checks have passed. A historical and forward replay is needed to validate these cases and any claim about signal usefulness. See the [test report](../Docs/TEST_REPORT.md).
