# Phase 1 configuration

Set these in the indicator Inputs. The EA input `Instance_ID` must match.

| Input | Default | Meaning |
| --- | ---: | --- |
| `Risk_Per_Trade` | 1.0 | Target percent of preview capital. |
| `Max_Risk_Per_Trade` | 2.0 | Maximum permitted target percent. |
| `Minimum_RR` | 2.0 | Minimum net estimated reward/risk; values below 2.0 are rejected. |
| `Preferred_Risk_Reward` | 3.0 | Initial planned target-distance ratio; net RR may be lower after costs. |
| `Default_Stop_Points` | 200 | Initial planned stop distance. |
| `Commission_Round_Turn_Per_Lot` | 0 | Broker-specific known commission in account currency. |
| `Unspecified_Cost_Buffer_Per_Lot` | 10 | Extra cost reserve in account currency. |
| `Estimated_Slippage_Points` | 2 | Adverse stop slippage estimate. |
| `Max_Quote_Age_Seconds` | 60 | Quote freshness gate. |
| `Use_Equity_As_Reference` | false | Use current equity instead of current balance for planning only. |

Do not interpret the provisional preview capital as the emergency-protection baseline. The protection EA maintains a separate persistent initial-balance reference tied to account login and server.

## Phase 2 protection EA

| Input | Default | Meaning |
| --- | ---: | --- |
| `Emergency_Loss_Per_Position` | 3.0 | Per-position loss percent trigger. |
| `Protection_Scope` | `ALL_ACCOUNT_POSITIONS` | Includes manual and other-EA positions. |
| `Emergency_Action` | `CLOSE_ALL_POSITIONS` | Cancels all pending orders, then closes all positions. |
| `Reference_Capital_Mode` | `INITIAL_BALANCE` | Account balance saved on first activation. |
| `Enable_Auto_Protection` | true | Enables the initial trigger. A previously latched emergency continues even if this is later set false. |
| `Enable_New_Trade_Execution` | false | Must remain false; the EA rejects true. |
| `Enable_Trade_Lock` | true | Must remain true; the EA rejects false. |
| `Exit_Cost_Buffer_Per_Lot` | 10 | Reserve for exit costs in account currency. |
| `Missing_History_Buffer_Per_Lot` | 10 | Additional reserve when deal-cost history is unavailable. |
| `Max_Close_Attempts_Per_Ticket` | 5 | Maximum attempts per ticket in one EA session. |
| `Retry_Delay_Seconds` | 3 | Base delay; later attempts use exponential backoff. |
| `Close_Deviation_Points` | 50 | Requested close-price deviation. |

`Enable_Alerts` defaults on. Sound and push notifications are separately opt-in. Only one EA instance holds the account controller file; other chart instances wait passively and can take over if the controller stops.

## Phase 3 advisory

`Show_Advisory_Panel=true` displays the experimental left panel. `Enable_Trading_Advice=true` in the calculation service computes it from H4/H1/M15/M5 by default. `Max_Advice_Spread_Points=50` is a hard spread gate in points; calibrate it for each broker symbol. The advisor uses the indicator's risk target and cost estimates. The standalone `TradingAdvisoryEA` has matching risk, spread, timeframe, and cost inputs, and writes to the Experts log only. Neither advisor opens or modifies trades. Review the [exact rules](ADVISORY_RULES.md).

`Show_Market_Overlays=true` draws non-draggable confirmed swing levels, BOS/MSS and sweep markers, FVG, PDH/PDL and equilibrium. Advisory Entry/SL/TP lines appear only while TRADE READY and protection remains healthy. The context panel can show closed-bar market structure while the trade status is NO TRADE. Historical data revisions are logged by the calculation service; chart annotations need replay validation before acceptance.
