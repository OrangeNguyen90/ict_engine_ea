# Thống kê ML/DL trong Smart EA và DecisionSupport EA

## Bản 1.10 — DL phân tích sớm và mũi tên lịch sử

Hai EA bổ sung chế độ dùng DNN đã fit/hiệu chỉnh để phân tích sớm dù MTF chưa đồng thuận, kèm nhãn và điểm giảm cho DL chưa vượt prior. Xác nhận native và logic bối cảnh không thay đổi. Ngưỡng mới 55/2/1; mặc định bắt buộc DNN. `ML_Statistics_Replay_Reserve_Bars=64` giữ riêng đuôi lịch sử để tái dựng 60 nến mà không đọc nhãn tương lai. Xem [bằng chứng 10 mã × 3 khung, Inputs, trạng thái cài đặt và giới hạn nghiệm thu ảnh](DL_SIGNAL_DIAGNOSIS_20261123.md).

## Bản 1.09 — bối cảnh đa khung và đồng thuận phân tích

Bối cảnh đa khung được đưa lên trước các phần ML/DL. Hai EA có thêm tầng phân tích sớm lấy trung bình theo nhóm, bao gồm DNN local đã hiệu chỉnh, vượt prior và khớp nến LTF. DNN là một nhóm duy nhất để tránh nhân phiếu từ cùng mô hình; xác suất first-touch không được trộn với bài toán hướng close. Tầng này tạo ứng viên phân tích riêng với quyết định native. Xem [nguồn nghiên cứu, công thức, điều kiện sử dụng DL và các Inputs mới](ANALYTICAL_CONSENSUS_20261123.md).

## Bản 1.07 — thứ tự chạm SSL / BSL untouched

Thêm mô hình first-touch riêng vào đầu dashboard và badge: BSL trước, SSL trước, chưa chạm trong H nến (mặc định 12 LTF). Native replay cung cấp cặp pool và nhãn; logistic cùng DNN hai lớp ẩn được fit lại cho bài toán này, không đổi tên xác suất tăng/giảm của nhánh cũ. Xu hướng 120 nến D1 đóng được đưa vào feature và ưu tiên hiển thị. Khi trái xu hướng, giữ nguyên phần trăm và ghi chưa đồng thuận.

Chỉ xuất số khi vượt các gate dữ liệu, parity pool và kiểm định. Nến OHLC chạm hai phía không rõ thứ tự bị loại, nên phần trăm được ghi rõ là có điều kiện trên mẫu xác định nhãn. Chưa phải xác suất tick vô điều kiện hoặc lợi nhuận; xem [nghiên cứu 1.07 và giới hạn](DEEP_LEARNING_ADVISORY_20261120.md).

| Input | Mặc định | Ý nghĩa |
| --- | --- | --- |
| `ML_Liquidity_Enable` | true | Bật phần first-touch độc lập |
| `ML_Liquidity_History_Bars` | 12000 | Lịch sử LTF cho replay, cho phép 1000–20000 |
| `ML_Liquidity_Horizon_Bars` | 12 | Thời hạn chạm mức, cho phép 1–24 nến |
| `ML_Liquidity_Trend_Timeframe` | D1 | Khung cấu trúc dài hạn; phải lớn hơn LTF |
| `ML_Liquidity_Minimum_Train` | 200 | Số mẫu train tối thiểu, không phải chứng nhận đủ dữ liệu |
| `ML_Liquidity_Minimum_Validation` | 50 | Số mẫu tối thiểu cho từng tập calibration/test |
| `ML_Liquidity_Prefer_Long_Trend` | true | Ưu tiên hướng xác suất đồng thuận trend, không sửa xác suất |
| `ML_Liquidity_Save_Evidence` | true | Lưu mẫu/kiểm định CSV trong MQL5/Files sau replay/fit |

Lần gắn EA đầu cần tải lịch sử, replay và học qua các timer; dashboard ghi tiến độ hoặc lý do chờ. Không có con số giả khi thiếu mẫu/lớp. Huấn luyện lại sau 64 nến LTF; huấn luyện lại hoặc gỡ/gắn EA có thể thay kết quả mô hình. Quản lý lệnh/SL/TP không nhận trọng số hay veto mới từ nhánh này. Phần bên dưới mô tả mô hình giá đóng 1.04 vẫn tồn tại độc lập.

Bản **1.04** đưa thống kê ML/DL lên đầu dashboard của **cả hai EA**, mặc định bật. Không cần cài Python hoặc tạo tệp model để dùng nhánh thống kê tại chart. Nhánh snapshot Python trước đây vẫn có thể bật riêng trên cả hai EA.

## Thống kê trực tiếp từ lịch sử chart

[Bộ học MQL5](../Include/ICTStatisticalLearning.mqh) huấn luyện hai bộ phân loại ba lớp: logistic softmax và DNN có hai lớp ẩn, kiến trúc `32 → 12 → 6 → 3`, tanh/softmax và backpropagation. 32 feature gồm cửa sổ sáu nến OHLC chuẩn hóa theo ATR, biến động 3/12 nến, range, spread và bốn nhóm mẫu: sweep/reclaim, engulfing, phá đỉnh/đáy tám nến, FVG retest lần đầu. Detector này là định nghĩa thống kê riêng, không thay detector hoặc tín hiệu ICT native.

Xác suất có nghĩa cụ thể: **giá đóng sau H nến giao dịch tăng / giảm / nằm trong biên**, so với giá đóng nến xác nhận. Biên bằng `Move_ATR × ATR(14) + spread ghi tại nến xác nhận × point`. Đây không phải xác suất TP trước SL hoặc có lợi nhuận sau phí. Không dùng xác suất này để tự giao dịch hay chỉnh SL/TP.

[Luồng runtime](../Include/ICTStatisticalDashboard.mqh) chỉ lấy nến đóng bằng `CopyRates(..., 1, ...)`, theo thứ tự cũ đến mới. [Tài liệu CopyRates](https://www.mql5.com/en/docs/series/copyrates) mô tả chỉ số 0 là nến đang hình thành và thứ tự vật lý của dữ liệu sao chép. Mỗi mẫu lịch sử cách nhau H nến, nhãn chỉ dùng giá đóng tại H nến sau đó; mẫu chưa đủ tương lai không được huấn luyện. Timestamp trong bộ học định danh nến bằng thời điểm mở nến của MT5.

Dữ liệu chia theo thời gian: 65% train, 15% hiệu chỉnh, phần còn lại kiểm định; bỏ thêm một mẫu ở mỗi ranh giới để nhãn không chồng qua tập sau. Scaler, tần suất tham chiếu và trọng số chỉ fit trên train. Temperature của từng mô hình chọn bằng log-loss trên tập hiệu chỉnh, với lưới cố định `0.75, 1, 1.5, 2, 3`; không chọn bằng tập kiểm định. Cần ít nhất 15 mẫu mỗi lớp trong train và 5 mỗi lớp trong hiệu chỉnh; nếu thiếu lớp hiệu chỉnh, hiển thị rõ chưa hiệu chỉnh. Dự báo kết hợp là trung bình cố định hai mô hình, không chọn mô hình thắng theo tập kiểm định.

Dashboard hiển thị:

- Xác suất ba lớp của logistic, DNN và kết hợp; thời điểm nến xác nhận.
- Số mẫu train / hiệu chỉnh / kiểm định; Brier ba lớp (tổng bình phương sai số, thấp hơn tốt hơn), accuracy và baseline tần suất train trên cùng tập kiểm định.
- Số mẫu, tỷ lệ đúng hướng và khoảng Wilson 95% cho từng nhóm mẫu/hướng trong tập kiểm định. Nhóm chưa đủ số mẫu chỉ hiện `chưa đủ mẫu`; không xếp hạng mẫu hiệu quả nhất trên cùng dữ liệu kiểm định.
- Trạng thái tải lịch sử, đang học, thiếu mẫu/lớp hoặc chưa vượt baseline. Các trạng thái này vẫn xuất hiện ở đầu bảng, kể cả khi phân tích ICT native đang thiếu dữ liệu.

| Input | Mặc định / ý nghĩa |
| --- | --- |
| `ML_Statistics_Enable` | `true`, dùng được trong cả Smart và DecisionSupport |
| `ML_Statistics_Timeframe` | `PERIOD_CURRENT`, đi theo chart; có thể chọn riêng |
| `ML_Statistics_History_Bars` | 6000 nến đóng, tối đa 20000 |
| `ML_Statistics_Horizon_Bars` | 4 nến, cũng là bước giữa các mẫu lịch sử |
| `ML_Statistics_Move_ATR` | 0.25 ATR cộng spread để xác định lớp |
| `ML_Statistics_Minimum_Train` | 400 mẫu train |
| `ML_Statistics_Minimum_Validation` | 80 mẫu cho **mỗi** tập hiệu chỉnh và kiểm định |
| `ML_Statistics_Minimum_Pattern` | 30 mẫu cùng nhóm/hướng trong tập kiểm định |
| `ML_Statistics_Retrain_Bars` | Huấn luyện lại sau 64 nến mới trên khung thống kê |

Khi gắn EA, bảng hiện trạng thái chờ lịch sử rồi tiến độ học. Huấn luyện chia batch 16 mẫu, tối đa khoảng 30 ms mỗi nhịp timer, cộng một lượt hiệu chỉnh/kiểm định khi kết thúc; phân tích ICT và nhánh SL/TP vẫn theo nhịp 5 giây. Nhãn nhỏ phía trên dashboard cho biết trạng thái hoặc lớp có xác suất cao nhất; xem ba lớp và kiểm định trong bảng. Khi gỡ EA, các đối tượng này được dọn cùng dashboard.

**Giới hạn bằng chứng:** dữ liệu OHLC terminal chưa có chứng nhận Bid lịch sử, spread không thay thế commission/slippage và tỷ lệ đúng hướng không đo lợi nhuận. `Brier tốt hơn` chỉ mô tả so sánh tại cửa sổ kiểm định hiện tại, không kiểm định ý nghĩa thống kê hoặc chứng minh lợi thế. Cửa sổ cuốn chiếu và khoảng Wilson không chứng minh các mẫu độc lập; các lượt xem/đổi cấu hình liên tục không tạo tập holdout cuối cùng bất khả xâm phạm. Nhánh này không tạo marker `VERIFIED` hoặc bỏ gate nguồn của pipeline snapshot ngoài.

Để nhận thay đổi trong MT5, thay đúng EX5 đã cài và gỡ/gắn lại EA; phiên bản đang chạy trong bộ nhớ không tự cập nhật từ workspace. Xác nhận version `1.04` và nhóm `ML / DL: local price statistics (both decision EAs)` trong Inputs.

Kiểm chứng mã nguồn:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tests\RunICTCoreFixtures.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tests\CompileICTMLPrediction.ps1
```

[Fixture thống kê](../Tests/ICTStatisticalLearningFixtures.mqh) kiểm tra label/horizon/spread, detector chỉ dùng prefix, FVG chỉ chạm lần đầu, purge, scaler/trọng số không đọc validation, hiệu chỉnh không đọc test, DNN thật sự học feature tổng hợp, xác suất chuẩn hóa, baseline, số mẫu và Wilson. Kiểm thử giá tổng hợp không chứng minh hiệu quả thị trường; compile không phải kiểm tra giao diện hoặc runtime MT5.

Kiểm tra ngày 2026-11-20: **409 core assertion, 0 lỗi** qua adapter C# (bao gồm fixture thống kê); **42 assertion parser snapshot, 0 lỗi**. Cả **27 chương trình MQL5** được biên dịch lại với 0 errors, 0 warnings; log dùng hậu tố `ml_statistics_20261120.compile.log`. Hai EX5 1.04 đã được chép vào thư mục `MQL5/Experts/ict_engine_EA` của terminal cài trên máy và đối chiếu SHA-256 với workspace. Bản cũ được sao lưu trong `Tests/.terminal/installed-ea-backups/ml-statistics-20261120-212724/`.

Chưa gắn/gỡ EA trên chart trong lượt này. Computer Use không kết nối được (`native pipe is unavailable`), nên chưa có xác nhận runtime/ảnh chart hoặc kết quả mô hình trên lịch sử broker. Cần gỡ/gắn lại EA để nạp 1.04; không coi việc thay file thành xác nhận phiên bản trong bộ nhớ đã đổi.

## Snapshot mô hình Python bên ngoài (tùy chọn)

Đã bổ sung luồng **fit cố định → suy luận từ nến đóng → snapshot tệp → dashboard EA**. Nhánh này hiển thị ứng viên nghiên cứu độc lập, không gán xác suất cho tín hiệu native của EA. Ridge và MLP nhận cửa sổ nến có thể dự báo R ròng cho từng target; logistic dự báo riêng xác suất TP trước SL trong horizon. Xác suất chưa được hiệu chỉnh và không phải xác suất lợi nhuận ròng dương.

Chưa có bundle Python trên dữ liệu thực được chấp nhận hoặc được bật trên chart. Bộ US500 local vẫn thiếu xác minh Bid lịch sử và độ phủ nên lệnh fit phải từ chối nguồn này. Các kết quả test dưới đây dùng giá tổng hợp và không chứng minh hiệu quả giao dịch.

## 1. Mô hình cố định và điều kiện nguồn

[Portable model](../ai/market/research/portable_model.py) đóng băng StandardScaler, trọng số Ridge hoặc MLP `(32, 16)`, cùng logistic của từng target vào JSON. Suy luận dùng thư viện chuẩn Python; không tải pickle, không cần sklearn trong tiến trình suy luận. Huấn luyện vẫn cần [phụ thuộc ML](../ai/requirements-research-ml.txt).

Bundle ghi model ID SHA-256, cấu hình detector, thứ tự feature, cửa sổ nến, grid target, phí/slippage/horizon, cutoff, thời điểm kết thúc nhãn train, số mẫu, provenance và cảnh báo hội tụ. Hash của mã đọc dữ liệu, tạo nhãn, detector và suy luận cũng được khóa. Model ID phát hiện thay đổi nội dung; nó không phải chữ ký xác thực hoặc bằng chứng mô hình có lợi thế. Thay mã hoặc line ending của mã đã khóa đòi hỏi xuất lại bundle sau khi kiểm tra.

Chỉ fit bằng ứng viên có nhãn của **mọi target kết thúc trước cutoff**. Ambiguous dùng biên bất lợi để học payoff; censored/invalid không trở thành thắng hoặc thua. Model và snapshot luôn có `scope=RESEARCH_ADVISORY`, `execution_allowed=false`. Không có cờ bỏ qua gate nguồn.

Nguồn phải đáp ứng Bid lịch sử đã xác minh, export hoàn chỉnh và coverage đã xác minh. Đây là các xác nhận do người vận hành cung cấp, không phải chứng thực tự động. Cần lưu bằng chứng và chi phí phù hợp trước khi đặt cờ; không sửa metadata chỉ để làm lệnh fit chạy được. Xem [hướng dẫn xuất và audit](RESEARCH_EXPORT.md) và [thiết kế đánh giá ML/RR](ML_RESEARCH.md).

## 2. Fit sau khi khóa nghiên cứu

Chạy từ [ai](../ai/), với nguồn thực sự đủ điều kiện:

```powershell
.\.venv\Scripts\python.exe -m market.research.predict fit --csv "C:\du-lieu\US500_M15_verified.csv" --utc-offset-minutes 120 --fit-cutoff "2026-06-01T00:00:00Z" --targets 1 1.5 2 3 4 --commission-r 0.05 --slippage-ticks 1 --model mlp --sequence-window 32 --min-mlp-train 1000 --output ".\research-models\US500_M15_mlp.json"
```

Mọi con số trên là ví dụ; không phải phí, offset lịch sử hoặc ngày khóa đã xác minh cho broker hiện có. Dùng `--model ridge` để xuất đối chứng. Lệnh không ghi đè model cũ và trả `model_id` để pin ở cả producer và EA. Chọn mô hình/cấu hình trên phần phát triển, rồi kiểm tra đoạn cuối độc lập bằng mô hình đã khóa. Một bundle fit thành công chưa phải nghiệm thu dự báo hoặc giao dịch.

## 3. Suy luận và xuất snapshot

[Producer](../ai/market/research/predict.py) đọc export mới, bỏ nến chưa đóng và replay detector từ đúng `context_start` của bundle. Toàn bộ prefix trước cutoff phải giữ nguyên, bao gồm giá, spread và volume. Không dùng một rolling tail thay cho lịch sử ban đầu: detector giữ trạng thái các pool và lần chạm đã tiêu thụ. Nguồn khác symbol/timeframe/tick/point hoặc khác broker/server đã ghi sẽ bị từ chối. Metadata được kiểm tra lại mỗi lượt.

```powershell
.\.venv\Scripts\python.exe -m market.research.predict predict --model-file ".\research-models\US500_M15_mlp.json" --expected-model-id "THAY_BANG_MODEL_ID_64_KY_TU" --csv "C:\du-lieu\US500_M15_verified.csv" --utc-offset-minutes 120 --ttl-seconds 60 --output ".\prediction-feeds\ICTML_prediction.txt"
```

Để EA đọc trực tiếp, đổi `--output` sang đường dẫn thực trong `MQL5/Files` của **đúng terminal**, hoặc Common/Files nếu đã chọn cùng scope bên EA. Producer dùng tệp tạm cùng thư mục rồi thay atomically. Không ghi vào tệp của tài khoản/terminal khác. Các thư mục model/feed trong ứng dụng đã được Git bỏ qua.

Có thể thêm `--watch-seconds 5` để producer kiểm tra lại export định kỳ. Watch **không thu thập hoặc chứng nhận dữ liệu MT5**, và không chạy mô hình mới: một luồng xuất dữ liệu riêng phải cập nhật CSV/sidecar phù hợp, giữ nguyên prefix. Khi cặp tệp chưa đồng bộ, producer báo lỗi và không gia hạn forecast cũ. Không có cơ chế tự đồng bộ realtime trong bản bổ sung này.

Chỉ ứng viên xác nhận tại nến đóng mới nhất được xét. Không có ứng viên thì `ABSTAIN`; nhiều ứng viên đồng thời cũng `ABSTAIN`, vì chọn một mẫu thắng giữa nhiều setup sẽ tạo thêm một chính sách chưa được kiểm định. Thiếu cửa sổ/feature, family hoặc hướng chưa thấy trong train cũng bị từ chối. Suy luận không tính outcome, không đọc entry tương lai và không gọi API giao dịch.

Thời hạn tối đa là đầu nến kế tiếp hoặc TTL, lấy mốc sớm hơn. Forecast mô tả chính sách entry tại open kế sau xác nhận trong nghiên cứu; nó không phải giá vào có thể thực thi ở thời điểm người dùng nhìn dashboard. Dữ liệu cũ, đồng hồ sai hoặc lỗi nguồn sẽ không tạo một dự báo mới dùng được.

## 4. Bật hiển thị trên EA

[ICTSmartDecisionEngineEA](../Experts/ICTSmartDecisionEngineEA.mq5) dùng chung [EA chính](../Experts/ICTDecisionSupportEA.mq5). Nhánh snapshot và các input dưới đây có trong **cả hai EA**:

Lệnh compile ở mục 5 chỉ tạo binary trong runtime cô lập dưới `Tests/.terminal/MQL5/Experts/ICTWorkspace/`; không thay bản EA đã cài hoặc gắn nó lên chart. Sau nghiệm thu, biên dịch/cài EA cập nhật bằng quy trình MT5 thông thường và xác nhận input mới xuất hiện trên đúng chart trước khi cấu hình.

| Input | Thiết lập |
| --- | --- |
| `ML_Prediction_Enable` | Mặc định `false`; bật thêm snapshot ngoài trong phần nghiên cứu sau bối cảnh đa khung. Khi thống kê local tắt, snapshot ngoài dùng nhãn phía trên chart |
| `ML_Prediction_File` | Tên/đường dẫn tương đối dưới MQL5/Files, mặc định `ICTML_prediction.txt` |
| `ML_Prediction_Common_Files` | Chọn đúng scope producer đang ghi |
| `ML_Prediction_Expected_Model_ID` | Copy chính xác model ID 64 ký tự từ bundle đã chọn |
| `ML_Prediction_Timeframe` | Timeframe đã fit, mặc định M15; độc lập với timeframe hiển thị chart |
| `ML_Prediction_Broker_Timezone_Verified` | Chỉ bật sau khi xác nhận offset cho nến broker hiện tại |
| `ML_Prediction_Broker_UTC_Offset_Minutes` | Offset server so với UTC, phải nằm trong −840..840 |
| `Dashboard_Width` | Mặc định 320 px; điều chỉnh độ rộng dashboard bên trái |

EA chuyển thời điểm nến server sang UTC bằng offset được xác nhận; không đoán offset bằng đồng hồ máy. Cập nhật cấu hình khi broker đổi DST. Nguồn và model phải được chọn cho chính broker đang xem; wire không tự chứng minh danh tính broker. Thiếu hoặc sai cấu hình chỉ làm snapshot ML thành unavailable; phân tích native tiếp tục.

[Bridge MQL](../Include/ICTMLPrediction.mqh) kiểm tra model pin, symbol, timeframe, đúng nến xác nhận, UTC, expiry, cutoff train, scope, số hữu hạn và một bản ghi đầy đủ. File thiếu, partial, sai schema, hết hạn hoặc đang bị thay sẽ không giữ snapshot ML cũ như một forecast hợp lệ. Snapshot đi vào [dashboard](../Include/ICTUnifiedRenderer.mqh) và một nhãn nhỏ trên chart, đặt phía trên dashboard trái. Nhãn hiện timeframe, trạng thái/hướng và `P(TP trước SL)` nếu feed có xác suất; luôn đánh dấu chưa hiệu chỉnh. Khi feed không hợp lệ, nhãn cho biết trạng thái lỗi và tooltip có lý do. Đây là xác suất do pipeline nghiên cứu cung cấp, không phải dự báo được tính bên trong EA. Nó không sửa `g_decision`, journal, target/stop hoặc điều kiện rủi ro; đường quản lý SL/TP hiện hữu không nhận dữ liệu ML.

## 5. Hợp đồng wire và kiểm chứng

Một dòng ASCII có LF cuối, 22 trường phân cách bằng `;`:

```text
ICTML1;model_id;symbol;timeframe;generated_utc;asof_utc;expires_utc;fit_cutoff;train_end;candidate_id;family;direction;status;reason;target_r;expected_net_r;p_tp;train_n;RESEARCH_ADVISORY;0;VERIFIED;END
```

Timestamp là Unix UTC nguyên dương. `NA` biểu diễn số không có; `p_tp` có thể thiếu khi train chỉ có một lớp. `ABSTAIN` không được mang selected target. Candidate không có dùng ID/family `-` và hướng `0`. Cả Python và MQL từ chối dòng thiếu terminator, dòng thứ hai, quyền execution khác 0 hoặc model không khớp pin.

Kiểm tra Python từ [ai](../ai/):

```powershell
.\.venv\Scripts\python.exe -m unittest market.test_portable_model market.test_prediction_bridge market.test_prediction_pipeline
```

Kiểm tra parser native qua chuyển đổi cú pháp C# không tài khoản, rồi compile trong runtime cô lập từ thư mục gốc:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tests\RunICTMLPredictionFixtures.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tests\CompileICTMLPrediction.ps1
```

Đã kiểm tra parity trọng số với sklearn, không import sklearn khi infer, cutoff/source/code/prefix gate, snapshot stale/partial, ghi atomically và đường nối end-to-end trên giá tổng hợp. Parser có 42 assertion không tài khoản; fixture MQL biên dịch với 0 errors, 0 warnings. Đây không phải test runtime MT5, file IO trong terminal, hiển thị chart hoặc backtest thị trường; các phần đó cần nghiệm thu riêng trước khi sử dụng thực tế.

Lượt kiểm tra tổng hợp gồm **130 test Python đã pass**. Bản ghi tổng hợp do Python serializer tạo cũng được parser MQL sản xuất chấp nhận qua adapter C#, không chỉ fixture chuỗi tự viết.
