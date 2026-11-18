# Phase 4 implementation plan - gated

2026-11-04 update: the current user request authorizes the ICT Smart advisory implementation in the [latest delivery](ICT_SMART_DELIVERY_20261104.md). The original gate below remains an acceptance condition for operational rollout; it does not block the authorized read-only implementation. Other Phase 4 modules in this historical plan have not been implemented by this upgrade.

**Entry gate:** complete A01–A10 in the [Phase 3 test plan](../Tests/Phase3_Test_Plan.md), verify the chart overlays at multiple sizes and Forex/Gold/index broker symbols, then update the [Phase 3 recovery report](PHASE3_FIX_REPORT.md). Phase 4 implementation must not start while this gate is open.

| Module | Intended behavior | Safety boundary | Planned evidence |
| --- | --- | --- | --- |
| Portfolio Risk Monitor | Read all positions and pending orders; estimate current floating loss, planned stop exposure, symbol concentration and correlated symbol counts in account currency. | Read-only. Report unknown stop or conversion data explicitly. Do not alter the 3% per-position emergency rule or impose a new portfolio threshold without approval. | Hedging/Netting, missing SL, multiple symbols and broker contract data in Tester/demo. |
| Multi-Timeframe Analysis | Reuse the Phase 3 closed-bar context, add time-stamped H4/H1/M15/M5 state history and revision logging. | No open-bar confirmation; no order calls. | Historical replay and revised-data fixtures. |
| Trade Setup Scoring | Explainable rule score with separate structure, liquidity, FVG, execution-cost and risk components. | Score is descriptive, not win probability; RR >=2 and all hard risk gates remain mandatory. | Deterministic fixtures and out-of-sample demo observations. |
| Advanced Position Management | Show candidate break-even, partial-close and trailing-stop plans for existing positions. | Default disabled; any action that modifies or sends an order belongs to a separate execution component and needs explicit user confirmation. No automatic new entries. | Strategy Tester with rejection, slippage, partial fill and disconnect cases before demo use. |
| Trading Journal | Append timestamped plans, state changes and actions with account/symbol/ticket context. | Do not store credentials; distinguish simulated, demo and live sources. | Restart, file failure and duplicate-event tests. |
| Performance Analytics | Summarize realized P/L, costs, drawdown and setup outcomes from broker history. | Clearly label missing deal history and selection bias; no profitability promise. | Reconcile totals against MT5 history on Forex, Gold and index. |
| Risk/Protection Alerts | Show portfolio metrics, protection heartbeat, warning level and stale-data state. | Preserve emergency lock and account-wide close policy; alerts never replace broker stop orders. | Demo disconnect/reconnect, lock and alert deduplication tests. |

Build Phase 4 as read-only modules first. Keep any future order-execution component separate from the dashboard/advisor and require an explicit confirmation workflow. No live-account testing is part of this plan.
