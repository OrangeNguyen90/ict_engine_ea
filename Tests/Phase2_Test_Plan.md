# Phase 2 emergency protection verification

Run execution tests only in Strategy Tester or a disposable **demo** account. Record terminal build, broker server, account mode, symbol specifications, Inputs, journal excerpts, before/after positions and pending orders, and the persisted state file. A compiled source or a threshold-unit result does not establish emergency-execution success.

| ID | Scenario | Expected observation | Evidence now |
| --- | --- | --- | --- |
| TC01 | Reference 10,000; one position net loss 100. | 1% WARNING, no emergency. | Threshold calculation PASS in Strategy Tester; account alert not run. |
| TC02 | Reference 10,000; one position net loss 250. | 2.5% CRITICAL WARNING, no close. | Threshold calculation PASS; account alert not run. |
| TC03 | Reference 10,000; one position net loss 300. | Persist lock, then cancel all pending and close all positions. | Threshold calculation PASS; execution not run. |
| TC04 | One losing position crosses 3%, two others profitable. | All three positions close. | Not run. |
| TC05 | Attach protection EA to two charts. | One controller; no duplicate close requests; standby takeover after controller stops. | Not run. |
| TC06 | Restart MT5 after an emergency. | Saved reference and lock remain; unfinished requests resume. | Not run. |
| TC07 | Force a broker close rejection or invalid filling. | Retcode logged; bounded retry; CRITICAL if unresolved. | Not run. |
| TC08 | XAUUSD. | Preview cash risk follows broker contract/tick values. | Phase 1 demo check not run. |
| TC09 | EURUSD. | Pip, point, tick and cash risk correct for broker symbol. | Phase 1 demo check not run. |
| TC10 | Index CFD. | Points and ticks shown without Forex pip assumption. | Phase 1 demo check not run. |
| TC11 | Planned RR 1.5. | Plan BLOCKED. | Phase 1 demo check not run. |
| TC12 | Planned RR 2.5. | Only numeric RR gate passes; no advisory trade-ready claim. | Phase 1 demo check not run. |
| TC13 | Minimum lot exceeds budget. | Plan BLOCKED, never rounded up. | Phase 1 demo check not run. |
| TC14 | Disconnect after emergency latch. | CRITICAL/offline displayed; retry after reconnect. | Not run. |
| TC15 | Active pending orders during emergency. | All pending orders canceled and verified. | Not run. |
| TC16 | Balance falls, then MT5 restarts. | Initial reference unchanged. | Not run. |
| TC17 | Deposit or withdrawal. | Initial reference unchanged until explicit reset. | Not run. |
| TC18 | Hedging account, multiple positions on one symbol. | Every ticket closed; server results checked. | Not run. |
| TC19 | Manual/other magic-number position. | Still included in account-wide close. | Not run. |
| TC20 | Positions gone, one pending cancel rejected. | Never reports completed/LOCKED until pending order is gone. | Not run. |

`ProtectionPolicyTestEA.mq5` provides the executed boundary calculation test for TC01–TC03. `EmergencyExecutionTestEA.mq5` is a **Tester-only** fixture that creates small simulated exposure and checks the account-wide cancel/close loop. Its Hedging EURUSD run completed with `failures=0`, as recorded in the [execution log](Reports/ExecutionTester.log). This does not verify the production threshold latch, restart or rejection paths. Neither fixture may run on a live chart.
