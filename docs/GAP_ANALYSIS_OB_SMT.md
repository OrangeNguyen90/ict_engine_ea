# OB/SMT gap analysis — 2026-11-01

This audit covers the existing MQ5/MQH files, README, Phase 2–4 plans and test evidence. The attached `Tests/ResetProtectionState.log` proves only that the reset script compiles with 0 errors and 0 warnings.

| Area | Existing interface/evidence | Gap and action |
| --- | --- | --- |
| Market structure | `MarketStructure.mqh` returns closed-bar H4/H1 swings, bias and latest BOS/MSS; confirmed swing timestamps are available. | No pivot confirmation time or historical event stream. OB/SMT engines must use closed bars and retain formation versus confirmation times. |
| FVG and liquidity | `FVGDetector.mqh` finds latest confirmed gap and mitigation; `LiquidityDetector.mqh` reads previous closed D1 and latest closed trigger candle. | Neither identifies an OB. Their latest-event outputs can support confluence only when timestamps and direction align. |
| Risk/advisor | `TradeAdvisor.mqh` checks protection health, structure, FVG, sweep, trigger, spread and broker-based risk calculation. RR >= 2 is enforced. | No OB/SMT inputs. Add descriptive confluence without weakening any current hard gate or creating orders. |
| EA-to-indicator transport | `RiskCalculationService.mq5` publishes per-chart numeric Global Variables using `AdviceBridge.mqh`; `SmartRiskDashboard.mq5` reads them with a freshness timestamp. | Add a distinct OB/SMT snapshot with timestamp-last commit, explicit missing-data states and chart-specific keys. Avoid publishing strings through numeric Global Variables. |
| OB | No detector, state validator, scoring or renderer. | Build closed-bar OB candidate/confirmation/state engine and bounded chart rendering. Avoid treating an arbitrary opposing candle as confirmed. |
| SMT | No configured comparison symbols, aligned-return correlation, swing-pair detector or renderer. | Build explicit symbol validation; default comparisons empty. Correlation must join by identical closed-bar timestamps and require >=60 valid pairs. Swing comparison must bound pivot-time gap and confirm using right-side closed bars. |
| Confluence | Existing advisor has strict Phase 3 hard gates but no OB/SMT score. | Produce separate informational recommendation and score. Preserve old TRADE READY gate; never promote an invalid risk setup based on score. |
| Visuals | Dashboard draws current structure, FVG, liquidity and advisory levels. | Add compact OB/SMT readouts and chart objects with unique prefixes. SMT price lines use only the main chart symbol's prices. |
| Acceptance | Nine existing MQ5 programs compiled; Phase 3 A01–A10 and visual acceptance remain open. | OB01–OB10, SMT01–SMT12 and IT01–IT10 need executed evidence. Tester and demo checks must not be marked PASS from compilation. |

The existing protection controller and 3% per-position emergency action remain outside the OB/SMT implementation. The user's currently open MT5 session prevents an isolated CLI Tester run until it is closed or a separate Tester environment is provided.
