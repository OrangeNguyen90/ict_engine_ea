# Đối chiếu MASTER PROMPT MTF / SMT / Strong OB

## Dashboard rủi ro một trang và trần 3% / 6% — 24/11/2026, bản 1.11

- Hai EA DecisionSupport/Smart dùng bảng bên phải **một trang, 12 dòng tóm tắt**: bảo vệ, P/L mở, rủi ro SL + pending, phần Equity có thể giảm thêm, P/L ngày, risk ngày đã dùng, dư địa, margin, Balance/Equity, số lệnh, vị thế rủi ro nhất, trần lệnh/ngày. TP/RR và chi tiết từng vé chuyển vào tooltip. Nền xen kẽ; đỏ cho lỗi/âm/thiếu dữ liệu, vàng cho cảnh báo, xanh cho lời/bảo vệ đang giám sát. Mặc định 420 × tối đa 420 px; tự giảm font, ưu tiên dòng đầu khi cửa sổ thấp, không phân trang.
- Theo bổ sung của người dùng: **mỗi lệnh không quá 3%, mỗi ngày không quá 6%**. Gỡ trần 2% cũ ở các đường kiểm tra liên quan, từ chối cấu hình vượt 3%/6% và không cho tắt giới hạn lỗ ngày bằng 0. Target mặc định vẫn **0,25%/lệnh**, không phải phải dùng hết 3%. Đề xuất mặc định tổng risk đồng thời 3%.
- Hiện dùng cả chốt lỗ ngày và chốt risk cộng dồn ngày (`Daily_Risk_Budget_Enable=true`) trong lúc chưa có lựa chọn khác từ người dùng. Chốt cộng dồn đọc deal mở hôm nay + history SL gốc, gồm lệnh đã đóng, không hoàn lại ngân sách sau lệnh thắng; thiếu SL gốc/history thì chặn. Có thể tắt riêng chốt cộng dồn nếu chỉ muốn giới hạn lỗ ngày; trần lỗ ngày 6% vẫn giữ.
- Vốn tính lot = `min(reference bảo vệ, Balance, Equity)`; bảng mặc định toàn tài khoản và `%` theo `min(Balance, Equity)`. Gate mới tính cả pending và rủi ro có thể trả lại lời tới SL. Không lấy lợi nhuận SL của lệnh này bù rủi ro lệnh khác; thiếu SL, lỗi đồng bộ hoặc định giá thì không cấp thêm risk.
- Auto Trader **1.31** thêm gate ngân sách tổng/ngày, trần margin dự kiến 20% Equity qua `OrderCheck()`, kiểm tra lại trước gửi. Smart auto SL/TP dùng vốn hiện tại thận trọng và trần 3%. Các quyền tự mở lệnh, tự sửa SL/TP, tự đóng toàn tài khoản vẫn cần bật/xác nhận riêng; không sửa hành động controller khẩn cấp 3% lỗ thả nổi/vị thế thành controller lỗ ngày 6%.
- **616/616 kiểm tra MQL thuần qua adapter C# đạt**; **30/30 chương trình MQL5 biên dịch 0 lỗi / 0 cảnh báo**, log có hậu tố `risk_3_6_final_20261124.compile.log` trong thư mục tài liệu. Không có bằng chứng broker/demo cho các gate mới. Script preview native đã biên dịch và được terminal cô lập tải nhưng không xuất completion/PNG; Computer Use báo `native pipe unavailable`. **Chưa nghiệm thu hình ảnh MT5**, phiên terminal thử nghiệm do tác vụ mở đã được đóng.
- Binary 1.11 / 1.31 mới nằm trong workspace; chưa chép/nạp vào terminal đang giao dịch. Chart/set đã lưu không tự đổi Inputs; cần nạp [preset 3%/6%](ICT_LIVE_CONSERVATIVE.set) hoặc cập nhật theo [cấu hình](CONFIGURATION.md). Chốt lỗ ngày chưa có latch Equity đầu ngày bền vững; 3%/6% là giới hạn tính toán/mở mới, không bảo đảm lỗ thực thi khi gap/trượt giá. Xem [nghiên cứu 10 nguồn chính thức, công thức, ví dụ và phần còn thiếu](RISK_POLICY.md).

## Chẩn đoán chart không có tín hiệu và DL ngày 23/11/2026 — bản 1.10

- Đọc snapshot terminal thực tế: bối cảnh HTF/MTF trung tính, xung đột hoặc thiếu cấu trúc đang chặn nhánh phân tích trước DNN; một số chart còn báo journal SMT không khôi phục được. File EA đã cài khớp bản 1.09, nên không chỉ là lỗi chép binary.
- Tầng phân tích sớm mặc định dùng **DNN thật**, ngưỡng **55/100, hai nhóm định hướng, một nhóm ủng hộ**. Cho phép xem DL khi MTF chưa đồng thuận, có nhãn rõ; giữ nguyên tính toán bối cảnh và xác nhận native. DNN không vượt prior hoặc có cảnh báo miền feature chỉ hiện dưới dạng **DL tham khảo**, bị giảm trọng số/điểm và có thể tắt.
- Giữ riêng 64 nến cuối ngoài train/calibration/test, dựng mũi tên cho tối đa 60 nến sau cutoff; thêm badge DL, CSV chẩn đoán và PNG chart. Không dùng trạng thái SMT/liquidity/OB hiện tại gán cho quá khứ.
- Replay dữ liệu MT5 thật trên 10 mã × M5/M15/H1: **130 / 113 / 109 ứng viên** trên 640 nến mỗi khung; tổng 352, gồm 268 ứng viên tham khảo. Đây là kiểm tra thuật toán qua C#, chưa phải kết quả giao dịch hoặc nghiệm thu ảnh chart live. **568 kiểm tra lõi đạt**; hai EA 1.10 đã sao lưu/cập nhật vào terminal và đối chiếu SHA256.
- Xem [chẩn đoán, bảng 10 mã, phương pháp, Inputs và giới hạn bằng chứng](DL_SIGNAL_DIAGNOSIS_20261123.md). Đang chờ nạp lại EA để kiểm tra CSV/PNG do chart thực tế xuất; Computer Use không kết nối được và lần thử native chart cô lập chưa có bằng chứng hoàn tất.

## Bối cảnh đa khung lên đầu và phân tích tổng hợp ngày 23/11/2026 — bản 1.09

- Bối cảnh đa khung đứng đầu nội dung dashboard của Smart, DecisionSupport/range và nhánh legacy, trước các phần ML/DL, first-touch và sweep. Giữ nguyên mapper, bias, detector và logic xác nhận bối cảnh native.
- Hai EA bổ sung **PHÂN TÍCH SỚM MUA/BÁN** bằng trung bình sáu nhóm: đường đi giá, hành vi nến, liquidity native, phản ứng OB/FVG/BPR, SMT, DNN. Mặc định điểm 60/100, ít nhất ba nhóm có dữ liệu và hai nhóm ủng hộ. Các nhóm kỹ thuật bổ sung bằng chứng thay cho yêu cầu tất cả cùng xuất hiện; bằng chứng ngược chiều kéo điểm xuống.
- DNN local `32 → 12 → 6 → 3` chỉ tham gia khi đã hiệu chỉnh, vượt prior theo Brier riêng, đúng nến/khung LTF và feature trong miền kiểm tra. Thiếu DL thì ghi rõ phân tích kỹ thuật; có thể bắt buộc DL bằng `Analysis_Require_Deep_Learning`. Điểm consensus không phải xác suất thắng; không trộn xác suất first-touch với xác suất hướng close.
- Tín hiệu sớm có nhãn riêng; bộ xác nhận vào lệnh, RR, Risk Manager, cảnh báo và nhật ký native tiếp tục dùng logic hiện hữu. **546 kiểm tra lõi đạt** qua adapter C#; chưa có backtest broker hay nghiệm thu hình ảnh MT5 cho tầng mới. Xem [nghiên cứu đầy đủ, công thức, nguồn gốc và cấu hình](ANALYTICAL_CONSENSUS_20261123.md).
- Hai EA 1.09, indicator và hai EA fixture liên quan biên dịch **0 lỗi / 0 cảnh báo**; binary ở workspace, log trong `Tests/.terminal/analysis-consensus-20261123/`. Cần cập nhật EX5 vào terminal và nạp lại để thấy thay đổi.

## Sửa hiển thị BSL / SSL untouched và first-touch ngày 23/11/2026 — bản 1.08

- Mức liquidity native chưa chạm/đang tiếp cận dùng `STYLE_DASH` rộng **1 px** để MT5 hiển thị đúng nét đứt; độ rộng 2 px có thể khiến đường hiện liền. BSL màu cam hổ phách (RGB 217/119/6), SSL xanh lam (RGB 37/99/235); cả đường và nhãn tự điều chỉnh độ tương phản theo nền chart. Có thể đổi hai màu trong Inputs qua `Range_Untouched_BSL_Color` và `Range_Untouched_SSL_Color`, dùng chung cho hai EA và indicator.
- Kết quả first-touch có nhãn trực tiếp trên chart: cặp giá SSL/BSL và tỷ lệ BSL trước, SSL trước, chưa chạm. `ML_Liquidity_Show_On_Chart=true` giữ nhãn khi dashboard bị ẩn; khi chưa qua điều kiện dữ liệu/kiểm định, chart ghi trạng thái và tooltip giữ giải thích chi tiết.
- Nhãn nằm phía ngoài dashboard để không bị che ở góc trên hoặc dưới. Xác suất chỉ hiện khi mô hình first-touch đã qua kiểm định hiện có; đây là tỷ lệ có điều kiện trên các mẫu OHLC xác định được thứ tự, không phải xác suất lợi nhuận.
- Đã biên dịch lại hai EA và indicator: **0 lỗi / 0 cảnh báo**, binary mới ở [DecisionSupport](../Experts/ICTDecisionSupportEA.ex5), [Smart](../Experts/ICTSmartDecisionEngineEA.ex5) và [SmartRiskDashboard](../Indicators/SmartRiskDashboard.ex5). Log trong `Tests/.terminal/untouched-style-20261123/`; cần cập nhật binary vào MT5 rồi nạp lại để áp dụng. Chưa kiểm tra trực tiếp hình ảnh trên chart MT5 trong lần sửa này.

## SSL / BSL untouched và xác suất chạm trước — bản 1.07, 22/11/2026

- Mức chưa bị quét/phá theo vòng đời native được làm đậm: đường liền 3 px, chữ Semibold, đen trên nền sáng / trắng trên nền tối. Bảng, mũi tên và cấu trúc thư mục hiện hữu được giữ lại.
- Bổ sung bài toán **BSL trước / SSL trước / chưa chạm trong H nến** ở đầu dashboard, mặc định H=12 nến LTF. Chọn cặp native gần nhất ở hai phía; kiểm tra thêm wick touch và coverage từ availability, không thay bằng mức ATR khi thiếu pool.
- Logistic và DNN `32 → 12 → 6 → 3` được fit lại bằng nhãn first-touch trong một mô hình riêng, replay qua `CICTRangeEngine.Step`. Bias 120 nến D1 đã đóng là feature và điều kiện ưu tiên; không tăng phần trăm thủ công theo hướng mong muốn.
- Phần trăm chỉ xuất khi khớp cặp pool replay/native, đủ train/calibration/test, được hiệu chỉnh, vượt cả prior và đối chứng khoảng cách, feature trong miền train và chưa chạm mức sau snapshot. Ghi CSV mẫu/kiểm định để đối chiếu khi runtime chạy.
- **Giới hạn:** loại OHLC chạm hai mức cùng nến không xác định được thứ tự và gap chưa phân loại; xác suất là ước lượng có điều kiện trên mẫu xác định nhãn, chưa phải xác suất tick vô điều kiện hoặc P(lợi nhuận). Chưa có kết quả fit/chart broker thực được quan sát trong phiên này.
- Kiểm tra lại CSV US500: 47.066 nến, 520 gap chưa phân loại, 24.253 cửa sổ 33+12 nến liên tục trước lọc; chưa phải số mẫu native độc lập. 498 fixture lõi đạt, không đồng nghĩa độ chính xác thị trường. Xem [nghiên cứu, hợp đồng nhãn, mô hình và giới hạn](DEEP_LEARNING_ADVISORY_20261120.md).
- Hai EA, indicator và ba EA fixture liên quan biên dịch 0 lỗi / 0 cảnh báo. Đã sao lưu và cài hai EA 1.07 cùng indicator của dự án vào đúng vị trí đang có, SHA256 sau copy khớp build; [manifest sao lưu/cài đặt](../Tests/.terminal/installed-ea-backups/sweep-focus-20261122-210400/manifest.json). Cần nạp lại để MT5 dùng binary mới; chưa quan sát fit/chart thực.

## Tinh chỉnh dashboard và ưu tiên sweep thuận H1 ngày 22/11/2026 — bản 1.06

- Hai EA dùng chung mã hiện hữu: `Dashboard_Y` và `Position_Risk_Y` mặc định từ 80 xuống **60 px**, nâng hai bảng lên 20 px. Chart đang lưu Inputs cũ cần sửa riêng hai giá trị này; vị trí kéo thả vẫn được tôn trọng trong phiên.
- Mũi tên sweep tập trung giảm từ width 3 xuống **1**, điều chỉnh bằng `Sweep_Focus_Arrow_Size` (1–3); cỡ nhãn giữ nguyên.
- `Sweep_Focus_Prefer_H1=true`: ưu tiên sweep có hướng mũi tên thuận cấu trúc H1, sau đó theo thời điểm reclaim mới nhất và khung nguồn lớn hơn. SSL ↑ thuận H1 tăng; BSL ↓ thuận H1 giảm. Các vị trí còn lại vẫn có thể hiện sweep khác; mũi tên ngược H1 dùng màu xám.
- H1 lấy từ 120 nến đã đóng tại reclaim bằng detector swing hiện có, cùng `Range_Swing_Left/Right`. Nhãn/tooltip/dashboard ghi thuận, ngược, trung tính hoặc thiếu dữ liệu; H1 đang chạy và H1 đóng về sau không tham gia xếp hạng sự kiện cũ.
- Giữ nguyên cấu trúc thư mục, luồng engine, pool detector, snapshot/bridge, score, duyệt lệnh và quản lý rủi ro. Chỉ sửa các module/tài liệu/fixture đang có. Chi tiết trong [bàn giao sweep cập nhật](LIQUIDITY_SWEEP_MSS_20261120.md).
- Kiểm tra lõi bản 1.06: **458/458 đạt**, gồm 22 ca mới cho H1, nến chưa đóng, dữ liệu thiếu và thứ tự ưu tiên. Điều khiển Windows timeout hai lần ngày 22/11; chưa nghiệm thu bố cục trực tiếp trên MT5.
- Hai EA bản 1.06 và fixture `ICTSweepFocusTests` đã biên dịch **0 lỗi / 0 cảnh báo**, binary mới nằm cạnh mã nguồn trong `Experts` / `Tests`. Hash các nguồn được dùng để biên dịch khớp với workspace. Hai EX5 của terminal đã được sao lưu và cập nhật tại đúng đường dẫn hiện có; SHA256 sau copy khớp bản build. Cần nạp lại EA và sửa Inputs giao diện cũ nếu chart còn lưu 80.

## Bổ sung hiển thị liquidity sweep ngày 20/11/2026 — bản 1.05

Đã bổ sung dùng chung cho hai EA: đoạn BSL/SSL đậm, mũi tên tại râu quét, nhãn lớn, gộp trùng trên cùng nến, trạng thái MSS sau sweep và ngữ cảnh DNN tại nến reclaim. Xem [hành vi, điều kiện và giới hạn](LIQUIDITY_SWEEP_MSS_20261120.md).

- Đọc sự kiện từ snapshot native; không thay pool detector, score, schema/bridge hay cơ chế duyệt lệnh hiện tại.
- MSS tham khảo dùng swing đã xác nhận trước wick, phá bằng nến đóng sau reclaim và displacement mặc định. Chỉ gọi MSS khi bias trước sweep phù hợp; trường hợp khác ghi phá swing.
- DL chỉ hiện khi train/hiệu chỉnh kết thúc trước sự kiện và cùng khung; đây là dự báo hướng OHLC sau H nến, chưa phải model chuyên biệt TP/SL/MSS.
- 436 fixture pure core đạt ở bản 1.05; chưa nghiệm thu hình ảnh runtime MT5 trong phiên đó. Chi tiết build và giới hạn trong tài liệu bàn giao.

## Bổ sung tham mưu học sâu ngày 20/11/2026

Hướng nâng cấp ưu tiên là **TCN causal 32 nến + context MTF/SMT/OB**, huấn luyện ngoài EA và suy luận dùng chung trong hai EA sau kiểm định. Xem [phân tích, so sánh phương án và lộ trình](DEEP_LEARNING_ADVISORY_20261120.md). Đây là đề xuất nghiên cứu; chưa có TCN/Transformer được huấn luyện hoặc chứng minh tốt hơn trên dữ liệu broker.

| Khoảng trống hiện tại | Bằng chứng / ảnh hưởng | Hướng ưu tiên |
| --- | --- | --- |
| ML/DL trong hai EA đã có, nhưng còn hạn chế về bài toán | [Bản 1.04](ML_PREDICTION_EA.md) có logistic + DNN hai lớp ẩn, mặc định hiện đầu bảng; dự báo hướng giá sau H nến, chưa phải TP trước SL hoặc R ròng | Giữ làm đối chứng; bổ sung mô hình chấm setup với nhãn entry/SL/TP/horizon và chi phí |
| Feature ML chưa dùng đủ bối cảnh native | [Bộ học local](../Include/ICTStatisticalLearning.mqh) chưa nhận context MTF/SMT/Strong OB đầy đủ | Export feature đúng as-of từ snapshot native, tránh hai detector khác nhau nhưng mang cùng tên |
| Hợp đồng gap của local và Python khác nhau | Local đếm nến giao dịch qua khoảng nghỉ; [sequence Python](../ai/market/research/sequences.py) yêu cầu timestamp liên tục | Thống nhất session policy, phân loại đóng phiên và thiếu dữ liệu; không tự điền OHLC |
| Chuỗi dài không dùng được với nguồn US500 hiện có | Kiểm tra lại CSV: 47.066 nến, 520 khoảng >15 phút, chuỗi liên tục dài nhất 92; cửa sổ 128/256 có 0 mẫu liên tục | Bắt đầu W=32, đối chứng W=64 trên cùng cohort; nghiên cứu trading-clock sau khi xác minh lịch phiên |
| Chưa đủ nguồn cho đánh giá kinh tế | Bid lịch sử/coverage chưa xác minh; commission và contract history chưa đầy đủ | P0: provenance, nguồn broker, lịch phiên và chi phí; không đổi cờ xác minh để ép fit |
| Mô hình sâu chưa có kiểm định lựa chọn | Brier tốt hơn một cửa sổ và test tổng hợp không xác nhận lợi thế thị trường | Walk-forward nhiều fold, calibration riêng, cùng cohort, ghi đủ trial và giữ holdout cuối |
| Hai đường native vẫn khác nhau | Smart dùng unified; DecisionSupport còn nhánh legacy/range, dù dashboard ML dùng chung | Gắn model với đúng nguồn event/schema; kiểm tra parity trước khi gộp kết quả |
| Chưa có inference TCN/Transformer trong MT5 | Bridge hiện có đọc snapshot; portable model chỉ hỗ trợ họ model đã định nghĩa | ONNX adapter dùng chung, đối chiếu Python–ONNX–MQL, cache và shadow; đo runtime thực |

Thứ tự đề xuất: **P0 dữ liệu và funnel → P1 event/feature contract → P2 TCN32 và đối chứng → P3 ONNX/shadow → P4 PatchTST hoặc pretrained khi có ích bổ sung**. Mapper, Dynamic SMT và Strong OB đã có triển khai theo bàn giao 09/11; các nhận xét “chưa có” trong audit lịch sử bên dưới không phải kết luận hiện tại.

## Audit lịch sử và bàn giao MTF

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
