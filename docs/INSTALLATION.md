# Installation and use

1. In MT5, open **File → Open Data Folder**, then `MQL5`.
2. Copy the project `Indicators/SmartRiskDashboard.mq5` into `MQL5/Indicators/`.
3. Copy `Experts/RiskCalculationService.mq5` into `MQL5/Experts/`. Optionally copy `Experts/TradingAdvisoryEA.mq5` for a standalone Experts-log advisory.
4. Copy `Experts/RiskProtectionEA.mq5` into `MQL5/Experts/` only after reviewing its account-wide close policy. Copy `Tests/ResetProtectionState.mq5` into `MQL5/Scripts/` if a confirmed reset is needed.
5. Copy every `.mqh` file in the project `Include/` into `MQL5/Include/`.
6. Compile the indicator, calculation service EA, protection EA, and optional reset script in MetaEditor. Their `../Include/` paths resolve from the standard `MQL5/Indicators/`, `MQL5/Experts/`, and `MQL5/Scripts/` folders. If you organize compiled EX5 files in custom Navigator subfolders such as `QH indicators` or `QH support`, copy the compiled EX5 there; the source files in those subfolders need a different relative include layout to compile in place.
7. On a **demo** chart, attach the indicator and **RiskCalculationService EA to the same chart** with matching `Instance_ID`. MT5 permits one EA per chart: `TradingAdvisoryEA` is standalone and does not feed the dashboard, so do not attach it in place of `RiskCalculationService`. The advisor panel also requires the protection controller to be active and healthy. Attach `RiskProtectionEA` to a **different chart** only after reviewing the [risk policy](RISK_POLICY.md); it is account-wide and can close manual positions and positions from other EAs.
8. Click BUY PREVIEW or SELL PREVIEW and drag the white Entry, red SL, and green TP lines. CALCULATE LOT refreshes the result; RESET SETUP uses the current quote.

The calculation EA must be running for a valid preview. `RiskCalculationService offline or pending` is a blocking status. Inspect the Experts log, chart placement, and matching instance IDs if it persists. `NO TRADE` with `Service offline/stale` means the dashboard has not received a recent advisory result. If the service is running but protection is offline or locked, the advisor still returns NO TRADE. On a demo account, Algo Trading must be enabled for the protection EA to send emergency close requests.

The left advisory panel is enabled by `Show_Advisory_Panel`. It uses the calculation service's `Enable_Trading_Advice` setting and updates every five seconds. `TRADE READY` is an experimental advisory, never an automatic trade. See the [advisory rules](ADVISORY_RULES.md).

The standalone TradingAdvisoryEA can draw the latest detected Order Block on its own chart. `Show_Order_Block` controls the overlay, `Order_Block_Timeframe` selects the analysis timeframe (M15 by default), and `Show_Inactive_Order_Block` controls whether candidate, mitigated, invalidated, or expired zones are shown in gray. Green and red indicate confirmed bullish and bearish blocks. No zone is drawn if no block is detected or history is unavailable. The overlay does not feed the dashboard or place trades.

For standalone SMT, enter exact broker symbol names in `SMT_Comparison_1` and optionally `SMT_Comparison_2` (for example, a broker's EURUSD and GBPUSD names). `Show_SMT` enables analysis, `SMT_Timeframe` selects the timeframe, and the correlation settings select automatic, positive or negative relationships. Automatic mode requires at least 60 aligned return pairs and sufficient correlation. Only confirmed divergence is drawn, using the primary symbol's pivot prices; state changes and missing-data reasons appear in Experts. Empty comparisons disable their respective signals. SMT is informational and does not relax the advisory's risk gates.

For Phase 3 recovery, use the newly compiled dashboard and calculation service together. Restart or detach/reattach the indicator and EA after replacing EX5 files so their in-memory copies reload. `Show_Market_Overlays` controls the optional chart objects. Do not interpret visible swing/FVG levels as permission to trade while NO TRADE or WAIT is displayed. The [Phase 3 fix report](PHASE3_FIX_REPORT.md) records which checks remain unverified.

MetaEditor compilation produced `.ex5` files in the project beside each `.mq5` source. The [test report](TEST_REPORT.md) records the completed checks and remaining demo tests.

## Reset after an emergency

The protection lock survives restart. To reset it, first remove the protection EA from all charts, ensure the account has **zero open positions and zero pending orders**, then run `ResetProtectionState.mq5` once from Scripts. Set `Confirm_Account_Login` to the visible account number and `Confirmation_Phrase` to `I CONFIRM RESET SRMP`; explicitly select `Clear_Emergency_Lock` and, only if intended, `Reset_Reference_Capital`. The script refuses a reset while a controller is active. Reattach the protection EA afterward. Merely restarting MT5 never resets the reference or lock.
