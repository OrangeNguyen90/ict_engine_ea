# Smart Decision EA — tự đặt SL/TP theo kế hoạch

Đây là chức năng thử nghiệm của `ICTSmartDecisionEngineEA`, độc lập với `ICTAutoTraderEA`. EA không tự mở lệnh trong chức năng này. **Mặc định `Auto_SLTP_Enable=false`; chưa có bằng chứng kiểm thử runtime hay nghiệm thu broker.**

## Phạm vi

Khi được bật, EA theo dõi các deal vào mới nhận được trong lúc EA chạy, trên **cùng symbol với chart**, gồm lệnh tay và lệnh từ EA. EA dùng đúng SL/TP của kế hoạch Smart Decision đã ở trạng thái ENTRY READY, có dữ liệu và rủi ro hợp lệ trước thời điểm khớp. Nếu vị thế đã có SL hoặc TP, EA giữ nguyên cả hai và không bổ sung giá còn thiếu. Không quét hoặc sửa vị thế cũ khi khởi động lại.

Chức năng chủ động bỏ qua các trường hợp không thể xác định an toàn kế hoạch/position: không có kế hoạch hợp lệ trước khi khớp, giá hoặc chiều khớp không phù hợp, dữ liệu cũ, lệnh gộp netting hoặc nhiều deal/partial fill, kế hoạch đổi SL/TP trước khi xử lý, không có dữ liệu lịch sử vị thế, hoặc không còn vị thế. Do thời gian MT5 dùng ở đây có độ phân giải giây, kế hoạch phải được quan sát ở **giây trước** giây khớp; bằng giây bị bỏ qua. Sau khi gửi yêu cầu EA ghi nhận lần thử trước khi gửi và không tự gửi lại, kể cả broker từ chối hay kết quả chưa rõ. Theo dõi Journal để biết kết quả; không giả định lệnh đã được bảo vệ chỉ vì chức năng đã bật.

## Điều kiện và cấu hình

1. Kiểm thử trên demo trước; gắn EA vào chart symbol cần theo dõi. Bật `Auto_SLTP_Enable`, bật quyền Algo Trading và bảo đảm EA bảo vệ riêng có heartbeat NORMAL, bật bảo vệ và reference hợp lệ. Nếu chạy tài khoản thật, còn cần `Auto_SLTP_Allow_Real_Account=true` và `Auto_SLTP_Confirm_Real_Account` trùng login.
2. Kế hoạch hiển thị phải cùng hướng, có SL/TP hợp lệ; giá mở thực không lệch giá Entry quá `Auto_SLTP_Max_Entry_Deviation_Points` (mặc định 50 points). EA kiểm tra tuổi kế hoạch, tuổi vị thế, tuổi quote, tick size và khoảng cách stop/freeze thực tế. Không tự dịch SL/TP để vượt kiểm tra.
3. EA định giá P/L bằng `OrderCalcProfit` với **khối lượng thực của vị thế**, chi phí và trượt giá dự phòng đã cấu hình; rủi ro ước tính không vượt `Maximum_Risk_Per_Trade` so với vốn reference của bộ bảo vệ và RR ròng tối thiểu `Minimum_RR` (không dưới 2). Giá khớp, phí và trượt giá thực tế có thể khác ước tính.
4. Không chạy hai bản Smart Decision cùng bật tự đặt SL/TP cho cùng account/symbol. Khóa file giới hạn một instance Smart Decision; nó không ngăn EA khác hoặc người dùng cùng sửa vị thế, và không bảo đảm thao tác nguyên tử với broker.

`Auto_SLTP_Max_Plan_Age_Seconds` mặc định 15; `Auto_SLTP_Max_Position_Age_Seconds` 120; `Auto_SLTP_Max_Quote_Age_Seconds` 10. Lý do bỏ qua hoặc phản hồi server được ghi với tiền tố `Smart SLTP:` trong Experts/Journal. Đổi hoặc xóa SL/TP thủ công sau lần gửi không khiến EA tự áp lại.

## Kiểm thử còn thiếu

Cần chạy Strategy Tester và demo với lệnh tay/EA, BUY/SELL, từng trạng thái đã có SL/TP, giá lệch, stale, invalidation, broker từ chối, restart, mất kết nối, đồng thời nhiều EA, partial fill và hedging/netting. Bài kiểm thử thuần chỉ kiểm tra điều kiện; compile không xác nhận lệnh sửa được gửi hay broker chấp nhận.
