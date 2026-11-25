# Phase 1 configuration

Set these in the indicator Inputs. The EA input `Instance_ID` must match.

| Input | Default | Meaning |
| --- | ---: | --- |
| `Risk_Per_Trade` | 0.25 | Target percent of preview capital. |
| `Max_Risk_Per_Trade` | 3.0 | Per-trade ceiling required by the user. |
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
| `Enable_Auto_Protection` | false | Explicit opt-in. Disarming retains the lock but withholds further close requests. |
| `Confirm_Protection_Account` | 0 | Correct account login required together with enabling protection for account-wide closing. |
| `Enable_New_Trade_Execution` | false | Must remain false; the EA rejects true. |
| `Enable_Trade_Lock` | true | Must remain true; the EA rejects false. |
| `Exit_Cost_Buffer_Per_Lot` | 10 | Reserve for exit costs in account currency. |
| `Missing_History_Buffer_Per_Lot` | 10 | Additional reserve when deal-cost history is unavailable. |
| `Max_Close_Attempts_Per_Ticket` | 5 | Maximum attempts per ticket in one EA session. |
| `Retry_Delay_Seconds` | 3 | Base delay; later attempts use exponential backoff. |
| `Close_Deviation_Points` | 50 | Requested close-price deviation. |

`Enable_Alerts` defaults on. Sound and push notifications are separately opt-in. Only one EA instance holds the account controller file; other chart instances wait passively and can take over if the controller stops.

## Hai EA quyết định 1.11: trần 3%/6%, một trang rủi ro

Áp dụng cho ICTDecisionSupportEA và ICTSmartDecisionEngineEA. Nạp [preset](ICT_LIVE_CONSERVATIVE.set) hoặc sửa Inputs; chart cũ không tự đổi theo mặc định mới. Đọc [nghiên cứu và giới hạn](RISK_POLICY.md) trước khi dùng trên tài khoản thật.

| Input | Mặc định | Ý nghĩa |
| --- | ---: | --- |
| `Risk_Per_Trade` | 0.25 | Target/lệnh; có thể tăng trong trần 3% |
| `Maximum_Risk_Per_Trade` | 3.0 | Trần/lệnh; lớn hơn 3% bị từ chối |
| `Portfolio_Risk_Limit_Percent` | 3.0 | Ngân sách đồng thời cho entry-SL và phần giảm thêm từ Equity, gồm pending/new SL; 0 tắt ngưỡng này |
| `Daily_Loss_Limit_Percent` | 6.0 | Lỗ ngày tối đa, dự phòng new SL; phải >0 và <=6% |
| `Daily_Risk_Budget_Enable` | true | Cộng dồn risk SL ban đầu của deal mở hôm nay, kể cả đã chốt lời; giới hạn theo cùng budget ngày |
| `Maximum_Quote_Age_Seconds` | 10 | Tuổi quote tối đa |
| `Position_Risk_All_Symbols` | true | Toàn tài khoản, gồm thủ công / EA khác / pending |
| `Position_Risk_Capital` | `ICT_POSITION_CONSERVATIVE` (2) | % theo `min(Balance, Equity)`; Balance=0, Equity=1 vẫn được hỗ trợ |
| `Position_Risk_Corner` | `CORNER_RIGHT_UPPER` | Góc bảng |
| `Position_Risk_X` / `Position_Risk_Y` | 12 / 60 | Khoảng cách tới góc chart, px |
| `Position_Risk_Width` / `Position_Risk_Height` | 420 / 420 | Chiều rộng / chiều cao tối đa, px |

12 dòng tóm tắt, không nút đổi trang. Dùng `Dashboard_Font_Size`, tự giảm nếu cần; cửa sổ quá thấp hiện số mục giữ lại và ưu tiên trạng thái/P&L/rủi ro. Chi tiết TP/RR và từng vé ở tooltip. Màu đỏ: lỗi/âm/thiếu dữ liệu; vàng: cảnh báo; xanh: lời hoặc bảo vệ đang giám sát.

Mẫu số của bảng có thể chọn khác với vốn tính lot: lot dùng `min(reference bảo vệ, Balance, Equity)`. Các gate không tự đóng lệnh hiện tại và không ngăn EA khác/người dùng gửi lệnh trực tiếp. Gate lỗ ngày chưa phải drawdown từ Equity lúc 00:00; chốt risk cộng dồn cần history SL gốc hợp lệ.

Calculation service dùng `Decision_Daily_Loss_Limit_Percent=6.0`, `Decision_Daily_Risk_Budget_Enable=true`, `Decision_Portfolio_Risk_Limit_Percent=3.0` cho nhánh ICT decision. Preview planner/advisory cũ vẫn là ước lượng từng kế hoạch, không phải xác nhận mọi gate ngày đã qua.

## Auto Trader 1.31

| Input | Mặc định | Ý nghĩa |
| --- | ---: | --- |
| `Risk_Percent` / `Max_Risk_Percent` | 0.25 / 3.0 | Target / trần mỗi lệnh |
| `Daily_Loss_Limit_Percent` | 6.0 | Gate lỗ ngày, gồm new SL |
| `Daily_Risk_Budget_Enable` | true | Không hoàn lại ngân sách risk ngày sau lệnh thắng |
| `Portfolio_Risk_Limit_Percent` | 3.0 | Tổng risk SL đồng thời |
| `Maximum_Margin_Usage_Percent` | 20.0 | Margin/Equity dự kiến theo `OrderCheck`; 0 tắt |
| `Enable_Auto_Entry` | false | Phải bật riêng để gửi lệnh |
| `Allow_Real_Account` / `Confirm_Real_Account` | false / 0 | Hai điều kiện riêng để cho phép tài khoản thật |

Auto Trader giữ điều kiện không có vị thế hoặc pending khác trên tài khoản; kiểm tra lại ngân sách và quyền trước gửi. Không bật quyền giao dịch chỉ để thử bố cục.

## Phase 3 advisory

`Show_Advisory_Panel=true` displays the experimental left panel. `Enable_Trading_Advice=true` in the calculation service computes it from H4/H1/M15/M5 by default. `Max_Advice_Spread_Points=50` is a hard spread gate in points; calibrate it for each broker symbol. The advisor uses the indicator's risk target and cost estimates. The standalone `TradingAdvisoryEA` has matching risk, spread, timeframe, and cost inputs, and writes to the Experts log only. Neither advisor opens or modifies trades. Review the [exact rules](ADVISORY_RULES.md).

`Show_Market_Overlays=true` draws non-draggable confirmed swing levels, BOS/MSS and sweep markers, FVG, PDH/PDL and equilibrium. Advisory Entry/SL/TP lines appear only while TRADE READY and protection remains healthy. The context panel can show closed-bar market structure while the trade status is NO TRADE. Historical data revisions are logged by the calculation service; chart annotations need replay validation before acceptance.
