# Master prompt — ICT Engine EA

Ngày cập nhật: 2026-11-06. Đây là yêu cầu kiến trúc đích, không phải tuyên bố các chức năng đã hoàn thành.

Duy trì một repository và hai thành phần cấp cao nhất dưới đây. Theo yêu cầu bổ sung, giữ `ICTAutoTraderEA` là EA riêng có thể tự mở lệnh khi được bật; phạm vi không tự động mở lệnh dưới đây áp dụng cho hai thành phần mới.

1. **ICT Smart Decision Engine** hợp nhất ICT DecisionSupport và ICT Core Analysis: market structure, BOS/MSS/CHoCH, swing, displacement, FVG, OB, premium/discount, dealing range, IRL/ERL, BSL/SSL, sweep/run, đa khung thời gian và phiên/kill zone. Bao gồm SMT thuận/nghịch, đề xuất hai symbol có thể thay đổi, tín hiệu và chất lượng; biểu đồ, liquidity map, bias matrix, confluence, scenario, entry/SL/TP/DOL; BUY PRIORITY, SELL PRIORITY, NO TRADE, giải thích, điều kiện thiếu, R, vô hiệu và lịch sử tín hiệu/kết quả. Giữ thuật toán đã hoàn thiện, hợp nhất đầu ra vào một quyết định; không duy trì các engine quyết định trùng lặp.
2. **EA Smart Risk Manager Pro** sở hữu tính rủi ro, lot, tiền rủi ro, RR, giới hạn, theo dõi vị thế, bảo vệ tài khoản, đóng khẩn cấp, cảnh báo, dashboard và nhật ký rủi ro. R đề xuất tối thiểu 1:2. Bảo vệ theo quy tắc một vị thế lỗ vượt 3% vốn tham chiếu, giám sát cả vị thế bên ngoài hệ thống; khi được người dùng xác nhận rõ ràng mới đóng toàn bộ vị thế tài khoản. Giữ an toàn và chức năng bảo vệ hiện có, xác minh chính xác ranh giới ngưỡng trước nghiệm thu.

Hai thành phần dùng hợp đồng dữ liệu rõ ràng, có phiên bản và kiểm tra độ mới: phân tích đề xuất Entry/SL/TP, bộ quản trị vốn tính/kiểm tra thực tế, đưa cảnh báo hoặc từ chối và theo dõi bảo vệ. Không sao chép thuật toán rủi ro sang engine phân tích hoặc thuật toán ICT sang bộ quản trị. Indicator, EA và thư viện có thể là module kỹ thuật, không là sản phẩm/engine độc lập. Không tự động mở lệnh.

Nghiệm thu yêu cầu hợp nhất chức năng hai dự án cũ, không mất Phase 2/3/4, bảo vệ nguyên vẹn, tích hợp và kết quả indicator/EA nhất quán trên MT5; kiểm thử repaint, look-ahead, rủi ro và dashboard với dữ liệu thực; chứng minh không tự mở lệnh. Xem kế hoạch và bằng chứng tại [ICT_ARCHITECTURE.md](ICT_ARCHITECTURE.md) và [FEATURE_MATRIX.md](FEATURE_MATRIX.md).
