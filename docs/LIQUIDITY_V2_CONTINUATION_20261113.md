# ICT SmartDecision — tiếp tục hoàn thiện Liquidity V2

Ngày: 2026-11-13–14. Tài liệu này bổ sung, không thay thế [báo cáo audit trước](LIQUIDITY_V2_DELIVERY_20261113.md) và [baseline trước nâng cấp](../Tests/Baselines/ICT_Baseline_20261113_pre_v2.zip).

## Những điểm đã sửa

- [ICTSignalHistory.mqh](../Include/ICTSignalHistory.mqh): một kết quả chưa xác nhận có thể được đánh giá lại trong cùng nến khi dữ liệu hoặc cổng rủi ro thay đổi. Nếu đủ điều kiện, chỉ dòng của nến đó được nâng thành tín hiệu xác nhận, các dòng chẩn đoán trước được giữ lại; lịch sử tín hiệu đã xác nhận vẫn bất biến. Lần nâng cấp ghi rõ thời gian quan sát theo giờ broker, tách biệt thời điểm bằng chứng nến đóng. Tín hiệu truyền ra ngoài sử dụng kiểm tra rủi ro, RR và chẩn đoán hiện tại; nếu kế hoạch mới khác bản đã ghi thì chặn tín hiệu. Các điều kiện dữ liệu, khung thời gian, SMT bắt buộc, mục tiêu và rủi ro vẫn được kiểm tra. Nhánh ghi file này vẫn cần kiểm thử native và khởi động lại MT5.
- [ICTRangeEngine.mqh](../Include/ICTRangeEngine.mqh): chỉ tính hợp lưu giữa hai vùng khác loại, cùng hướng, cùng range, nằm nội bộ, đã xác nhận và còn hiệu lực. Vùng bị xuyên hết hoặc mất hiệu lực không tiếp tục nâng điểm vùng khác.
- [ICTRangeTypes.mqh](../Include/ICTRangeTypes.mqh) và [ICTDecisionEngine.mqh](../Include/ICTDecisionEngine.mqh): từ chối tín hiệu range khi giá thoát thực tế đã tới mục tiêu. Nến phản ứng chạm mục tiêu được chọn bị coi là không rõ thứ tự diễn biến trong nến và setup bị hủy; kiểm tra thêm mục tiêu gần nhất trước nến để không âm thầm thay bằng mục tiêu xa hơn khi pool gần bị quét trong nến đó.
- [ICTUnifiedDecisionAdapter.mqh](../Include/ICTUnifiedDecisionAdapter.mqh) và [ICTUnifiedRenderer.mqh](../Include/ICTUnifiedRenderer.mqh): trình bày SMT thiếu dữ liệu, không có phân kỳ, cùng hướng, ngược hướng hoặc xung đột; dashboard phân biệt điều kiện chưa được đánh giá với điều kiện thất bại. Phần chẩn đoán không thay đổi cổng SMT.
- [ICTSessionLiquidity.mqh](../Include/ICTSessionLiquidity.mqh): hàm độc lập xác định high/low phiên đã đóng từ nến hoàn chỉnh. Cần truyền lịch offset UTC lịch sử của timezone phiên và broker; hàm từ chối lịch thiếu, nến thiếu/trùng/sai và thời gian DST mơ hồ. Đây **chưa phải tích hợp session liquidity vào tín hiệu, chart hay bộ chọn mục tiêu**.

## Kiểm tra

- [ICT_UNIFIED_CORE_FIXTURES.txt](../Tests/Reports/ICT_UNIFIED_CORE_FIXTURES.txt): 272 kiểm tra đạt qua bộ chuyển cú pháp MQL sang C#; kết quả trong file không phải chạy native MT5. Fixture bao gồm cùng nến, mục tiêu, vùng hợp lưu, phiên qua nửa đêm, DST và dữ liệu không hợp lệ.
- Bộ Pester của công cụ chạy: 57 đạt, 0 lỗi.
- [CompileICTIsolated.ps1](../Tests/CompileICTIsolated.ps1) biên dịch 23 chương trình trong bản MT5 cách ly và ghi [báo cáo](../Tests/Reports/ICT_CONTINUATION_BUILD_20261113.csv) cùng [mã băm nguồn](../Tests/Reports/ICT_CONTINUATION_SOURCE_MANIFEST.csv). Sau đó phần ghi nhật ký được cập nhật và chương trình sử dụng nó được biên dịch lại riêng; xem [kết quả biên dịch bổ sung](../Tests/Reports/ICT_SIGNAL_JOURNAL_BUILD_20261114.csv). Các binary nằm trong môi trường cách ly, không được chép sang EA đang cài.
- Các fixture MQL và Strategy Tester vẫn cần được chạy trong môi trường có tài khoản thử nghiệm. Lần thử trước báo tester không khởi động vì thiếu tài khoản; không có kết quả backtest, thống kê tín hiệu hoặc xác nhận giao diện thực tế.

## Công việc còn lại

1. Tích hợp phiên phải cấu hình chính xác lịch timezone và DST của từng phiên và broker, chuyển `confirmed_utc` về thời gian broker lịch sử một cách không mơ hồ, xử lý replay qua DST và mở rộng sức chứa pool. Không được mặc định timezone broker hoặc dùng offset hiện tại cho lịch sử.
2. Hoàn thiện trendline liquidity, round-number liquidity, relative equal highs/lows, inducement, xếp hạng zone và khả năng theo dõi sweep cho mọi pool theo đặc tả. Kiểm tra riêng breaker, CHoCH và mọi nhánh breakout/retest trong unified runtime.
3. Chạy fixture MQL native, so sánh baseline/candidate trên cùng dữ liệu và chi phí, kiểm tra chart và journal sau restart, sau đó đánh giá ngoài mẫu. Chỉ dữ liệu thực nghiệm mới cho phép kết luận về tần suất hoặc chất lượng tín hiệu.

Các tham số tolerance, số nến lịch sử, cửa sổ sweep và trọng số điểm vẫn là giả thuyết cấu hình, chưa được chứng minh tối ưu.
