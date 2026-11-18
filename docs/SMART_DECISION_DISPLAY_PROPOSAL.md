# Đề xuất điều kiện hiển thị ICT Smart Decision Engine

Trạng thái 2026-11-07: đã triển khai dashboard tổng quan ban đầu và bật lớp ngữ cảnh trong range mode, nhưng **chưa nghiệm thu hiển thị/runtime**. Bảng dưới vẫn là đặc tả đích; không coi mọi hàng là đã hoàn thành. Hai ảnh tham chiếu là mẫu trình bày, không phải dữ liệu kiểm thử hoặc cơ sở để suy ra hiệu quả giao dịch. Áp dụng cho `ICTSmartDecisionEngineEA`; không thay đổi tiêu chí mở lệnh của `ICTAutoTraderEA`.

Dashboard mới có hai thẻ điểm, trạng thái theo hướng, hai symbol SMT và kế hoạch chỉ khi các gate hiện có đạt. Trong range mode điểm hướng đối diện hoặc điểm chưa được engine tính hiện `--`. Khi range bật, các lớp context FVG/OB/PD/thanh khoản vẫn được vẽ, riêng mức range đã sweep/consumed/invalidated được ẩn; các lớp context không đồng nghĩa tín hiệu vào lệnh. Dashboard mặc định bên trái, chiều cao co theo các nhóm hiển thị và nội dung; có thể kéo nền và ẩn/hiện. `Dashboard_Height` là giới hạn chiều cao; nếu giới hạn hoặc chart quá nhỏ để hiển thị tổng quan, bảng chuyển sang dạng phân trang. Dùng `Show_FVG`, `Show_Order_Blocks`, `Show_Premium_Discount`, `Show_Liquidity`, `Show_SMT`, `Show_Structure` và các tùy chọn range để giảm chồng lấn. Nếu MT5 lưu inputs cũ, chọn `Dashboard_Corner=CORNER_LEFT_UPPER` hoặc reset inputs để đổi vị trí mặc định.

### Cấu hình hai SMT trong Smart Decision EA

Trong nhóm Inputs `SMT 1 / 2: manual symbol overrides automatic`, bật `Auto_Suggest_SMT_Symbols` và `SMT_1_Auto` / `SMT_2_Auto` cho từng ô tự động; để trống `Comparison_Symbol_1` / `Comparison_Symbol_2`. Khi nhập tên symbol chính xác của broker, tên nhập tay được ưu tiên cho ô đó, kể cả khi Auto của ô bật. Để tắt một ô, xóa tên thủ công và đặt Auto của ô thành false; công tắc tổng false tắt lựa chọn tự động nhưng vẫn cho phép symbol thủ công. Hai symbol phải khác nhau và khác symbol chart. Chọn đủ symbol ứng viên trong Market Watch: auto chỉ xem các symbol tại đó, yêu cầu tương quan đóng đủ dữ liệu, có thể không tìm được đủ hai cặp. Để vẽ, bật `Show_SMT`; tín hiệu có thể không xuất hiện nếu thiếu dữ liệu, tương quan yếu, pivot chưa xác nhận hoặc các điều kiện phân kỳ không đạt.

Dashboard ghi `AUTO: symbol`, `MANUAL: symbol`, `AUTO: WAIT DATA` hoặc `OFF` cho từng ô; khi dòng bị rút ngắn do kích thước panel, đưa chuột lên dòng để xem đầy đủ. Đổi Inputs là thao tác khởi tạo lại EA trong MT5; ô còn để Auto vẫn được chọn theo symbol chính. Việc có đủ hai symbol chỉ được bảo đảm khi Market Watch có ít nhất hai ứng viên thỏa dữ liệu và ngưỡng tương quan; EA không gán dữ liệu yếu thành tín hiệu hợp lệ.

Đường SMT nối hai đỉnh đối với bearish hoặc hai đáy đối với bullish trên symbol chính; SMT1 nét liền, SMT2 nét đứt. Nhãn ghi symbol đối chiếu, khung và thời điểm xác nhận; vị trí nhãn được dịch nhẹ để tránh chồng chữ, còn đầu mút đường vẫn ở giá pivot. Đối tượng bị xóa nếu tín hiệu không còn đủ điều kiện, thời điểm xác nhận chưa tới hoặc dữ liệu pivot thay đổi. Đối tượng thể hiện tín hiệu đã xác nhận, không có nghĩa là nó đã có thể biết tại thời điểm pivot. Phần này cần kiểm thử visual runtime; không dựa vào ảnh cũ hay thành công biên dịch làm bằng chứng.

Phần tiêu đề dashboard đặt symbol và khung chart trước tên EA để tránh bị cắt; dòng trạng thái ghi khung LTF đang phân tích. Nút hình mắt ẩn/hiện dashboard. Nếu `Show_SMT` và `Show_SMT_Comparison_Legend` cùng bật, góc phải chart ghi symbol chính, khung SMT, hai symbol đối chiếu và trạng thái detector. Legend không thay thế đường SMT: đường chỉ xuất hiện khi điều kiện pivot và phân kỳ được xác nhận. Các nhãn PREMIUM/DISCOUNT và EQH/EQL xuất hiện khi cấu trúc/liquidity cần thiết có dữ liệu; không tạo hình minh họa giả nếu chưa có đối tượng.

`ICTSmartDecisionEngineEA` và `SmartRiskDashboard` dùng chung detector và renderer SMT. Bridge của `RiskCalculationService` hiện cung cấp thêm thời điểm xác nhận pivot; indicator đọc cả trạng thái, số cặp và thời gian xác nhận trước khi vẽ. Cần cập nhật **cả** indicator lẫn service để dùng bridge mới; service cũ không cung cấp đủ trường nên renderer sẽ không vẽ tín hiệu đó. Biên dịch không chứng minh có SMT trên dữ liệu thực.

## 1. Dashboard

| Thành phần | Đề xuất điều kiện hiển thị | Dữ liệu/giới hạn hiện tại |
| --- | --- | --- |
| Đầu trang | Symbol, các khung thực tế, thời gian nến đóng gần nhất, thời điểm cập nhật và trạng thái dữ liệu. Nếu dữ liệu cũ, lỗi hoặc chưa sẵn sàng, hiển thị OFFLINE / STALE / DATA UNAVAILABLE và không trình bày kế hoạch như sẵn sàng. | `SICTDecision.as_of`, cấu hình timeframe và `data_quality`; cần bổ sung hợp đồng độ mới và thời gian nguồn nhất quán. `TimeLocal()` trong renderer hiện là thời điểm vẽ, không chứng minh dữ liệu giá mới. |
| BUY/SELL score | Hai thẻ 0–100 như ảnh; luôn đi kèm PRIORITY hoặc NO TRADE và lý do. Hai điểm vượt ngưỡng đồng thời thì NO TRADE theo chính sách hiện có. Điểm không phải xác suất thắng hay điều kiện đủ. | `buy_score`, `sell_score`, `priority`; ngưỡng, trọng số do cấu hình. |
| Bias matrix | Hiện MN/W/D/HTF/structure theo đúng timeframe cấu hình, theo hướng tăng/giảm hoặc NEUTRAL / UNKNOWN; chỉ hiển thị xung đột khi hàm kiểm tra xung đột xác định. | Các `*_bias`; hiện giá trị 0 không phân biệt được trung tính và thiếu dữ liệu, cần thêm trạng thái chất lượng riêng trước khi tách hai nhãn. |
| Bảng confluence | Mỗi hàng HTF, sweep, MSS, displacement, FVG, OB, premium/discount, SMT, session có cột BUY/SELL và trạng thái CONFIRMED, NOT CONFIRMED hoặc DATA UNAVAILABLE; nêu required/optional. Thiếu bằng chứng không mặc nhiên là dữ liệu lỗi, và không coi optional là lỗi. | `buy_confirmed`, `sell_confirmed`, `required`, `data_quality`; hiện chưa đủ quality flag riêng cho từng hàng nên không được đoán DATA UNAVAILABLE từ bit bằng 0. |
| SMT 1 và 2 | Mỗi dòng tên symbol, nguồn nhập tay/tự đề xuất, tương quan có dấu và số cặp, trạng thái bullish/bearish/không xác nhận/thiếu dữ liệu, timeframe và thời điểm xác nhận; dấu âm không tự động được coi là lỗi. | `SSMTDivergence` và symbol đã chọn; phải chuyển dữ liệu SMT vào snapshot chung và bổ sung nguồn lựa chọn, không suy ra từ điểm. |
| Kế hoạch | Chỉ tô nổi Entry, SL, TP và RR khi snapshot cùng symbol/timeframe còn mới, `state==ICT_ENTRY_READY`, `hard_filters_passed`, `entry_confirmed` và `risk.valid`; RR ròng ít nhất 2 theo cấu hình. Ngược lại hiển thị WAIT / BLOCKED và lý do, không hiển thị số 0 như giá. Kế hoạch lịch sử nếu hiển thị phải ghi rõ HẾT HIỆU LỰC, không là tín hiệu hiện tại. | `SICTDecision` và `SRiskResult`; cần phản hồi rủi ro liên chart gắn với đúng kế hoạch trước khi coi đây là tích hợp hai EA hoàn chỉnh. |
| Rủi ro | Hiện spread theo point, RR ròng, lot, tiền rủi ro, tiền dự kiến thưởng, giá trị tham chiếu và thời gian xác thực; OFFLINE/BLOCKED nếu controller hoặc phản hồi tính toán cũ. Không làm tròn lot lên để vừa ngân sách. | Một số trường đã có trong `risk`; spread, nguồn vốn và tuổi phản hồi cần được đưa vào snapshot dùng chung. |
| Invalidation / lý do | Nêu lý do đang chặn có thể hành động được: thiếu dữ liệu, sweep, MSS, zone, retest, bảo vệ hay rủi ro; phân biệt invalidation giá với lý do chặn. | `reason`, `hard_filter_reason`, `missing_conditions`, `invalidation`; hiện các trạng thái không luôn phân biệt đầy đủ. |
| Range mode | Cùng ngôn ngữ trạng thái nhưng hiển thị thêm range ID/version, phase, scenario, IRL/ERL, zone state và lý do. Không áp dụng nhãn zone thông thường cho snapshot range khác nguồn. | `SICTRangeSnapshot`; cần bảo đảm cùng snapshot cho panel, biểu đồ và indicator. |

## 2. Biểu đồ

| Lớp | Điều kiện và nhãn đề xuất |
| --- | --- |
| Swing / BOS / MSS | Chỉ vẽ sự kiện đã xác nhận theo nến đóng; nhãn gồm loại, timeframe, hướng, mức và thời gian xác nhận. Phân biệt thời điểm nến tạo sự kiện với thời điểm tín hiệu khả dụng; không vẽ vào quá khứ như thể đã biết trước. Không đổi tên MSS thành CHoCH nếu chưa thống nhất định nghĩa trong engine. |
| BSL / SSL, EQH / EQL, sweep | Phân biệt mức thanh khoản và sự kiện quét, nguồn PDH/PDL hoặc swing, mức giá và thời gian xác nhận; mức không còn hợp lệ phải bị xóa hoặc chuyển sang lịch sử mờ. Không gọi mọi lần chạm là sweep. |
| Premium / discount | Vẽ khi có dealing range hợp lệ, hai đầu và midpoint; nêu timeframe, thời điểm bắt đầu và 50%. Nếu range chưa xác nhận, thiếu hoặc bị thay thế thì không duy trì vùng cũ như hiện hành. |
| FVG / OB | Vẽ vùng theo hướng và trạng thái fresh/touched/mitigated/invalidated, timeframe, thời điểm xác nhận. Ẩn vùng không hoạt động theo mặc định; bật lịch sử thì dùng màu mờ và nhãn lịch sử. Overlay ngữ cảnh và vùng được engine chọn cho kế hoạch phải được phân biệt rõ. |
| SMT | Vẽ divergence chỉ khi detector xác nhận, ghi symbol đối chiếu, chiều và timeframe; xóa đối tượng khi dữ liệu thiếu hoặc tín hiệu mất hiệu lực. Không vẽ theo score hoặc tên symbol. |
| Entry / SL / TP / DOL | DOL ngữ cảnh có thể hiển thị riêng; vùng ứng viên dùng nét đứt và nhãn CANDIDATE. Entry/SL/TP được xác nhận chỉ xuất hiện khi cùng bộ điều kiện plan trong bảng dashboard đạt, và phải được xóa ngay khi dữ liệu stale hoặc kế hoạch bị chặn/vô hiệu. |
| Scenario | Chỉ cho phép đường projection là minh họa có nhãn SCENARIO / NOT FORECAST, kèm điều kiện xác nhận và vô hiệu. Không dùng để suy ra target bảo đảm. |

Màu sắc theo ảnh có thể dùng xanh cho bullish và đỏ cho bearish, nhưng luôn kèm chữ và loại đường để không phụ thuộc màu. Giới hạn số vùng trên màn hình; cho phép bật/tắt nhóm, ẩn dashboard, kéo và phân trang trên MT5.

## 3. Thứ tự thực hiện và kiểm thử

1. Hoàn thiện một snapshot có version, nguồn, thời gian nến đóng, trạng thái sẵn có từng trường và phản hồi risk gắn cùng plan; đọc ghi fail-closed khi thiếu hoặc cũ.
2. Tạo dashboard theo mẫu bằng chính snapshot đó; hai score, priority, bảng bằng chứng và kế hoạch không tính lại độc lập trong renderer.
3. Nối overlay vào cùng ID setup/range, phân biệt context với plan; xóa object khi thay symbol, timeframe, dữ liệu hoặc EA dừng.
4. Kiểm thử fixture trạng thái thiếu/mâu thuẫn, hai chiều cùng vượt ngưỡng, risk fail, stale, symbol/timeframe thay đổi, không có SMT và range invalidation; replay theo nến đóng, kiểm tra look-ahead/repaint và nhất quán indicator/EA.
5. Chạy visual tester với dữ liệu broker và kiểm tra kích thước chart/DPI, tràn chữ, kéo/ẩn/hiện; ghi ảnh và journal làm bằng chứng. Compile không đủ chứng minh hiển thị thực.
