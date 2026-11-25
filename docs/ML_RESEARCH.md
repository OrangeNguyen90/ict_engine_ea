# Nghiên cứu hồi quy, machine learning và mạng nơ-ron cho ứng viên ICT

Tài liệu này mô tả một thử nghiệm **offline**, không phải kết quả giao dịch. Chưa có lịch sử broker được kiểm chứng trong workspace, do đó chưa có bằng chứng mô hình nào có lợi thế trên US500 M15. [Nhánh dự báo đóng băng và hiển thị EA](ML_PREDICTION_EA.md) là tùy chọn tham khảo riêng; không tự xuất các dự báo OOS này thành tín hiệu EA.

## 1. Câu hỏi và mục tiêu dự báo

Pipeline bắt đầu từ ba nhóm ứng viên đã được xác nhận bằng nến đóng: sweep/reclaim, FVG first retest và break/retest. Mỗi mẫu là một ứng viên tại `as_of`; đặc trưng chỉ dùng thông tin đã biết khi nến xác nhận đóng. Entry được mô phỏng tại nến kế tiếp. Outcome được xác định sau entry và không được dùng làm đặc trưng.

| Hướng nghiên cứu | Mục tiêu | Đánh giá |
| --- | --- | --- |
| Hồi quy tuyến tính OLS | Ước lượng R ròng của outcome, một đại lượng liên tục | MAE, RMSE so với trung bình R trên train |
| Logistic regression | Ước lượng xác suất TP trước SL trong horizon; timeout thuộc lớp không TP | Brier, log loss so với tần suất trên train |
| Mạng nơ-ron nhiều lớp (MLP) | Cùng câu hỏi phân loại TP để so sánh trên các mẫu và fold giống logistic | Brier, log loss và tình trạng hội tụ |

Các mô hình này dự báo outcome **theo chính sách mô phỏng đã chọn**. TP-first không đồng nghĩa lợi nhuận dương: một timeout có thể có R dương hoặc âm. Hồi quy tuyến tính không tự cho xác suất; dự báo R có thể ngoài khoảng payoff thông thường vì OLS không bị chặn. Không so sánh trực tiếp MAE của hồi quy với Brier của phân loại.

[Gu, Kelly và Xiu (2020)](https://academic.oup.com/rfs/article/33/5/2223/5758276) so sánh nhiều mô hình trên dữ liệu cổ phiếu Mỹ và tách train, validation, test theo thời gian. Kết quả đó không chứng minh hiệu quả cho CFD, US500 hoặc các quy tắc ICT của dự án. Công trình cũng ghi nhận mạng nông có thể tốt hơn mạng sâu hơn trong bối cảnh dữ liệu tài chính nhiễu. Vì vậy MLP được coi là đối chứng nghiên cứu, không giả định ưu việt.

## 2. Chống rò rỉ và đánh giá

- Chia theo thứ tự thời gian; các ứng viên cùng timestamp thuộc cùng một batch. Ở mỗi batch, chỉ huấn luyện bằng outcome đã kết thúc **trước** thời điểm bắt đầu batch. Nhãn chồng lấn bị purge; không dựa vào số dòng cách nhau vì sự kiện không đều và có gap.
- Chuẩn hóa và xử lý missing được fit riêng bằng train của từng batch. `entry`, stop/target tính lại sau fill, `net_r`, outcome và mọi biến biết sau xác nhận không được đưa vào input. Xem [khuyến nghị chống data leakage của scikit-learn](https://scikit-learn.org/stable/common_pitfalls.html).
- `AMBIGUOUS`, `CENSORED`, `INVALID_PLAN` không phải nhãn thắng hoặc thua và được loại khỏi supervised target; phải báo số loại trừ. Tập đã resolve vẫn có thể bị thiên lệch do loại các trường hợp mơ hồ hoặc thiếu dữ liệu.
- So sánh mô hình và baseline trên cùng outcome ngoài mẫu, báo số mẫu, từng fold và các tình huống thiếu mẫu hoặc thiếu một lớp. Không diễn giải chỉ số thống kê thành lợi nhuận giao dịch.
- Các fold walk-forward vẫn là **thăm dò**. Chế độ holdout tách ứng viên theo mốc thời gian, niêm phong đầu ra mặc định, và khi được yêu cầu sẽ fit một lần từ các outcome đã kết thúc trước mốc đó. Trước khi mở holdout cần khóa cấu hình, ghi mọi trial và chọn mô hình trên dữ liệu phát triển; xem holdout rồi điều chỉnh hoặc chạy nhiều lần làm mất tính độc lập. Mã không thể chứng minh dữ liệu chưa từng được xem hoặc bảo đảm việc đăng ký trước. Khi số thử nghiệm tăng, nguy cơ overfit do lựa chọn cũng tăng; xem [nghiên cứu Probability of Backtest Overfitting](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2326253).
- Báo cáo có bảng reliability theo các nhóm xác suất cố định, Brier/log loss và ECE mô tả; `SMALL_SAMPLE` và nhóm rỗng phải được đọc cùng số mẫu. Brier và log loss phản ánh cả calibration lẫn khả năng phân biệt, nên không chứng minh calibration riêng; [tài liệu scikit-learn](https://scikit-learn.org/stable/modules/calibration.html). Không fit bộ hiệu chỉnh xác suất, không tự kết luận mô hình đã calibrated.
- Chưa kiểm chứng stability theo regime hoặc thử nghiệm tick/chi phí lịch sử. Spread mỗi nến chỉ là xấp xỉ Ask và không thể xác định thứ tự chạm khi TP và SL cùng trong một nến. Việc chỉ học nhãn đã resolve có thể ưu tiên outcome kết thúc sớm gần ranh giới; cần nghiên cứu sensitivity theo horizon tối đa.

## 3. Điều kiện đưa vào thử nghiệm thực tế

1. Xuất cặp CSV/sidecar, kiểm tra giá Bid, timezone/DST, độ phủ, gap và lịch sử điều kiện hợp đồng; làm theo [hướng dẫn xuất](RESEARCH_EXPORT.md). Cờ trong metadata là lời xác nhận của người vận hành, không tự chứng minh nguồn.
2. Ghi giả định phí/slippage và hash dữ liệu, mã, cấu hình. Chạy audit và replay trước khi fit. Tách bộ dữ liệu theo symbol và timeframe.
3. Kiểm tra số ứng viên, số ngày và phân bố lớp; so sánh với baseline, theo fold và sau chi phí. Khi mẫu ít, chỉ báo `INSUFFICIENT` theo trạng thái của pipeline.
4. Sau khi khóa mô hình và hoàn tất test cuối độc lập, mới thiết kế shadow forward riêng. Mọi dự báo hiện tại giữ `usable_for_shadow=false`; không tạo lệnh hay bỏ qua risk gate của EA.

Không chọn thiết kế deep learning lớn, LSTM hay Transformer chỉ vì số lớp nhiều. MLP phân loại hiện có dùng đặc trưng bảng. Nhánh RR ở mục 5 bổ sung đầu vào cửa sổ nến cho mạng feedforward; chưa triển khai LSTM hoặc Transformer và chưa có bằng chứng mạng sâu tốt hơn đối chứng.

## 4. Xuất dữ liệu thực và giới hạn audit hiện tại

Lần kết nối chỉ đọc ngày 19/11/2026 đã lấy [CSV US500 M15](../ai/research-data/US500_M15_20241119_20261119.csv) từ MT5 đang chạy, kèm [sidecar](../ai/research-data/US500_M15_20241119_20261119.csv.meta.json) và [báo cáo audit](../ai/research-runs/US500_M15_20241119_20261119_audit.json). Đây là các tệp local được Git bỏ qua. API trả 47.066 nến từ 19/11/2024 00:00 UTC đến 18/11/2026 23:45 UTC, 520 khoảng trống chưa phân loại, không có nến spread bằng 0. Hash SHA-256 CSV là `a08536a6e5df722f5e6080f4ab10c27fb26aa42df0aa2140271f713cd2a5be97`.

`complete=true` trong sidecar chỉ là trạng thái trích xuất theo API và kiểm tra thô hai đầu; `coverage_verified=false`. Chart mode Bid hiện tại không xác nhận loại giá trong cả lịch sử. Không có phí, slippage hay hợp đồng lịch sử đã xác minh. Vì vậy bộ này mới được audit; chưa dùng để fit và chưa có kết quả ML thực tế. Không tự sửa cờ xác minh để vượt điều kiện nạp.

## 5. Chọn RR bằng hồi quy và deep feedforward

[Bộ chọn RR](../ai/market/research/rr.py) so sánh một lưới target R **được khóa trước khi chạy**. Mỗi ứng viên có cùng thời điểm xác nhận và cùng thông tin đầu vào ở tất cả target; các biến thể target là hành động giả định của một mẫu, không phải các mẫu độc lập. Không tối ưu target, threshold, số lớp hoặc mô hình bằng kết quả OOS/holdout.

- `--rr-model ridge`: hồi quy Ridge đa đầu ra, một dự báo R ròng cho mỗi target. Đây là đối chứng mặc định.
- `--rr-model mlp`: mạng `MLPRegressor` với hai lớp ẩn `(32, 16)` và seed cố định. Mạng học payoff ròng liên tục, bao gồm timeout dương/âm và stop bị gap. Không dùng công thức `p(TP) * RR - (1-p(TP))` vì payoff thực không chỉ có hai mức cố định.
- `--rr-sequence-window 32`: lấy 32 nến **đã đóng**, kết thúc ở nến xác nhận. [Bộ tạo cửa sổ](../ai/market/research/sequences.py) chuẩn hóa OHLC theo hướng giao dịch, close cuối đã biết và ATR tại xác nhận; thêm spread/ATR. Mạng nhận `5 × window` giá trị nến cùng mã hướng và nhóm mẫu. Đây là deep feedforward trên cửa sổ cố định, chưa có bộ nhớ hồi quy hoặc attention. Thiếu lịch sử, thiếu ATR hoặc có gap trong cửa sổ thì loại mẫu train và từ chối dự báo; không điền nến giả.

Mỗi fold chỉ fit bằng ứng viên quá khứ có outcome của **mọi target** kết thúc trước fold. Supervised payoff dùng R ròng đã resolve, hoặc biên bất lợi cho `AMBIGUOUS`; dữ liệu censored/invalid không được gán là thắng hay thua. Cách ghép chung này tránh ưu ái target có nhiều outcome bị loại hơn. Xác suất TP được ước lượng riêng bằng logistic trên nhãn resolved trong train; có thể thiếu nếu chỉ có một lớp, và chưa được hiệu chỉnh xác suất.

Với mỗi ứng viên, chọn target có **R ròng dự báo lớn nhất** trong lưới; target nhỏ hơn thắng khi dự báo bằng nhau. Trả `ABSTAIN` khi thiếu bằng chứng hoặc dự báo tốt nhất không vượt `--rr-min-expected-r` (mặc định 0). RR danh nghĩa cao không tự tốt hơn RR thấp: cần payoff sau phí cùng xác suất thành công và độ bất định. Các dự báo R không phải xác suất hoặc cam kết lợi nhuận.

Trường `rr_study` lưu dự báo của từng hành động, quyết định chọn/abstain, số mẫu train, cảnh báo hội tụ, outcome bị loại và thống kê OOS. Mọi target cố định và chính sách đã chọn được đánh giá trên cùng tập ứng viên được chọn và quan sát đủ outcome; trường hợp biết outcome được chọn nhưng thiếu outcome khác vẫn được đếm riêng. `metrics.calibration` mô tả Brier, log loss và reliability cho từng target cùng chính sách đã chọn, với baseline trên đúng các hàng hợp lệ. Bootstrap theo ngày mô tả độ bất định của **R trung bình trên ứng viên**, không phải kiểm định toàn bộ quá trình chọn mô hình. Chưa mô phỏng danh mục, hạn mức vốn, drawdown hoặc các lệnh đồng thời; không cộng R thành lợi nhuận tài khoản.

Ví dụ chạy sau khi có nguồn đủ điều kiện, từ thư mục [ai](../ai/):

```powershell
.\.venv\Scripts\python.exe -m market.research.run --mode evaluate --ml --csv "C:\du-lieu\US500_M15.csv" --utc-offset-minutes 120 --commission-r 0.05 --slippage-ticks 1 --rr-targets 1 1.5 2 3 4 --rr-model mlp --rr-sequence-window 32 --min-mlp-train 1000 --holdout-cutoff "2026-06-01T00:00:00Z" --output ".\research-runs\US500_M15_rr_development.json"
```

Phí, slippage, timezone, cutoff và số mẫu trên chỉ là ví dụ cấu hình, không phải điều kiện broker đã xác minh. Giữ holdout niêm phong khi phát triển. Chỉ thêm `--evaluate-holdout` sau khi khóa nghiên cứu và tạo tên output mới; mở lại nhiều lần sẽ làm mất tính độc lập. Thay grid/model/window/threshold tạo trial hash khác; thứ tự khai báo cùng grid được chuẩn hóa. Hash mã bao gồm cả bộ chọn RR và bộ tạo cửa sổ. `usable_for_shadow=false` vẫn áp dụng cho toàn bộ nhánh này.

Các test cho nhánh mới dùng giá tổng hợp để kiểm tra tính đúng đắn, không chứng minh mô hình có lợi thế trên thị trường thực:

```powershell
.\.venv\Scripts\python.exe -m unittest market.test_research_rr market.test_research_sequences market.test_research_rr_integration
```
