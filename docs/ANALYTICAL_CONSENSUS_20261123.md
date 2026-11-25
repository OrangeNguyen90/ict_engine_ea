# Bối cảnh đa khung và tín hiệu phân tích tổng hợp — 1.09

**Cập nhật:** các ngưỡng và cổng của 1.09 bên dưới là lịch sử. Bản [DL 1.10](DL_SIGNAL_DIAGNOSIS_20261123.md) đã chẩn đoán dữ liệu terminal thực tế, bổ sung mũi tên lịch sử sau cutoff, badge DL và chế độ phân tích sớm ít điều kiện hơn.

Ngày nghiên cứu và triển khai: 23/11/2026. Áp dụng cho hai EA dùng chung [mã chính](../Experts/ICTDecisionSupportEA.mq5). Dashboard đặt **bối cảnh đa khung → phân tích tổng hợp → first-touch SSL/BSL → sweep/MSS → thống kê ML/DL → quyết định native**. Indicator dùng chung renderer cũng đưa bối cảnh lên trước phần nghiên cứu khi có phần đó.

## Kết luận thiết kế

Muốn có thêm tín hiệu phân tích mà vẫn giữ bối cảnh đa khung, cần nới cách tổng hợp bằng chứng ở tầng phân tích. Giảm điều kiện HTF/MTF hoặc lấy điểm học sâu để bù cho bối cảnh xung đột sẽ làm đổi giả thuyết của chiến lược. Bản này giữ nguyên mapper, detector cấu trúc, snapshot và bộ xác nhận native; bổ sung một tầng **PHÂN TÍCH SỚM MUA/BÁN**. Tầng mới dùng trung bình các nhóm bằng chứng có dữ liệu, đủ số nhóm ủng hộ, theo đúng hướng HTF/MTF hiện hữu.

Điều kiện sweep, mẫu nến, vùng giá, SMT và DNN được xem là bằng chứng bổ sung ở tầng này. Một nhóm thiếu tín hiệu không tự phủ quyết mọi nhóm khác. Bằng chứng ngược chiều làm giảm điểm; dữ liệu không có được ghi là thiếu. Kết quả native vẫn cho biết khi nào điểm vào, mục tiêu, RR và rủi ro thực sự đạt yêu cầu. Mũi tên phân tích sớm là ứng viên để quan sát, không thay cho kết quả xác nhận đó.

## Những gì các nguồn bên ngoài hỗ trợ

Các nguồn dưới đây được tra cứu để xây dựng phương pháp. Chúng không chứng minh các trọng số hay ngưỡng của EA có lợi thế trên symbol, broker và khung intraday đang dùng.

| Nguồn gốc | Kết quả liên quan | Cách sử dụng và giới hạn |
| --- | --- | --- |
| [Lo, Mamaysky, Wang — Foundations of Technical Analysis, 2000](https://web.mit.edu/wangj/www/pap/LoMamayskyWang00.pdf) | Nhận dạng hình học bằng thuật toán cho phép kiểm tra thông tin có điều kiện của mẫu giá | Định nghĩa bằng OHLC và thời điểm xác nhận; không coi tên mẫu hoặc cảm quan là bằng chứng đủ. Nghiên cứu cổ phiếu Mỹ ngày không xác nhận hiệu quả mẫu intraday ở đây. |
| [Moskowitz, Ooi, Pedersen — dữ liệu gốc Time Series Momentum](https://www.aqr.com/Insights/Datasets/Time-Series-Momentum-Original-Paper-Data) | Tác giả cung cấp bằng chứng động lượng ở nhiều nhóm hợp đồng với kỳ quan sát dài | Giữ một nhóm đo hướng và đường đi của giá. Cửa sổ 3/12 nến của bản này là lựa chọn kỹ thuật chưa được suy ra hay kiểm định từ kết quả 12 tháng của bài báo. |
| [Gneiting, Ranjan — Combining Predictive Distributions](https://arxiv.org/abs/1106.1638) | Phân tích tổ hợp dự báo và vấn đề calibration/dispersion | Trung bình là quy tắc minh bạch để bắt đầu, nhưng không tự biến điểm kỹ thuật thành xác suất. Gom các biến cùng nội dung vào nhóm để hạn chế đếm trùng. |
| [Guo và cộng sự — On Calibration of Modern Neural Networks](https://arxiv.org/abs/1706.04599) | Độ tin cậy của neural network có thể lệch; temperature scaling là phương pháp hiệu chỉnh hữu ích trong các tập dữ liệu được nghiên cứu | Tái sử dụng hiệu chỉnh trên tập riêng và kiểm tra Brier của DNN. Việc có hiệu chỉnh không đủ chứng minh xác suất đúng trong mọi chế độ thị trường. |
| [Geifman, El-Yaniv — Selective Classification for Deep Neural Networks](https://arxiv.org/abs/1705.08500) | Việc từ chối dự báo tạo đánh đổi giữa độ phủ và sai số | Cho phép chỉnh ngưỡng/quorum và đo cùng một cohort. Không áp dụng bảo đảm sai số của bài phân loại ảnh sang thị trường. |
| [Bai, Kolter, Koltun — Convolutional and Recurrent Networks for Sequence Modeling](https://arxiv.org/abs/1803.01271) | TCN là một lựa chọn có cơ sở để nghiên cứu chuỗi nhân quả | Giữ TCN32 làm hướng nâng cấp sau export và kiểm định; mô hình đang được tích hợp thực tế ở bản này là DNN hai lớp ẩn hiện có. |
| [Bailey và cộng sự — The Probability of Backtest Overfitting](https://www.davidhbailey.com/dhbpapers/backtest-prob.pdf) | Thử nhiều cấu hình rồi chọn kết quả đẹp có thể tạo overfit | Không chọn ngưỡng bằng đoạn kiểm định cuối. Ghi số lần thử, dùng walk-forward và tính chi phí khi đánh giá giao dịch. |

Suy luận thiết kế từ các nguồn: nhiều yếu tố cần đại diện cho những khía cạnh khác nhau của diễn biến giá. Body, close-location và engulfing liên quan chặt với nhau; đếm mỗi yếu tố như một lá phiếu riêng sẽ làm nhóm nến lấn át SMT hoặc liquidity. Chia nhóm hạn chế vấn đề này nhưng **không chứng minh các nhóm độc lập thống kê**. DNN cũng dùng OHLC nên còn tương quan với các nhóm kỹ thuật.

## Sáu nhóm bằng chứng trong mã

[Bộ tổng hợp thuần](../Include/ICTAnalyticalConsensus.mqh) không đọc web, không đặt lệnh và không sửa snapshot. [Lớp runtime](../Include/ICTAnalyticalDashboard.mqh) lấy các nến broker đã đóng, gọi bộ tổng hợp rồi trình bày kết quả.

| Nhóm | Các thành tố được kết hợp bên trong một lá phiếu |
| --- | --- |
| Đường giá | Biến động close 3 nến / 1,5 ATR; 12 nến / 3 ATR; hiệu suất có dấu `delta12 / tổng(abs(delta từng nến))`. Lấy trung bình ba thành tố sau khi chặn miền hợp lệ. ATR lấy từ các nến trước nến phân tích. |
| Hành vi nến | Body/ATR; vị trí close trong high-low; chênh lệch râu dưới/râu trên; điểm có dấu của các mẫu thống kê hiện hữu. Trung bình trong nhóm, không thêm một lá phiếu cho mỗi mẫu. |
| Liquidity native | Sự kiện xác nhận gần nhất: SSL sweep/reclaim hoặc BSL breakout hỗ trợ mua; chiều ngược lại hỗ trợ bán. Sự kiện đối nghịch cùng thời điểm được trung bình, bằng chứng giảm theo tuổi. Cửa sổ là số khoảng thời gian LTF đã trôi qua, không điền thêm nến qua khoảng nghỉ. |
| Vùng giá | Phản ứng nến đóng tại vùng OB/FVG/BPR đủ vòng đời. Vùng phải có trước nến phản ứng. Giữ bằng chứng mạnh nhất mỗi phía trong cùng nhóm, tránh nhân điểm do nhiều vùng trùng. |
| SMT | Trung bình bằng chứng có dấu của các peer/khung có dữ liệu, tương quan đã xác định và thời gian khớp snapshot. SMT trái chiều kéo điểm xuống; peer thiếu dữ liệu không thành điểm trung tính giả. |
| Deep learning | `P(tăng sau H nến) − P(giảm sau H nến)` từ DNN `32 → 12 → 6 → 3` đã huấn luyện thật sự bởi bộ học local. Khối lượng xác suất đi ngang được giữ lại qua mức độ yếu của hiệu số. |

Nhóm đã quan sát nhưng không có sự kiện mang giá trị 0. Nhóm chưa có dữ liệu không tham gia mẫu số; vẫn phải đạt mức độ phủ tối thiểu. Các hệ số ATR/cửa sổ và ngưỡng dưới đây là quy tắc kỹ thuật ban đầu, chưa phải kết quả tối ưu hóa trên broker.

Mỗi nhóm có `v_g ∈ [-1,1]`; hướng bối cảnh là `d ∈ {-1,+1}`. Với `N` nhóm có dữ liệu:

```text
mean = tổng(v_g) / N
score = 50 × (1 + d × mean)
ủng hộ nếu d × v_g ≥ 0,2
phản đối nếu d × v_g ≤ −0,2
```

Mặc định cần ít nhất **3 nhóm có dữ liệu, 2 nhóm ủng hộ, điểm 60/100**. Ví dụ đường giá `+0,8`, nến `+0,5`, liquidity `0`, vùng giá `0` tạo điểm mua `66,25/100`, dù chưa có SMT hoặc DL. Nếu liquidity và vùng giá đều là `−1`, điểm giảm còn `41,25`, ứng viên bị giữ lại. Một nhóm cực mạnh đi cùng ba nhóm trung tính không đủ quorum ủng hộ. Điểm này mô tả đồng thuận, không mang nghĩa “66,25% thắng”.

## Bối cảnh đa khung và deep learning

Smart dùng các tier của snapshot unified: dữ liệu hợp lệ, đủ ba khung khác nhau theo thứ tự LTF < MTF < HTF, nến LTF khớp `asof`, hai khung trên đã đóng, bias HTF khác trung tính và MTF cùng hướng. Các phép tính mapper/structure hiện hữu không thay đổi. DecisionSupport range đọc xác nhận cấu trúc và hướng từ range engine đang có; nhánh legacy đọc bias đã tính của decision. Nhánh này có thể chờ cấu trúc lâu hơn Smart; không chạy detector mới để ép hai nhánh phát tín hiệu giống nhau.

DNN chỉ được nhập vào trung bình khi có đủ các điều kiện: cùng LTF và đúng nến hiện tại; model fitted và calibrated; Brier riêng DNN thấp hơn prior trên đoạn kiểm định; nhãn train/calibration/test không vượt thời điểm phân tích; xác suất hữu hạn và tổng bằng 1; từng feature chuẩn hóa nằm trong miền kiểm tra ±6 độ lệch chuẩn train. Bộ chuẩn hóa đang có vẫn chặn đầu vào mạng ở ±5. Các kiểm tra này là giới hạn sử dụng, không phải chứng nhận thị trường ổn định hay mô hình có lợi nhuận.

Xác suất của DNN là **close tăng/giảm/ngang sau H nến**. Xác suất first-touch SSL/BSL có nhãn và horizon khác nên không được lấy trung bình với DNN này. Snapshot model Python cũng không được trộn tự động khi chưa có cùng hợp đồng feature/nhãn/thời gian. Tầng consensus chưa được hiệu chỉnh như một bộ phân loại độc lập; vì vậy toàn bộ kết quả consensus là điểm bằng chứng.

Khi DL không hợp lệ, dashboard nói rõ “Đang phân tích kỹ thuật; DL chưa tham gia”. Có thể bật `Analysis_Require_Deep_Learning=true` để chỉ xuất tín hiệu sau khi nhóm DNN sử dụng được. Cách này giảm độ phủ, có chủ đích, thay vì dùng tỷ lệ chưa được kiểm định để làm đầy dashboard.

## Cấu hình và sử dụng

| Input | Mặc định | Tác động |
| --- | --- | --- |
| `Analysis_Enable` | true | Bật tầng phân tích tổng hợp ở cả hai EA |
| `Analysis_Show_On_Chart` | true | Hiện một mũi tên và nhãn ứng viên của nến hiện tại |
| `Analysis_Minimum_Score` | 60 | Tăng ngưỡng để giảm số ứng viên; miền `(50,95]` |
| `Analysis_Minimum_Groups` | 3 | Số nhóm có dữ liệu tối thiểu, 2–6 |
| `Analysis_Minimum_Supporters` | 2 | Ít nhất 2 nhóm ủng hộ; không lớn hơn số nhóm tối thiểu |
| `Analysis_Liquidity_Window_Bars` | 12 | Tuổi tối đa của sự kiện native, 1–60 khoảng LTF |
| `Analysis_Require_Deep_Learning` | false | Khi true, DNN sử dụng được trở thành điều kiện bắt buộc |

Để quan sát thận trọng hơn, có thể dùng điểm 70 và ba nhóm ủng hộ với tối thiểu ba nhóm dữ liệu. Đây là ví dụ cấu hình, chưa được khuyến nghị bằng kết quả broker. Bắt đầu bằng mặc định 60/3/2, ghi tín hiệu và so sánh các cấu hình trên cùng chuỗi dữ liệu trước khi quyết định đổi.

Mũi tên biểu diễn **ứng viên hiện tại** và được bỏ khi điều kiện hiện tại không còn đạt. Chưa có nhật ký bất biến riêng của consensus; huấn luyện lại DNN có thể thay điểm sau đó. Chưa tuyên bố lịch sử consensus không repaint. Nhật ký tín hiệu native và các điều kiện vào lệnh/rủi ro không bị thay đổi bởi bộ tổng hợp.

Các tài liệu bên ngoài được đọc trong quá trình nghiên cứu; EA không tự crawl bài viết hoặc tin tức lúc chạy. Tín hiệu runtime dùng dữ liệu broker và nguồn native có thời gian xác nhận. Muốn thêm lịch kinh tế, tin tức, order flow hay dữ liệu sàn cần nguồn có quyền truy cập, định danh symbol, timestamp công bố và khả năng replay đúng thời điểm. Tick volume của CFD/FX không được đổi tên thành khối lượng giao dịch tập trung hay order flow thực.

## Kiểm chứng và giới hạn còn lại

**546 kiểm tra lõi đạt**, bao gồm các ca mới cho độ phủ, quorum, đối xứng mua/bán, điểm ngược chiều, dữ liệu thiếu/cũ/tương lai, DNN khác khung/chưa hiệu chỉnh/chưa vượt prior, feature ngoài miền, xác suất sai, vùng trùng và thứ tự dashboard. Chạy bằng [adapter C# của thuật toán MQL thuần](../Tests/RunICTCoreFixtures.ps1); đây không phải chạy MT5 hay backtest thị trường. Trên cohort giả lập 11 mức bằng chứng cố định, ngưỡng 60 nhận 7 ứng viên, ngưỡng 70 nhận 3; ví dụ chỉ kiểm tra hành vi ngưỡng.

Biên dịch cuối: hai EA **1.09**, indicator và hai chương trình fixture `ICTUnifiedTests` / `ICTUnifiedDiagnosticTests` đều **0 lỗi / 0 cảnh báo**. Binary được cập nhật cạnh mã nguồn trong workspace; log mới nằm ở `Tests/.terminal/analysis-consensus-20261123/`. Chưa cài thay binary của terminal đang chạy hoặc gỡ/gắn EA trên chart trong lần sửa này.

Chưa có kết quả mới chứng minh số lượng/độ chính xác/lợi nhuận tín hiệu tăng trên broker. Bộ dữ liệu US500 đã được audit ở [nghiên cứu trước](DEEP_LEARNING_ADVISORY_20261120.md) còn hạn chế provenance và coverage, nên không được tự nâng cờ xác minh để tạo model thật được chấp nhận. Không suy rộng tỷ lệ đạt fixture hoặc ví dụ giả lập sang hiệu quả giao dịch.

Đánh giá tiếp trên broker cần giữ cùng một cohort và ghi tuần tự: số nến đủ MTF; số nến đủ nhóm dữ liệu; số ứng viên theo từng ngưỡng; số xác nhận native; phân bố theo phiên/chế độ biến động; Brier/log-loss và reliability của DNN; kết quả sau spread, commission, slippage cho những kế hoạch có entry/SL/TP rõ ràng. Chia thời gian train/calibration/test, purge nhãn qua ranh giới, dùng nhiều fold tiến về trước và giữ tập cuối chưa dùng chọn ngưỡng. Không gọi kết quả consensus là thắng/thua giao dịch khi nó chưa có hợp đồng thực thi riêng.
