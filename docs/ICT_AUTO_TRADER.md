# EA giao dịch tự động ICT — bản thử nghiệm

Chức năng tự đặt SL/TP theo đường đề xuất của **Smart Decision EA** được mô tả riêng tại [SMART_DECISION_SLTP.md](SMART_DECISION_SLTP.md); chức năng đó không phải lệnh mở tự động của ICTAutoTraderEA.

> **Phiên bản thử nghiệm 1.30:** theo yêu cầu mới, khôi phục khả năng tự mở lệnh của 1.10; mặc định `Enable_Auto_Entry=false`. EA nới một điều kiện của advisor cũ: mặc định `Require_Latest_H1_BOS=false` không đòi BOS trên nến H1 đóng gần nhất; đặt `true` để dùng lại bộ lọc đó. Sau khi advisor đạt TRADE READY, EA yêu cầu chất lượng dữ liệu và điểm bằng chứng cùng hướng từ detector/chấm điểm DecisionSupport, mặc định `Minimum_Decision_Evidence_Score=50`. Điểm này không tương đương trạng thái ENTRY READY đầy đủ của ICTDecisionSupportEA. Các điều kiện ICT khác và kiểm tra rủi ro vẫn hoạt động. Chưa có backtest runtime cho 1.30, chưa chứng minh có lệnh mỗi 24–48 giờ và không thể bảo đảm tần suất này. File EX5 đã cài trong MT5 không tự cập nhật. [Kiến trúc đích](ICT_ARCHITECTURE.md), [feature matrix](FEATURE_MATRIX.md).

`Experts/ICTAutoTraderEA.mq5` mở lệnh thị trường khi bộ `SRMPAnalyzeAdvice` đạt TRADE READY. Bộ quy tắc này tương ứng điều kiện tư vấn trong dự án `indicator_support_mt5`: xu hướng H4/H1 đồng thuận, H1 BOS, FVG M15 chưa bị chạm và ở premium/discount phù hợp, M5 quét đỉnh/đáy ngày trước và đóng nến xác nhận, giá nằm trong FVG. Khung thời gian có thể cấu hình; mức ngày trước vẫn dùng D1. Chi tiết tại `docs/ADVISORY_RULES.md`. Không phải mọi đối tượng vẽ trên indicator đều là điều kiện vào lệnh; Order Block, SMT, IRL/ERL, điểm confluence và đường kế hoạch SL/TP không phải bộ lọc bổ sung trong EA này.

EA tính SL/TP từ setup, gửi chúng cùng lệnh mở, dùng `CalculateRisk` để tính khối lượng theo vốn tham chiếu đã lưu của bộ bảo vệ, chi phí dự kiến, trượt giá dự phòng, RR ròng, bước lot và margin. Mặc định rủi ro 1%, giới hạn tối đa 2%, RR tối thiểu 2. Bộ bảo vệ tài khoản `Experts/RiskProtectionEA.mq5` phải chạy riêng, bật tự bảo vệ và có heartbeat NORMAL, không lỗi trong ba giây gần nhất; EA không vào lệnh nếu thiếu các điều kiện này. Kiểm tra có thêm độ lệch giá dự phòng, nhưng giá khớp thực tế, spread, phí, gap và trượt giá có thể làm lỗ vượt mức dự tính; các cách khớp lệnh khác nhau có thể không đảm bảo giới hạn deviation.

## Strategy Tester: không có tín hiệu / không giao dịch

Bản 1.00 dừng trước khi phân tích nếu không có heartbeat của `RiskProtectionEA`. Strategy Tester chạy một EA trong agent riêng; bộ bảo vệ gắn trên chart terminal không cung cấp heartbeat cho lần test. Các nhánh thoát cũ không ghi lý do, và `Enable_Auto_Entry=false` còn ngăn cả việc phân tích. Đây là các nguyên nhân xác định được từ mã nguồn; chưa có journal lần test của người dùng để xác nhận các bộ lọc thị trường tiếp theo.

Từ bản 1.10, chạy Tester như sau:

1. Biên dịch lại `Experts/ICTAutoTraderEA.mq5` và chọn đúng EA vừa biên dịch trong Tester.
2. Đặt `Tester_Simulated_Protection=true` (mặc định). Chế độ này chỉ có hiệu lực khi `MQL_TESTER` bật: dùng balance đầu lần test làm vốn tham chiếu, không cần heartbeat, không ghi global bảo vệ giả. **Không mô phỏng cơ chế đóng khẩn cấp/khóa tài khoản của RiskProtectionEA**; chỉ kiểm thử chiến lược vào lệnh với SL/TP và các bộ lọc rủi ro hiện có. Khi chạy ngoài Tester vẫn bắt buộc bộ bảo vệ riêng.
3. Đặt `Enable_Auto_Entry=true` nếu muốn Tester gửi lệnh mô phỏng. Mặc định vẫn `false`; trạng thái phân tích vẫn hiển thị khi tắt tự vào lệnh. Đặt `Enable_Diagnostics=true` để xem lý do trong Journal và trên chart Visual.
4. Ưu tiên mô hình **Every tick based on real ticks**, chọn symbol chính xác của broker, đủ lịch sử H4/H1/M15/M5/D1 và khoảng test đủ dài. Bản sửa phân tích theo tick trong Tester; ngoài Tester vẫn theo timer hai giây. Không đọc/ghi tệp tín hiệu đã gửi giữa các lần test; chống gửi trùng trong cùng lần test vẫn hoạt động.
5. Kiểm tra lý do `NO TRADE`, `WAIT`, `BLOCKED`. Chưa đồng thuận H4/H1, chưa có BOS H1, FVG không hợp lệ, chưa quét PDH/PDL, chưa xác nhận M5, spread hoặc RR đều có thể khiến không có lệnh. `Max_Spread_Points=30` tính bằng **point của symbol**, không phải pip hay đơn vị giá; cần đối chiếu thông số broker. Không nới điều kiện ICT chỉ để tạo lệnh.

Journal được giới hạn tối đa một thông báo trạng thái mỗi phút thời gian mô phỏng và nhắc lại trạng thái không đổi sau năm phút; chart cập nhật trạng thái mỗi lần đánh giá. Tab Results/Graph không phải nơi hiển thị tín hiệu WAIT; EA hiện hiển thị trạng thái dạng chữ, không vẽ mũi tên tín hiệu.

Kiểm tra ngày 2026-11-06: EA và `Tests/ICTAutoTraderTesterTests.mq5` biên dịch 0 lỗi, 0 cảnh báo. Có bài hồi quy kiểm tra vốn tham chiếu, không tạo heartbeat giả, bộ lọc bảo vệ mặc định của advisor và reset tín hiệu giữa các lần test. Có thể biên dịch/chạy bằng `Tests/RunICTTests.ps1 -Mode Compile -Expert ICTAutoTraderTesterTests`, rồi `-Mode Run -Config ict_autotrader.ini`. Runtime riêng hiện báo `tester not started because the account is not specified`; **chưa có kết quả PASS runtime hoặc bằng chứng giao dịch**. Bài hồi quy mặc định tắt auto entry; cần một lần test EA chính với auto entry bật để đánh giá thực thi lệnh. Không coi compile thành công là backtest thành công.

## Cấu hình và chạy thử

1. Biên dịch các mã nguồn trong cùng cấu trúc thư mục. Gắn `RiskProtectionEA` trên chart riêng; đặt `Enable_Auto_Protection=true`, `Confirm_Protection_Account` bằng login tài khoản demo, giữ `Enable_Trade_Lock=true` và `Enable_New_Trade_Execution=false`. Theo mặc định một vị thế lỗ 3% vốn tham chiếu làm bộ bảo vệ khóa và yêu cầu đóng toàn bộ vị thế, hủy toàn bộ lệnh chờ của tài khoản, kể cả lệnh tay và EA khác. Tham khảo `docs/RISK_POLICY.md` trước khi bật.
2. Gắn `ICTAutoTraderEA` trên chart symbol muốn giao dịch, bật Algo Trading và `Enable_Auto_Entry=true`. Mặc định vào lệnh tự động tắt. Tài khoản thật còn yêu cầu `Allow_Real_Account=true` và `Confirm_Real_Account` khớp login. Không bật trên tài khoản thật khi chưa kiểm thử demo và chấp nhận rủi ro.
3. EA không mở lệnh nếu tài khoản đang có bất kỳ vị thế hoặc lệnh chờ nào. Một khóa tệp dùng chung giới hạn một instance auto trader cho tài khoản trên máy; bộ bảo vệ vẫn chạy riêng. Một tín hiệu nến chỉ được gửi một lần, kể cả khi broker từ chối hoặc kết quả không rõ: trạng thái được ghi trước khi gửi và duy trì sau khởi động lại. Không xóa tệp trạng thái để ép gửi lại tín hiệu cũ.
4. Theo dõi tab Experts, kết quả trade server, vị thế và SL/TP thực tế. Khi cần thay đổi SL/TP thủ công, EA này không tự áp dụng lại. Bộ `AutoPositionSLTPEA` của dự án nguồn là chức năng riêng cho vị thế mới chưa có SL/TP, không phải điều kiện vào lệnh của EA này.

Chốt trạng thái trước khi gửi giúp hạn chế lệnh trùng nhưng không tạo giao dịch nguyên tử với broker; mất điện, trễ mạng, khớp một phần, can thiệp thủ công hoặc EA khác chạy đồng thời vẫn cần kiểm tra thủ công. Cơ chế bảo vệ phụ thuộc terminal, kết nối và phản hồi server. Không đảm bảo dừng lỗ tại giá đặt hoặc ngăn mọi chương trình khác vào lệnh.

## Kiểm thử và nghiệm thu

Biên dịch sạch không chứng minh có tín hiệu hoặc giao dịch thành công. Cần kiểm thử Strategy Tester và demo với dữ liệu/broker thực: tín hiệu đủ/thiếu, lot tối thiểu, spread, margin, SL/TP, server từ chối/khớp một phần, restart, đồng thời, mất heartbeat, ngắt kết nối, khóa bảo vệ và cả tài khoản hedging/netting. Bản hiện tại chưa có bằng chứng nghiệm thu những kịch bản đó; không coi kết quả mô phỏng cũ của bộ bảo vệ là kiểm thử EA mới.
## Trạng thái tích hợp chuỗi sweep và BPR vào Smart Decision

Đây là phần đang triển khai, chưa phải nghiệm thu BPR/Wyckoff. AutoTrader vẫn
độc lập; các thay đổi dưới đây áp dụng cho chế độ IRL/ERL của Smart Decision.

- Hai pool tại biên dealing range được theo dõi chuỗi sweep từ nến đã đóng.
  Lần quét mới phải có nến riêng, đủ khoảng cách và giá từ chối đi xa khỏi pool.
  Pool bị phá vỡ hoặc hết hiệu lực sẽ ngừng đếm. Nếu thời điểm pool bắt đầu
  nằm ngoài lịch sử được giữ lại, hệ thống không dựng lại chuỗi thiếu dữ liệu.
- `SweepMode` mặc định là `SWEEP_2_PREFERRED`: cộng 5 điểm khi có hai sweep
  xác nhận trên cùng pool đang hoạt động và cấu trúc đã xác nhận; các điều kiện
  kế hoạch và rủi ro vẫn áp dụng. `SWEEP_1_ALLOWED` không cộng điểm này;
  `SWEEP_2_REQUIRED` chờ hai sweep. Hiện chế độ và chuỗi chỉ áp dụng cho hai
  biên range trong IRL/ERL, chưa bao phủ mọi liquidity pool.
- Biểu đồ có nhãn sweep đánh số và đường nối; dashboard hiển thị thời gian,
  cực trị và trạng thái của hai sweep đầu trong cùng pool. Chưa có bảng chi
  tiết về phản ứng, MSS, displacement, SMT và khoảng cách giá/thời gian cho
  từng sweep.
- BPR hiển thị phần giao nhau của hai FVG ngược chiều đã đóng; hướng được quy
  ước theo FVG hình thành sau. Đây mới là thông tin biểu đồ, chưa là điều kiện
  quyết định và chưa công bố đầy đủ lịch sử vùng BPR.
- Chưa có bộ nhận diện bốn loại vùng Wyckoff, các input và điều kiện confluence
  tương ứng. Vì vậy chưa hoàn tất toàn bộ yêu cầu và kiểm thử nghiệm thu.
- Dữ liệu range trao đổi dùng schema 2 và có các sự kiện sweep. Cần biên dịch
  và triển khai EA cùng indicator `SmartRiskDashboard` đồng thời: phiên bản chỉ
  hỗ trợ schema 1 không đọc được dữ liệu mới. Quy tắc bảo vệ tài khoản và kênh
  quyết định tới risk manager không thay đổi.
- Đã thêm các trường hợp kiểm thử sweep và BPR trong `ICTRangeTests.mq5`.
  Biên dịch thành công không có nghĩa là kiểm thử đã đạt: Strategy Tester cô lập
  chưa khởi chạy vì terminal cô lập chưa có tài khoản.

## Nâng cấp mapping MTF / SMT / Strong OB đang thực hiện

Xem [bảng đối chiếu 18 mục và trạng thái từng Phase](MTF_SMT_OB_GAP_MATRIX.md).
Smart Decision dùng `MTF_Mode=AUTO` theo chart hoặc `MANUAL` với
`MTF_Override`/`HTF_Override`; trong Smart Decision các input timeframe cũ
không còn điều khiển các tầng này. Đường phân tích dùng range chặn khi HTF và
MTF không đồng thuận. D1 (HTF MN1), W1 và MN1 hiện báo thiếu dữ liệu để tránh
khẳng định sai trạng thái khi chưa hỗ trợ replay tháng hoặc giảm cấp.

Chưa hoàn tất SMT nhiều khung/60 nến và Strong OB mới. Bản EA biên dịch trong
runtime kiểm thử cô lập chưa được triển khai vào terminal của người dùng và
không phải bản đã nghiệm thu. Không bật giao dịch thật để kiểm thử các thay đổi.

