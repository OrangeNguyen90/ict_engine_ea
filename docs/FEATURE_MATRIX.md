# Feature matrix — chuyển đổi hai thành phần

Trạng thái dựa trên cấu trúc mã hiện có; có module không đồng nghĩa được nghiệm thu.

Các điểm vào `ICTSmartDecisionEngineEA.mq5` và `EASmartRiskManagerPro.mq5` hiện dùng lại trực tiếp DecisionSupport và RiskProtection tương ứng. Đây là các bước chuyển tiếp: chưa hợp nhất đầy đủ phân tích, chưa tích hợp dịch vụ tính lot vào EA bảo vệ và chưa có hợp đồng tích hợp mới. Không chạy song song hai tên EA bảo vệ cho cùng tài khoản. `ICTAutoTraderEA` được giữ riêng theo yêu cầu bổ sung.

| Nhóm | Nơi hiện có | Trạng thái và việc còn lại |
| --- | --- | --- |
| Market structure, BOS/MSS, swing, FVG, sweep, MTF | `MarketStructure.mqh`, `FVGDetector.mqh`, `LiquidityDetector.mqh`, `TradeAdvisor.mqh`, `ICTDecisionEngine.mqh` | Có nhiều đường quyết định; hợp nhất hợp đồng, giữ hành vi đã kiểm chứng và kiểm tra CHoCH/displacement. |
| OB, IRL/ERL, premium/discount, range | `OrderBlock*`, `ICTRange*`, `ICTConfluenceEngine.mqh` | Có module; tích hợp vào kết quả chung, đối chiếu dữ liệu thực và lịch sử. |
| SMT và symbol | `SMTDivergenceDetector.mqh`, `SymbolCorrelationEngine.mqh`, `SMTChartRenderer.mqh` | EA mới xếp hạng symbol đã chọn trong Market Watch theo trị tuyệt đối tương quan trên tối đa 100 nến đóng H1 (hoặc khung SMT cấu hình), ít nhất 60 cặp, ngưỡng 0,60. Symbol nhập tay được ưu tiên; có thể không đủ hai symbol hợp lệ. Cần kiểm thử runtime, đồng bộ và hiển thị. |
| Phiên, kill zone, confluence, scenario, DOL | `ICTSessionManager.mqh`, `ICTConfluence*`, `ICTDecisionEngine.mqh` | Có một phần; kiểm tra múi giờ lịch sử, hoàn thiện và đối chiếu yêu cầu từng trường. |
| Dashboard, entry/SL/TP, giải thích | `SmartRiskDashboard.mq5`, `ICTDashboardPanel.mqh`, `ICTDecisionRenderer.mqh`, `ICTDecisionBridge.mqh` | Smart Decision EA xuất snapshot quyết định cho indicator cùng chart bằng bridge dùng chung với service cũ; panel và indicator có thể dùng cùng kết quả. Còn cần runtime xác minh hiển thị, stale, bảo vệ và mọi trường; các panel legacy và calculator vẫn có luồng riêng. |
| Lịch sử tín hiệu và kết quả | Các log/test hiện có | Chưa có hợp đồng lịch sử tín hiệu và kết quả đầy đủ; cần thiết kế lưu trữ và replay. |
| Lot, RR, chi phí, margin | `RiskCalculator.mqh`, `RiskCalculationService.mq5` | Có module dùng chung; chuyển quyết định phân tích sang hợp đồng dịch vụ rủi ro, kiểm thử broker. |
| Theo dõi, đóng và khóa tài khoản | `RiskProtectionEA.mq5`, `PositionMonitor.mqh`, `EmergencyController.mqh` | Giữ hiện trạng; kiểm tra xác nhận tài khoản, ranh giới 3%, mọi vị thế, pending, hedging/netting và lỗi server. Chính sách hiện có dùng ngưỡng **đạt hoặc vượt 3%**; yêu cầu mới nói **vượt 3%**: cần xác nhận và kiểm thử trước khi thay đổi. |
| Không tự mở lệnh trong hai EA mới | `ICTSmartDecisionEngineEA.mq5`, `EASmartRiskManagerPro.mq5` | Theo yêu cầu bổ sung, ICTAutoTraderEA là EA riêng có thể mở lệnh khi bật. Hai EA mới không tự mở lệnh; cần kiểm thử runtime. Đóng khẩn cấp vẫn được phép sau xác nhận. |
| Repaint, look-ahead, MT5 và dữ liệu thực | `Tests/`, báo cáo Tester | Có bài kiểm thử một phần; chưa đủ bằng chứng nghiệm thu toàn bộ hành vi, tính nhất quán và dashboard. |
