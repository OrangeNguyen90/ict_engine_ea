# ICT Smart Trade Decision Engine upgrade — 2026-11-03

## Baseline and implementation plan

Update 2026-11-05: see the [display fix and installation notes](ICT_DISPLAY_FIX_20261105.md) for the US30 stale/future-data panel and the H4 initialization failure. Changing the chart timeframe does not change the configured range timeframes.

IRL/ERL extension: see [current range-engine delivery](IRL_ERL_DELIVERY.md) and [audit/design](IRL_ERL_DESIGN.md). This is the next authorized implementation layer; older evidence below remains historical.

Update 2026-11-04: see the [current delivery and fresh validation](ICT_SMART_DELIVERY_20261104.md) and [module audit](ICT_SMART_AUDIT_20261104.md). TP2 and the additional decision/UI fixes are now implemented; runtime acceptance remains pending. Evidence below records the earlier 2026-11-03 baseline.

This upgrade extends the existing project; it does not replace the Phase 2 protection controller or Phase 3 advisory strategy. The attached specification is the implementation target, not evidence of test success.

| Requirement | Existing baseline | Upgrade work |
| --- | --- | --- |
| HTF/structure | Closed-bar swings and latest-bar BOS/MSS; configurable H4/H1 | Explicit confirmation times; configurable multi-timeframe decision evidence |
| Liquidity | Prior-day levels, equal swings, recent local/daily sweep | Week/session levels and lifecycle evidence |
| FVG | Gap geometry and one touch flag | Partial/full mitigation, invalidation and inversion evidence |
| OB | Detector, state validator, score and renderer | Continue lifecycle after mitigation; no score for inactive blocks |
| SMT | Two manual symbol fields, timestamp-joined returns, swing pairs | Reject stale alignment and weak/wrong-sign measured correlation even in manual mode; confirmation close times |
| Decision | Single selected direction and cumulative fixed score | Independent BUY/SELL scores, three-way decision, separate hard gates and inspectable record |
| UI | Risk dashboard and small standalone Comment view | Dedicated positionable decision panel, component overlays and event alerts |
| Risk | Broker-aware OrderCalcProfit/OrderCalcMargin, RR >= 2, persistent per-position 3% emergency policy | Reuse calculations and policy; require explicit account confirmation for emergency execution |
| Transport | Numeric terminal-global snapshot; 24-character symbol helper also used for reasons | Separate bounded text transport for readable reasons |
| Validation | Prior compile logs and limited historical probes | Fresh compilation, deterministic fixtures and isolated Tester runs where available |

Implementation order: extend shared detectors and validation; add independent scoring and decision evidence; integrate standalone UI and service; compile all consumers; execute fixtures/replays; record observed results and remaining gaps.

## Safety boundaries

- The analysis EA and calculation service do not send trade requests.
- Emergency policy remains **loss on any one position / saved reference capital >= 3%**, followed by the existing account-wide action. This is not an aggregate account drawdown threshold.
- Emergency execution now defaults to disarmed. Both `Enable_Auto_Protection=true` and `Confirm_Protection_Account=<current login>` are required. Disarming preserves an existing lock but withholds close/cancel calls. This is an intentional configuration migration.
- No live-account test or attachment of protection to a chart is part of this upgrade.
- Independent score components are heuristic confluence, not calibrated win probabilities. A score never overrides a hard veto.

## Evidence status

### Fresh build evidence

MetaEditor 5 build 6295 compiled the following with **0 errors and 0 warnings** on 2026-11-03:

- `Experts/ICTDecisionSupportEA.mq5`
- `Experts/RiskCalculationService.mq5`
- `Indicators/SmartRiskDashboard.mq5`
- `Experts/TradingAdvisoryEA.mq5`
- `Experts/RiskProtectionEA.mq5`
- `Tests/ICTDecisionTests.mq5`, `Tests/ICTDetectorTests.mq5`, `Tests/Phase3ProbeEA.mq5`, and `Tests/OBSMTProbeEA.mq5`

The fresh compiler outputs are in `docs/*.compile.log`.

### Executed Tester attempt

An isolated portable terminal was prepared in `Tests/.terminal`: no user terminal configuration, credentials, profile, or account history was copied; every supplied run configuration has `AllowLiveTrading=0` and `Enabled=0`. Both deterministic fixture runs were attempted on 2026-11-03. MT5 stopped them before EA initialization with `tester not started because the account is not specified`. Therefore there is **no runtime PASS claim**, no backtest, and no performance metrics.

The scripts, configurations, and terminal log make this condition reproducible. To execute the tests, provide a tester-only account configuration or run the supplied configurations from an existing demo terminal after verifying the same disabled-trading settings.

### Outstanding validation

- Visual acceptance at multiple chart sizes and broker symbols still needs MT5 screenshots.
- Replay must validate chronological sweep -> MSS -> FVG/OB behavior with real broker history, including missing/unsynchronized SMT data.
- The two targets are represented by the primary DOL target; a separately ranked TP2 remains a documented enhancement.
- No win rate, profit factor, drawdown, expectancy, or trade count is available because no qualifying backtest ran.
