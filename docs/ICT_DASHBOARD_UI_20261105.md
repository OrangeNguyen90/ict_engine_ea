# Dashboard bên trái — cập nhật 2026-11-05

Dashboard của ICTDecisionSupportEA và panel IRL/ERL của SmartRiskDashboard dùng chung renderer mới. Bản EA là **1.02**, bản indicator là **1.01**.

- Nút **👁** ở góc trái tiêu đề ẩn toàn bộ panel, giữ lại nút để bấm hiện lại. Việc làm mới dữ liệu không tự mở lại panel. Trạng thái này áp dụng trong phiên chương trình đang chạy; gắn lại EA sẽ khởi tạo lại giao diện.
- Tiêu đề và trạng thái luôn nằm trên cùng khi chuyển trang. Các nhóm Market, ICT Setup, Trade Plan và Decision Details có màu riêng, chữ Segoe UI và giãn dòng theo kích thước font thực tế.
- Nội dung dài tự xuống dòng theo chiều rộng đo bằng pixel. Hai nút `<` và `>` chuyển trang; tooltip giữ nguyên tiêu đề/trạng thái đầy đủ khi không đủ chiều rộng.
- Khi dữ liệu bị chặn, panel tập trung vào lý do lỗi thay vì liệt kê nhiều trường giá chưa có dữ liệu.
- Nút con mắt bên trái hoạt động độc lập với nút con mắt của dashboard rủi ro bên phải. Khi standalone EA đã có panel hoặc nút con mắt trên cùng chart, indicator không vẽ thêm một panel trái chồng bên dưới.
- Ẩn panel không ẩn các vùng phân tích trên chart và không thay đổi hoạt động phân tích hay chính sách giao dịch.

## Cấu hình dễ đọc

| Thiết lập | Standalone EA | Indicator | Giá trị mặc định mới |
| --- | --- | --- | --- |
| Vị trí ngang | Dashboard_X | Range_Panel_X | 12 |
| Vị trí dọc | Dashboard_Y | Range_Panel_Y | 80 |
| Chiều rộng | Dashboard_Width | Range_Panel_Width | 520 |
| Chiều cao | Dashboard_Height | Range_Panel_Height | 420 |
| Cỡ chữ | Dashboard_Font_Size | Range_Panel_Font_Size | 11 |

Các giá trị đang lưu trong chart có thể vẫn giữ cấu hình cũ. Sau khi gắn lại bản mới, sửa riêng các giá trị giao diện trong Inputs theo bảng trên nếu cần; không cần Reset toàn bộ tham số phân tích/rủi ro. Panel tự giới hạn kích thước trong vùng chart chính, phía trên các cửa sổ indicator phụ. Khi chart quá thấp, chỉ giữ nút con mắt đến khi có đủ không gian.

## Mã nguồn và kiểm tra

Renderer dùng chung: [ICTDashboardPanel.mqh](../Include/ICTDashboardPanel.mqh). Hai adapter: [ICTRangeRenderer.mqh](../Include/ICTRangeRenderer.mqh) và [ICTDecisionRenderer.mqh](../Include/ICTDecisionRenderer.mqh). Sự kiện được nối trong [ICTDecisionSupportEA.mq5](../Experts/ICTDecisionSupportEA.mq5) và [SmartRiskDashboard.mq5](../Indicators/SmartRiskDashboard.mq5).

Log biên dịch dùng hậu tố `dashboard_ui.compile.log`. Kiểm tra trực quan và thao tác bấm con mắt trong MT5 chưa thực hiện được vì helper điều khiển Windows báo `Computer Use native pipe is unavailable`. Không suy diễn kết quả biên dịch thành xác nhận giao diện runtime.

Cả 16 chương trình đã biên dịch không lỗi/cảnh báo. Các chương trình liên quan được biên dịch lại sau điều chỉnh cuối. Hai EX5 của standalone EA và indicator đã được chép vào vị trí MT5 hiện có, đối chiếu SHA-256 trùng bản trong dự án; bản cũ nằm trong `Tests/.dashboard-ui-backup/20261105_093116`. Gắn lại EA/indicator để nạp phiên bản mới. Mã nguồn năm module bảo vệ vẫn khớp hash baseline.

Tham chiếu API chính thức: [TextSetFont](https://www.mql5.com/en/docs/objects/textsetfont), [TextGetSize](https://www.mql5.com/en/docs/objects/textgetsize), [OBJ_BUTTON](https://www.mql5.com/en/docs/constants/objectconstants/enum_object/obj_button).
