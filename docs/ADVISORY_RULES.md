# Phase 3 advisory rules (experimental)

The advisor produces NO TRADE, WAIT, or TRADE READY. It does not send orders. TRADE READY means the deterministic rules below and the broker-based risk calculation passed at the last refresh. It is not a probability estimate or a claim of profitability. The dashboard refreshes the analysis about every five seconds and treats an update older than ten seconds as offline. A separate context snapshot can display confirmed market structure while the recommendation remains NO TRADE.

## Data and setup

1. A recommendation requires protection heartbeat no older than three seconds, `NORMAL` state, explicit zero health errors and a saved reference capital. Disconnection or invalid data yields NO TRADE. Market-context display alone does not imply this gate passed.
2. H4 and H1 use the most recent 120 **closed** candles. A swing high or low requires two candles on each side with strictly lower highs or higher lows. The two latest swing highs and lows determine HH/HL bullish or LH/LL bearish bias. H4 and H1 biases must agree.
3. The latest closed H1 candle must cross the most recent confirmed swing high or low in the bias direction (BOS). An opposite break is marked as MSS context but does not qualify.
4. ATR(14) reads the last closed H1 value. M15 searches 80 closed candles for a three-candle fair value gap at least 5% of H1 ATR wide. A later closed M15 candle touching the gap marks it mitigated; the newest unmitigated gap has priority. Bullish gaps must have their midpoint at or below the midpoint of the recent H1 swing range (discount); bearish gaps must be at or above it (premium).
5. The latest closed M5 candle must sweep the **previous completed daily candle** low and close back above it for a buy, or sweep its high and close back below it for a sell. It must also close above the preceding M5 high for a buy or below the preceding M5 low for a sell. The analysis records equal H1 swing highs/lows when their difference is at most 10% of H1 ATR; equality is context, not a trigger.
6. The current Ask for buys or Bid for sells must be inside the M15 gap. The current spread must be at most `Max_Advice_Spread_Points`. The stop is one tick beyond the sweep extreme or the gap boundary, whichever is farther. The target is the recent H1 swing or prior-day extreme. Prices are rounded to broker tick size.
7. `CalculateRisk()` checks quote age, symbol specification, stop distance, lot step, maximum risk, estimated net reward/risk, and margin. The advisor also requires target risk and maximum risk no greater than 2%, and minimum RR at least 2. If any gate fails, the result is NO TRADE. Estimated costs use the configured commission, buffer, and stop slippage. Actual fills and fees can differ.

These definitions are a narrow interpretation of ICT/SMC terminology. Timeframes are configurable, but the prior-day level remains D1. A setup can disappear as quotes, protection status, or closed candles change. The signal is not persistent advice to enter later. Confirmed BOS/sweep markers use their candle timestamp during a chart session. The service logs a revision when a same-time H1 swing or FVG price changes after a broker history update. Full historical reload stability is still unverified.

## Validation status

MetaEditor compilation has passed. Historical signal behavior, visual alignment, broker symbol variations, and forward outcomes have not been verified. Use the [test report](TEST_REPORT.md) before treating an advisory as operational.
