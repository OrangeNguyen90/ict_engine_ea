# Phase 3.7 chart overlays (current scope)

The compiled `Indicators/SmartRiskDashboard.ex5` in this project contains a
compact 560 x 190 pixel right-hand panel. The eye button hides or restores
the panel without removing chart analysis marks. `Compact_Dashboard=false`
restores the longer 560 x 230 pixel readout. The separate left advisory panel is
off by default. Its input `Show_Advisory_Panel` enables it when needed. The
right panel is not intended to cover the price area on a narrow chart; hide
Market Watch/Navigator or enlarge the chart if the terminal window is small.

The indicator now calculates visualization data from completed candles on the
chart independently of the lot/advisory service. It draws the latest available
OB, FVG and midpoint, SMT divergence (when comparison symbols are configured),
premium/discount halves and equilibrium, prior-day BSL/SSL, latest confirmed
same-bar sweep, and latest BOS/MSS marker. The sweep arrow retains the latest
event within 96 closed trigger candles. It checks that candle's PDH/PDL first,
then the high/low of its preceding 10 closed candles. A wick beyond the level
is not enough: the sweep candle must close back inside. Local sweeps and
PDH/PDL sweeps have distinct labels. Inputs `Show_OB_Overlay`,
`Show_SMT_Overlay`, `Show_FVG_Overlay`, `Show_Premium_Discount`,
`Show_Liquidity_Overlay` and `Show_Structure_Overlay` toggle the corresponding
layers. `Analysis_*_Timeframe` inputs select the analysis periods. Set
`Comparison_Symbol_1` and/or `Comparison_Symbol_2` to broker-available symbols
for SMT; they are blank by default. No comparison symbol price is drawn on the
primary chart's price scale.

The old service-published context and ICT overlay layers are off by default to
avoid duplicate markings. `Show_Market_Overlays` (with
`Show_Advisory_Panel`) and
`Show_Service_ICT_Overlays` can enable them for comparison. The indicator's
manual entry, SL and TP drag lines remain available; they are not orders.
If `RiskCalculationService` is not attached to the same chart, lot preview and
trade-ready advisory remain blocked/offline. The visual analysis never makes a
blocked plan trade-ready or changes `RiskProtectionEA`.

MT5 permits one EA per chart. To obtain the service-backed risk preview, place
`RiskCalculationService` and `SmartRiskDashboard` on one chart with matching
`Instance_ID`; put `RiskProtectionEA` on another chart. A standalone
`TradingAdvisoryEA`, if used, needs a third chart. Install the updated
indicator binary from this project into the terminal's Indicators directory
and reload it on the chart; a project-file compilation alone does not replace
the copy already loaded by MT5.

Current boundaries: only one selected OB and FVG plus the latest SMT pair per
comparison are shown. Historical zone collections, configurable FVG fill
thresholds, watch-zone priority, alert lifecycle and replay/visual Strategy
Tester validation are not yet implemented. Labels at pivot/formation bars are
for visual context; they are not claims that a signal was available at that
earlier bar. Use the recorded confirmation time for decision timing.
