# Đối chiếu MASTER PROMPT MTF / SMT / Strong OB

Cập nhật 2026-11-09: phần bên dưới là audit/tiến độ lịch sử. Xem
[bàn giao mới](MASTER_MTF_DELIVERY_20261109.md) để biết các thay đổi MTF, SMT,
OB, lịch sử tín hiệu, liquidity và bằng chứng kiểm chứng hiện tại.

Kiểm kê trước thay đổi ngày 2026-11-08. `NOT VERIFIED` nghĩa là chưa có
bằng chứng chạy thành công; không đồng nghĩa với đạt kiểm thử.

| Mục | Hiện có | Thiếu hoặc xung đột; hướng sửa | Kiểm thử |
|---|---|---|---|
| 0 | Smart Decision dùng chung DecisionSupport; auto-entry của AutoTrader mặc định tắt | Giữ EA cũ, không bật giao dịch; không sao chép engine | regression default và lệnh |
| 1 | Detector, dashboard, bridge, test MQL và MetaEditor cô lập | Repo không có metadata Git; giữ các thay đổi hiện có. Baseline detector compile 0 lỗi/0 cảnh báo | `ICTDetectorTests` |
| 2 | Input khung riêng cho range và decision | Chưa có mapper thống nhất; mặc định H4/H1/M15/M5 mâu thuẫn bảng mới | mapping mọi period, manual và thiếu dữ liệu |
| 3 | Structure, range, bias, điều kiện rủi ro | Chưa có đủ trạng thái và hợp đồng snapshot 3 tầng | replay as-of, alignment |
| 4 | SMT hai symbol, correlation, pivot đóng | SMT H1 cố định, một TF, kiểm tra thời gian/gap còn hạn chế | bullish/bearish, thuận/nghịch, thiếu bar |
| 5 | Renderer SMT theo giá symbol chính | Không có 60 nến riêng cho detection và cửa sổ chart; chưa lưu chuỗi sự kiện | biên cửa sổ, replay |
| 6 | Detector OB, displacement, break, FVG | OB đơn nến, ngưỡng range; chưa đủ nhóm, ATR và bảy tiêu chí | detector prefix |
| 7 | Score OB 100 điểm | Trọng số cũ khác; thiếu bias, freshness, gate reversal/continuation | 100 điểm, hard gate |
| 8 | Mitigation, invalidation, expiration | Thiếu touch count, partial state, lifecycle timestamp/restart đầy đủ | lifecycle/replay |
| 9 | Vẽ zone OB | Chỉ một vùng theo prefix, chưa có MTF/multiple stable IDs và lựa chọn bounds yêu cầu | object/restart, MTF timestamp |
| 10 | Decision confluence và kế hoạch RR | Chưa hợp nhất đủ MTF, SMT nhiều cấp và Strong OB; BPR chỉ overlay | decision và risk regression |
| 11 | Dashboard, biểu đồ, indicator | Chưa đủ ma trận 3 tầng, SMT nhiều TF và score breakdown | consistency và UI |
| 12 | Nhiều input cũ | Thiếu mode mới; cần giữ tương thích input cũ, validate | default/manual/set |
| 13 | Shared MQL modules và bridges | Chưa có cache hợp nhất từng timeframe; tránh tạo detector trùng | change chart/cache |
| 14 | Range replay dùng nến đóng, detector dùng CopyRates shift 1 | Các nhánh chưa chứng minh as-of/no repaint đầy đủ | historical prefix, timestamp |
| 15 | Risk Manager, protection, RR và guardrails hiện hữu | Không thay đổi policy; chưa có runtime regression mới | 3%/account-wide trong demo/test |
| 16 | Các module Phase A–F có nền tảng | Cần nối, triển khai và xác minh từng phase | compiler, replay, tester |
| 17 | Test MQL hiện hữu, runtime MT5 cô lập | Tester trước đây thiếu tài khoản; compile không phải PASS runtime | 20 nhóm acceptance |
| 18 | Feature matrix và tài liệu | Cập nhật kết quả thực, không nhận nghiệm thu khi thiếu evidence | báo cáo build/test/backtest |

Baseline: `Tests/RunICTTests.ps1 -Mode Compile -Expert ICTDetectorTests`
trả `0 errors, 0 warnings`; chưa chạy được tester cô lập vì không có tài khoản.

## Kết quả hiện tại sau thay đổi

- Phase A **một phần**: `ICTTimeframeMapper.mqh` chứa bảng AUTO đầy đủ, kiểm
  tra MANUAL và các tầng vắng mặt. Smart Decision dùng mapping cho range,
  context, OB hiện có và SMT một khung. Input timeframe cũ vẫn tồn tại cho
  DecisionSupport cũ; trong Smart Decision chế độ AUTO/MANUAL mới quyết định
  các khung này. Indicator `SmartRiskDashboard` vẫn có input phân tích riêng,
  chưa hợp nhất toàn bộ mapping. Các assertion mapping đã được thêm, chưa chạy.
- Phase B **một phần**: ở chế độ range, Smart Decision yêu cầu MTF đã đóng
  không mới hơn snapshot LTF và đồng thuận HTF trước khi cho phép setup. HTF
  neutral, MTF thiếu dữ liệu hoặc xung đột bị chặn. D1 bị chặn khi HTF là MN1
  vì bộ replay cũ dùng số giây cố định cho tháng; W1/MN1 xác định thiếu tầng
  nhưng hiện chỉ báo `INSUFFICIENT_DATA`, chưa phân tích giảm cấp đầy đủ; nhánh
  decision không dùng range chưa được nâng cấp cùng logic này.
- Phase C **chưa hoàn tất**: SMT hiện dùng MTF được map, nhưng vẫn là một
  timeframe; chưa có AUTO_ALL, chuỗi lịch sử, 60-bar detection/display và
  timestamp xác nhận lịch sử bất biến. Không coi đó là Dynamic SMT hoàn chỉnh.
- Phase D **chưa triển khai Strong OB mới**: detector và scoring cũ vẫn tồn
  tại, chưa đáp ứng đặc tả bảy tiêu chí, hard gates và lifecycle mới.
- Phase E **một phần**: dashboard hiển thị LTF/MTF/HTF và mode, còn thiếu
  SMT/OB nhiều tầng và adapter đồng nhất theo yêu cầu. Chưa sửa policy vốn,
  account-wide close hoặc mặc định auto-entry.
- Phase F **chưa nghiệm thu**: MetaEditor trong runtime cô lập biên dịch; lần
  chạy tester báo `tester not started because the account is not specified`.
  Không có PASS runtime, demo, kết quả no-repaint hay backtest định lượng.
