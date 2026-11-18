# ICT decision support delivery — 2026-11-02

## Delivered source

- `Experts/ICTDecisionSupportEA.mq5`: read-only standalone chart EA. It displays decision state, evidence times, provisional score, DOL, FVG consequent encroachment, Entry/SL/TP, estimated RR and cash risk, current New York session and account position counts; creates a bounded set of chart lines; logs state changes to Experts. It has no `CTrade`, `OrderSend`, position modification, or close call.
- `Include/ICTDecisionEngine.mqh`: closed-bar data sanity checks, informational Monthly/Weekly/Daily bias plus H4/H1 structural context, recent liquidity sweep, post-sweep MSS, post-MSS FVG, displacement check, premium/discount, prior-day/week/month and swing target selection, FVG retest, risk/protection vetoes, state classification. It reuses the existing detectors and broker-aware risk calculator.
- `Include/ICTSessionManager.mqh`: computes the current New York clock and US Eastern DST boundaries for session context. Historical broker offset and holidays are not inferred.
- `RiskCalculationService` now publishes the new decision state, score, DOL, evidence times, prices, estimated risk and a short reason. `SmartRiskDashboard` displays the decision below its existing advisory and market context, with a fresh protection check before showing `ENTRY READY`. The standalone EA remains an optional separate view.
- Existing OB and SMT components were copied from the source project and retained. The new engine reads protection state and uses SMT only as optional confluence.
- `RiskProtectionEA` now publishes whether automatic protection is enabled. The existing advisor, dashboard and new decision engine require this flag before treating protection as ready.

## Installation and configuration

Compile the dashboard indicator, `RiskCalculationService`, `RiskProtectionEA` and optionally `ICTDecisionSupportEA` in MetaEditor. Keep the dashboard and calculation service on one chart and protection on another. The dashboard's `Show_Advisory_Panel` and service's `Enable_ICT_Decision` inputs display the new state. The standalone decision EA may be attached to a **third chart** for its own chart lines. MT5 permits one EA per chart. A healthy, unlocked and enabled protection controller with saved reference capital is required before either path can show `ENTRY READY`. Default risk is 1% with a 2% cap and RR at least 2. A missing comparison symbol simply removes optional SMT points; enter the broker's actual symbol names.

| Input group | Key defaults | Meaning |
| --- | --- | --- |
| Context | H4, H1, M15, M5 | Higher, structure, setup, trigger timeframes. |
| Structure | 120 bars, swing strength 2 | Closed-bar pivot sensitivity. |
| Setup | 48 bars max age, body >= 1 ATR and >= 60% of range, FVG >= 0.05 ATR | Conservative, experimental event filters. |
| Costs and risk | 50 spread points, 1% risk, 2% cap, RR 2, 2 slippage points, 10 account-currency units per lot buffer; daily loss gate disabled by default | Risk calculator inputs; adjust to actual broker. The optional daily gate uses current broker-day realized deal net plus open floating P/L against saved reference capital. |
| SMT | Optional two comparisons, H1 | Correlation and divergence are confluence, never mandatory entry conditions. |
| Display | Chart levels and Experts logging enabled | DOL/sweep lines and ready-only entry/stop/target lines. |

## Verification evidence

MetaEditor64 compilation of `ICTDecisionSupportEA`, `RiskProtectionEA`, `RiskCalculationService`, `TradingAdvisoryEA` and `SmartRiskDashboard` completed with **0 errors and 0 warnings** on 2026-11-02. Their logs are `docs/<program>.compile.log`. This is a syntax/build check only. No new Strategy Tester, demo, broker-specific, historical replay, or live test was run, following the user's request to test later. Existing source-project test reports describe earlier limited fixtures and do not validate the new engine.

## Incomplete and unverified requirements

- Original ICT lectures and exact citation timestamps remain unverified. All coded thresholds are local engineering hypotheses.
- Monthly/weekly/daily biases are displayed but not yet fused into a weighted HTF decision. Session high/low DOL, AMD, full PD-array types (breaker/mitigation/rejection/BPR), and historical event persistence are not implemented in the new decision EA. Current New York kill zones use the UTC clock and DST calculation; historical broker offsets and holidays need validation.
- The proposed eight-state vocabulary exists, but `TRADE ACTIVE` uses a conservative match on symbol, direction, entry zone and stop; it is not linked to a strategy-owned ticket. No automatic trade execution is implemented.
- The score covers the implemented components, optional SMT and current New York kill zone. Several PD-array components are not scored; `score/100` is descriptive and uncalibrated, with a current READY maximum below 100.
- The standalone EA shows account position counts, estimated stop exposure in account currency, positions with unknown stop risk and positions aligned with the proposed direction under measured cross-symbol correlation. These are warnings, not automatic risk limits; the stop estimate omits future slippage and fees. The optional daily loss gate blocks a new READY result at a configured percentage of saved reference capital, or when account history cannot be read. The dashboard bridge publishes portfolio numbers but does not yet render them. Existing 3% emergency protection remains independent.
- The dashboard shows the decision summary and short reason. The standalone EA uses chart `Comment` and HLINE objects on its own chart; it cannot share that chart with `RiskCalculationService`. The dashboard does not yet draw the new engine's full event history.
- The current MSS rule requires an H1 opposite-structure break confirmed after the trigger-frame sweep closes, and the selected FVG must be confirmed after that MSS closes. This sequence may be rare or miss valid discretionary setups; no signal-frequency evidence is available.
- No backtest outcome, win rate, drawdown, false-positive rate, score calibration, or trading performance claim is available.

## Deferred validation plan

1. Run the prior Phase 3 A01–A10 acceptance cases and broker checks on EURUSD, XAUUSD and the broker's index symbol.
2. Compile all copied MQ5 programs under the user's MT5 build; inspect warnings and visual chart state.
3. Replay timestamped closed bars to verify no look-ahead, missing/duplicate data rejection, sweep → MSS → FVG ordering and expiry.
4. Exercise protection offline/lock, spread, stop-distance, lot, margin and RR vetoes in Tester/demo. Verify no new order is sent by the decision EA.
5. Run separate in-sample, walk-forward and out-of-sample tests with real broker history, spreads, costs and slippage. Report sample sizes and score-bucket calibration. Do not infer live profitability.

Operational and research acceptance remain **pending** until this evidence is recorded.
