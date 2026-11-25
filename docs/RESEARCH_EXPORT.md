# Xuất lịch sử nến cho nghiên cứu tín hiệu thống kê

[ExportResearchCandles.mq5](../Tests/ExportResearchCandles.mq5) là script xuất dữ liệu riêng. Script không gửi lệnh, không thay EA và không thay logic ICT. Hiện chưa có kết quả xác suất từ dữ liệu thật chỉ nhờ bổ sung script này.

## 1. Chuẩn bị và chạy xuất

1. Trong MetaEditor của terminal có lịch sử broker cần nghiên cứu, tạo thư mục `MQL5/Scripts/ICTResearch`, chép và biên dịch [script](../Tests/ExportResearchCandles.mq5). Không chép đè EA đang chạy.
2. Dùng một chart trống dành cho nghiên cứu, chạy script từ Navigator → Scripts. Không cần thay đổi cài đặt giao dịch của các EA.
3. Chọn tên symbol chính xác của broker, ví dụ `US500`; chọn khoảng ngày theo **giờ máy chủ broker**. `Research_From` bao gồm mốc đầu; `Research_To` không bao gồm mốc cuối. `Research_To=0` cố định mốc cuối bằng `TimeCurrent()` khi script bắt đầu.
4. Giữ `Export_All_Timeframes=true` để xuất M1, M15, H1 và D1 thành bốn cặp tệp riêng; hoặc chọn `false` và một trong bốn khung tại `Research_Timeframe`.
5. Bắt đầu bằng một khoảng ngắn để kiểm tra quyền xuất và dữ liệu. Sau đó xuất khoảng nghiên cứu đủ dài. Bảo đảm giới hạn **Max bars in chart** của terminal đủ chứa lịch sử cần lấy; dữ liệu ngoài giới hạn này có thể khiến API từ chối yêu cầu.
6. Sau khi hoàn tất, đọc tab Experts và sidecar; lấy cặp CSV + metadata từ **File → Open Data Folder → MQL5 → Files → ICTResearch**. Khi chạy trong tester, sandbox của tester có vị trí khác; không tự suy ra rằng tệp nằm trong terminal đang giao dịch.

Script có thể chọn symbol tạm thời trong Market Watch để gọi API và cố gắng trả lại trạng thái lựa chọn lúc đầu. Terminal có thể giữ symbol nếu chart hoặc thành phần khác đang dùng nó.

### Các input cần hiểu

| Input | Ý nghĩa |
| --- | --- |
| `Research_Symbol` | Tên symbol tại broker; không suy ra từ chart hiện tại |
| `Research_From`, `Research_To` | Khoảng thời gian máy chủ, tối đa 100 năm; chỉ giữ nến đã đóng trước mốc cuối hiệu lực |
| `Chunk_Days` | 1–31 ngày mỗi lần gọi API, mặc định 7; không nạp toàn bộ lịch sử vào một mảng |
| `Copy_Attempts`, `Retry_Delay_Milliseconds` | Số lần thử hữu hạn và khoảng chờ khi lịch sử đang tải/đồng bộ |
| `Price_Type` | Chỉ chấp nhận `unknown`, `bid`, `last`; mặc định `unknown` |
| `Price_Type_Historically_Verified` | Chỉ đặt `true` khi đã xác minh loại giá cho **toàn bộ khoảng lịch sử**; nhãn `bid` hoặc `last` bắt buộc có xác nhận này |
| `Export_Tag` | Hậu tố giúp phân biệt các lần xuất; ký tự không an toàn được đổi thành `_` |
| `Overwrite_Existing_Export` | Mặc định `false`; có tệp trùng thì từ chối. Nên dùng tag mới để lưu nguyên bằng chứng cũ |

Lựa chọn `Price_Type=unknown` vẫn cho phép thu thập và kiểm toán dữ liệu. Không được dùng dữ liệu đó để tuyên bố kết quả có thể giao dịch trước khi xác minh loại giá. `current_chart_mode` trong metadata chỉ là thông tin hiện tại, không tự xác nhận lịch sử.

Theo [tài liệu CopyRates](https://www.mql5.com/en/docs/series/copyrates), terminal có thể bắt đầu tải/xây dựng dữ liệu khi script yêu cầu lịch sử; kết quả có thể chưa đầy đủ trong lần gọi đầu. Nếu nhận `INCOMPLETE`, kiểm tra ngày, lịch sử, giới hạn bars và đồng bộ rồi xuất lại bằng tag mới. Script dừng ở chunk lỗi đầu tiên, không âm thầm bỏ qua để tiếp tục.

## 2. Tệp đầu ra

Tên có dạng:

```text
US500_M15_20200101T000000_20261118T000000_initial_audit.csv
US500_M15_20200101T000000_20261118T000000_initial_audit.csv.meta.json
```

CSV UTF-8, dấu phẩy, tăng dần theo thời gian:

```csv
timestamp,open,high,low,close,volume,spread_points
```

- `timestamp` có dạng `YYYY-MM-DDTHH:MM:SS`, là **thời gian mở nến theo máy chủ broker**, không có hậu tố `Z` và không được tự coi là UTC.
- Giá OHLC lấy từ `MqlRates`; không thay bằng một đường giá tổng hợp khác.
- `volume` là **tick volume**, không phải khối lượng giao dịch thực.
- `spread_points` lấy từ trường spread của nến; không phải chuỗi bid/ask có thể khớp tại entry/exit. Muốn xử lý thứ tự chạm TP/SL hoặc biến động spread trong nến cần dữ liệu tick phù hợp. Xem [cấu trúc MqlRates](https://www.mql5.com/en/docs/constants/structures/mqlrates).
- Không có nến mở hiện tại hoặc nến có thời gian đóng danh nghĩa vượt quá `effective_end`. `actual_last` là mốc **mở** của nến cuối, không phải mốc đóng.
- Không điền nến còn thiếu, không sửa OHLC, không tự phân loại ngày nghỉ hoặc khoảng đóng cửa.

Metadata có `schema_version=1`, tên CSV, broker/server, symbol/khung, số giây mỗi nến, point/tick size/digits, loại giá, khoảng yêu cầu và khoảng xuất thực tế, số hàng, trạng thái API, lỗi và số khoảng thời gian không có nến. Không ghi số tài khoản hoặc mật khẩu.

### Cách đọc trạng thái hoàn tất

`complete=true` chỉ có nghĩa:

- Từng chunk được trả về trong trạng thái đồng bộ và số bars API bằng số bars `Bars()` của chính khoảng đó.
- Tất cả chunk đã xử lý, CSV ghi được, các hàng hợp lệ và tăng dần, có ít nhất một nến.
- Ngày bắt đầu không nằm trước mốc lịch sử đầu tiên mà server thông báo.

Nó **không chứng minh** broker không thiếu lịch sử, lịch giao dịch đầy đủ, chuỗi tick đủ, chi phí đúng hoặc khoảng đó có lợi thế giao dịch. Vì vậy metadata luôn có `coverage_verified=false` và `gaps_classified=false`. `gap_count` đếm khoảng cách lớn hơn một chu kỳ nến; `gap_missing_periods_unclassified` đếm các chu kỳ danh nghĩa không có bar. Đóng cửa cuối tuần và mất dữ liệu đều nằm trong nhóm chưa phân loại này. Chỉ được xác nhận độ phủ sau khi đối chiếu lịch giao dịch của broker và kiểm toán nguồn.

`complete=false` hoặc `status=incomplete`: không đưa tệp vào huấn luyện/kiểm định. Tệp có thể chứa tiền tố đã xuất thành công để chẩn đoán. Tệp mang đuôi `.partial.*`, hoặc CSV không có sidecar phù hợp, cũng chưa dùng được. Khi ghi đè được chọn rõ ràng, sidecar cũ được vô hiệu hóa trước khi công bố CSV mới để tránh mô tả nhầm dữ liệu nếu tiến trình bị gián đoạn.

Các cờ đồng bộ và ngày đầu API chỉ mô tả trạng thái được server/terminal cung cấp; xem [History Database Properties](https://www.mql5.com/en/docs/constants/tradingconstants/enum_series_info_integer). Kiểm tra bằng SHA-256 và xác nhận nguồn phải được lưu tại bước nạp dữ liệu nghiên cứu.

## 3. Những thông tin phải bổ sung khi nạp nghiên cứu

1. **Timezone hoặc UTC offset lịch sử đã xác minh** của server cho khoảng xuất. Không lấy chênh lệch giờ hiện tại để áp cho nhiều năm; nếu có DST hoặc đổi quy ước giờ, cần quy tắc theo giai đoạn.
2. **Loại giá lịch sử** `bid`/`last` và bằng chứng xác minh. Không suy từ spread dương hoặc tên sản phẩm.
3. **Phí và giả định khớp lệnh**: commission, spread tại thời điểm giao dịch, slippage, contract/point/tick size lịch sử. Sidecar ghi commission và slippage là `unknown`; các thông số hợp đồng khác chỉ là snapshot hiện tại và không phải chứng nhận điều kiện quá khứ.
4. **Kiểm toán khoảng không có nến** và các biên thiếu dữ liệu. Không coi mọi gap là mất dữ liệu, cũng không coi mọi gap là thị trường đóng cửa.
5. **Giữ cặp nguồn nguyên gốc**, ghi hash khi nạp, chỉ tạo dữ liệu chuẩn hóa trong bước riêng có truy vết. Nến M1 hỗ trợ kiểm tra đường đi nhưng không loại hết trường hợp TP và SL cùng chạm trong một nến.

Các tệp cache `.hcc` mang tên năm chỉ cho biết cache tồn tại, không chứng minh có đủ dữ liệu của năm đó. Đường xuất được hỗ trợ là API của terminal đã khởi tạo và có lịch sử thích hợp. Không giải mã trực tiếp cache thành bộ nến được mặc nhiên coi là chuẩn. Collector chỉ kết nối vào terminal đang mở, không đăng nhập tài khoản và không tự chạy giao dịch.

## 4. Audit và replay offline

Chạy từ thư mục `ai/` bằng môi trường Python của dự án. Giữ nguyên CSV và sidecar gốc; mỗi báo cáo JSON được tạo mới, không ghi đè. [Lệnh nghiên cứu](../ai/market/research/run.py) chỉ dùng thư viện chuẩn, không kết nối MT5 hay Django.

```powershell
cd ai
.\.venv\Scripts\python.exe -m market.research.run --csv "C:\du-lieu\US500_M15.csv" --utc-offset-minutes 120 --output ".\research-runs\US500_M15_audit.json"
```

Chỉ dùng `--utc-offset-minutes 120` nếu đã xác minh UTC+2 đúng cho **toàn bộ khoảng xuất**. Với quy tắc giờ lịch sử có DST, dùng `--source-timezone` kèm tên IANA đã xác minh và cài `tzdata` nếu cần. Không dùng offset hiện tại để suy ra offset nhiều năm trước. `audit` kiểm tra định dạng, số hàng, kích thước/hash CSV khi sidecar có, thứ tự nến, OHLC, spread và gap; nó cho phép `Price_Type=unknown`. Nếu export không hoàn tất, chỉ chế độ audit mới nhận `--allow-partial`.

Để chạy replay thăm dò, phải xuất lại với `Price_Type=bid` và `Price_Type_Historically_Verified=true` **sau khi** kiểm tra nguồn giá lịch sử. Chỉ đổi nhãn trong sidecar không phải xác minh nguồn. Phải đặt giả định phí và slippage rõ ràng:

```powershell
.\.venv\Scripts\python.exe -m market.research.run --mode evaluate --csv "C:\du-lieu\US500_M15.csv" --utc-offset-minutes 120 --commission-r 0.05 --slippage-ticks 1 --target-r 2 --horizon-bars 16 --output ".\research-runs\US500_M15_exploratory.json"
```

`commission-r` là phí khứ hồi theo đơn vị R của từng mẫu, còn spread từ nến được phản ánh qua giá vào/ra mô phỏng; không trừ spread lần hai. Các giá trị trong ví dụ là cú pháp, **không phải chi phí đã xác minh cho broker**. Replay xuất tất cả ứng viên A/B/C, nhãn TP/SL/timeout/ambiguous/censored, phép chia thời gian purge theo `label_end`, thống kê ngoài mẫu và hash mã/cấu hình/nguồn. Mặc định target +2R trước phí và horizon 16 nến M15; báo cáo không thay thế backtest tick hoặc kiểm định logic EA hiện hành. Vì exporter để `coverage_verified=false`, báo cáo đánh dấu `EXPLORATORY_SOURCE_UNVERIFIED`, và `usable_for_shadow=false` kể cả khi thống kê mẫu nhìn có vẻ tốt.

Để so sánh thêm hồi quy tuyến tính, logistic và MLP, cài phụ thuộc tùy chọn rồi thêm `--ml` vào lệnh evaluate:

```powershell
.\.venv\Scripts\python.exe -m pip install -r requirements-research-ml.txt
.\.venv\Scripts\python.exe -m market.research.run --mode evaluate --ml --csv "C:\du-lieu\US500_M15.csv" --utc-offset-minutes 120 --commission-r 0.05 --slippage-ticks 1 --output ".\research-runs\US500_M15_ml.json"
```

Các mẫu, cảnh báo hội tụ, điểm so với baseline và phiên bản thư viện nằm trong trường `ml` của báo cáo. Mỗi mô hình so với baseline trên cùng các hàng mà mô hình đó dự báo được; MLP có thể có ít hàng hơn vì yêu cầu ít nhất 200 nhãn train theo mặc định. Có thể bổ sung `--rr-targets 1 1.5 2 3 4` để chọn target theo R ròng dự báo; `--rr-model mlp --rr-sequence-window 32` bật mạng feedforward nhận cửa sổ nến đóng. Kết quả nằm trong `rr_study`, có hành động `ABSTAIN` và giữ nguyên gate dữ liệu/holdout. Xem [thiết kế và giới hạn nghiên cứu ML](ML_RESEARCH.md). Các fold thăm dò chưa thay thế holdout cuối và không dùng để vận hành shadow.

Để dành một đoạn cuối làm holdout, thêm ví dụ `--holdout-cutoff "2026-08-01T00:00:00+00:00"` vào lệnh ML. Ở chế độ mặc định, detector và nhãn của khoảng từ cutoff trở đi không được xuất; `ml.holdout.status` là `SEALED`. Chọn mốc trước khi khảo sát outcome khoảng đó. Mốc chỉ là ví dụ và không mặc nhiên phù hợp với dữ liệu của bạn.

Sau khi khóa định nghĩa, chi phí, cấu hình và lựa chọn trên tập phát triển, chạy lại với cùng cutoff và thêm `--evaluate-holdout`, dùng tên tệp output mới. Mô hình được fit một lần từ outcome kết thúc trước cutoff; phần `ml.holdout` chứa dự báo, metrics và bảng reliability riêng. Dùng lại holdout để chọn hay điều chỉnh sẽ khiến nó không còn là kiểm định độc lập. Công cụ không ghi nhận việc bạn đã xem dữ liệu trước đó và không cưỡng chế đăng ký trước.

`ml.calibration.by_model` báo reliability và baseline trên đúng các hàng của từng mô hình; `common_rows` chỉ giữ giao tập có cả dự báo logistic và MLP để so sánh công bằng. Đây là đánh giá mô tả, không fit bộ hiệu chỉnh xác suất và không chứng nhận hiệu quả giao dịch.

[Collector Python tùy chọn](../ai/market/research/collect_mt5.py) dùng gói trong [requirements-research-mt5.txt](../ai/requirements-research-mt5.txt), chỉ bám vào terminal **đã mở** và symbol **đã có trong Market Watch**; `--probe` kiểm tra kết nối chỉ đọc. Collector gắn `price_type_historically_verified=false` vì chart mode hiện tại không chứng nhận loại giá của toàn bộ lịch sử, nên đầu ra của nó phù hợp cho audit trước khi có xác minh độc lập.

## 5. Kiểm tra bản bổ sung

- Đã biên dịch riêng script bằng MetaEditor trong runtime cô lập của dự án: **0 errors, 0 warnings**.
- Bộ test offline kiểm tra nguồn, collector, detector, nhãn kết quả, walk-forward, calibration, ML, lưới RR và cửa sổ nến; chạy từ thư mục [ai](../ai/): `.\.venv\Scripts\python.exe -m unittest market.test_research_data market.test_research_collector market.test_research_candidates market.test_research_evaluation market.test_research_ml market.test_research_calibration market.test_research_rr market.test_research_sequences market.test_research_rr_integration`. Test ML cần cài phụ thuộc tùy chọn.
- Collector Python đã xuất và audit lịch sử US500 M15 trên terminal đang mở; chưa xác nhận độ phủ, giá Bid lịch sử hoặc kết quả mô hình thực tế. Chi tiết tại [tài liệu nghiên cứu ML](ML_RESEARCH.md#4-xuất-dữ-liệu-thực-và-giới-hạn-audit-hiện-tại). Script MQL riêng chưa được xác nhận runtime với lịch sử broker.
- Script không sử dụng API đặt lệnh và không sửa các EA hiện có.
