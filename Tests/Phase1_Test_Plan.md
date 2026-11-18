# Phase 1 verification plan

Run these tests in MetaEditor and an MT5 **demo** account. Record the terminal build, broker, account currency, symbol specification, inputs, screenshots or journal output, and actual result for each case. Do not mark a case passed without executing it.

| Case | Procedure | Expected result |
| --- | --- | --- |
| Compile | Compile `SmartRiskDashboard.mq5` and `RiskCalculationService.mq5` in MetaEditor. | Zero errors. |
| Calculation service | Attach the indicator alone, then attach the EA on the same chart with matching `Instance_ID`. | BLOCKED without the EA; numeric preview appears after the EA responds. No trade request. |
| EURUSD example | On a 5-digit EURUSD symbol, set BUY Entry 1.10000, SL 1.09800, TP 1.10400 with commission, cost buffer, and slippage all zero for this arithmetic check. | 20 pip stop, 40 pip target, RR 1:2; broker-dependent lot. Restore conservative cost inputs afterward. |
| RR gate | Set TP closer so gross reward is less than twice risk. | BLOCKED with `RR below minimum`. |
| Minimum lot | Reduce reference capital or risk percent until the minimum lot exceeds budget. | BLOCKED; no rounding up. |
| Volume step/max | Increase risk budget; inspect a symbol with nonstandard min/step/max. | Lot on broker step and never above max. |
| Tick grid | Drag a line between valid ticks on a futures/CFD symbol. | BLOCKED with tick grid reason. |
| Stop/freeze | Move SL or TP inside the broker minimum distance. | BLOCKED. |
| Invalid side | Move BUY SL above Entry, or SELL TP above Entry. | BLOCKED. |
| Missing quote | Disconnect demo terminal or use an unavailable symbol. | Calculation blocked; no trade action. |
| Stale service | Remove the calculation EA while leaving the indicator attached. | Within seconds, calculation status returns to BLOCKED. |
| Margin | Use a setup whose risk-sized volume requires more than free margin. | BLOCKED with insufficient margin. |
| Estimated costs | Change commission, cost buffer, and slippage Inputs. | Risk/lot/RR respond conservatively; displayed cost estimate changes. |
| Multi-asset | Repeat on XAUUSD and one index CFD. | Cash amounts in account currency; points/ticks displayed. |
| Chart interaction | Drag each line; click BUY PREVIEW, SELL PREVIEW, CALCULATE LOT, RESET SETUP. | Values refresh; no order or position change. |
| Different account types | Attach on netting and hedging demo accounts. | Same preview behavior; no position action. |
| Restart | Close and restart MT5, reattach indicator. | New preview initializes; no claim of persistent protection. |

The V2 cases TC01–TC07 and TC14–TC20 (3% protection, trade-server rejection, retries, trade lock, pending-order cancellation, persistent baseline, and account-wide close) apply to Phase 2 and cannot pass with Phase 1 alone. TC08–TC13 correspond to the multi-asset, RR, and minimum-lot cases above.
