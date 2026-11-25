# Chẩn đoán thiếu tín hiệu và bản DL 1.10

Ngày 23/11/2026. Tiếp nối [bản tổng hợp 1.09](ANALYTICAL_CONSENSUS_20261123.md), lần này đã đọc snapshot của terminal đang chạy, lấy nến trực tiếp qua kết nối MT5 chỉ đọc, huấn luyện DNN bằng thuật toán production và replay trên một đoạn riêng sau train/calibration/test.

## Nguyên nhân quan sát được

SHA256 của các EA đã cài khớp binary 1.09 của workspace. Thiếu tín hiệu không chỉ do người dùng chưa chép file. Trong các snapshot đọc được, EURUSD H1 có HTF giảm nhưng MTF trung tính; EURUSD M5 có HTF giảm và MTF tăng; XAUUSD có HTF/MTF trung tính; GBPUSD thiếu cấu trúc HTF xác nhận. Một số snapshot còn ghi lỗi khôi phục journal SMT. Bộ phân tích 1.09 tái sử dụng cổng bối cảnh chặt cho cả ứng viên sớm nên dừng trước khi xét dự báo DL.

Bộ tổng hợp cũ còn lấy trung bình cả những nhóm đã quan sát nhưng không có sự kiện: không có sweep và không có phản ứng vùng giá đều đóng góp điểm trung tính. Khi chỉ có đường giá, nến và DNN đang mang thông tin, hai nhóm trung tính làm giảm điểm trung bình. Ngoài ra, renderer 1.09 chỉ giữ mũi tên của nến cuối; một tín hiệu ở vài nến trước không còn nhìn thấy.

Kiểm tra mô hình trên dữ liệu thật cho thấy không nên chỉ bỏ bộ lọc chất lượng rồi coi mọi DNN là tốt. Trên M5, cả 10 mô hình fit và hiệu chỉnh được, nhưng chỉ 5 mô hình có Brier riêng DNN thấp hơn prior. Trên M15 có 4/10, còn H1 có 0/10 trong lần chụp dữ liệu này. Các con số mô tả đúng cửa sổ kiểm định này, chưa phải kiểm định ý nghĩa thống kê hoặc bằng chứng lợi thế.

## Cách sửa trong 1.10

Logic tính bối cảnh HTF/MTF/LTF và bộ xác nhận native được giữ lại. Tầng **phân tích sớm bằng DL** được phép xuất ứng viên khi bối cảnh trung tính, xung đột hoặc thiếu xác nhận; trạng thái đó xuất hiện trong nhãn/tooltip/dashboard. Có thể bật lại `Analysis_Strict_MTF=true` để dùng cổng đồng thuận chặt cho cả tầng này. Journal SMT lỗi không tự ngăn một mô hình giá đã học hợp lệ đưa ra đánh giá tham khảo, nhưng quyết định native vẫn giữ điều kiện của nó.

Mặc định mới là **55/100, hai nhóm có thông tin định hướng, một nhóm ủng hộ**, đồng thời **bắt buộc có DNN**. DNN phải được fit, có hiệu chỉnh, đúng khung/nến, xác suất hữu hạn và tổng bằng 1; các nhãn kiểm định phải kết thúc trước thời điểm đánh giá. DNN ưu tiên đi ngang hoặc chênh lệch tăng/giảm dưới 0,04 thì không tạo mũi tên hướng. Không dùng một luật kỹ thuật đổi tên thành DL khi mô hình chưa sẵn sàng.

Giá trị nhóm gần 0 (`abs(v)<0,025`) vẫn được hiển thị nhưng không tham gia mẫu số định hướng. Nhóm phản đối vẫn kéo điểm xuống. DNN không vượt prior hoặc có feature ngoài miền train được gắn **DL THAM KHẢO**: trọng số nhóm DL còn 0,35 và khoảng cách của điểm tổng hợp đến 50 được nhân 0,65. Có thể tắt hoàn toàn trường hợp này bằng `Analysis_Allow_Experimental_DL=false`.

Hướng phân tích lấy từ lớp tăng/giảm được DNN ưu tiên, khi lớp đó lớn hơn lớp đi ngang. Điểm gốc vẫn là trung bình bằng chứng có dấu; bối cảnh hiện hữu cộng/trừ tối đa 3 điểm HTF và 2 điểm MTF trước phần giảm điểm thử nghiệm. Các hệ số này là lựa chọn thiết kế cố định, chưa được chọn bằng lợi nhuận trên đoạn replay.

### Lịch sử mũi tên và chống dùng tương lai

`ML_Statistics_Replay_Reserve_Bars=64` giữ 64 nến cuối bên ngoài cả train, calibration và test khi fit. Sau đó, EA có thể tái dựng tối đa 60 nến gần nhất bằng model đã cố định. Mỗi nến chỉ được dựng nếu nhãn test của model đã đóng trước thời điểm đó. Bối cảnh lịch sử dùng prefix của các khung trên và detector cấu trúc hiện hữu; không lấy bias hiện tại gán cho quá khứ.

Phần dựng lịch sử chỉ dùng giá, DNN và bối cảnh có thể tái tạo đúng thời điểm. Không đem snapshot SMT hoặc vòng đời liquidity/OB hiện tại gán cho các nến cũ. Mũi tên replay có tooltip riêng, không được coi là nhật ký dự báo live bất biến hoặc kết quả giao dịch.

## Kiểm tra 10 mã × 3 khung

Nguồn là terminal MT5 đã kết nối; chỉ chọn mã đã có trong Market Watch, không đăng nhập, không đổi tài khoản, không gửi lệnh. Mỗi mã lấy 6.000 nến đã đóng cho M5/M15/H1 và lịch sử khung trên. [`copy_rates_from_pos` với chỉ số 1](https://www.mql5.com/en/docs/python_metatrader5/mt5copyratesfrompos_py) bỏ nến 0 đang hình thành.

Mỗi model fit trên 5.936 nến đầu. Bộ tạo mẫu production chia theo thời gian được 958 mẫu train, 221 calibration và 294 test, có purge theo quy tắc hiện hữu. 64 nến cuối được dùng để đếm ứng viên sau khi khóa model. Thuật toán MQL thuần được thực thi qua adapter C#; chưa phải chạy native EA trên chart hoặc một backtest lợi nhuận.

| Mã | M5: ứng viên DL | M15: ứng viên DL | H1: ứng viên DL |
| --- | ---: | ---: | ---: |
| EURUSD | 9 | 10 | 16 |
| GBPUSD | 8 | 9 | 9 |
| USDJPY | 11 | 9 | 14 |
| USDCHF | 8 | 6 | 8 |
| AUDUSD | 10 | 3 | 10 |
| USDCAD | 23 | 6 | 5 |
| XAUUSD | 4 | 20 | 11 |
| XAGUSD | 13 | 10 | 10 |
| US500 | 28 | 15 | 8 |
| USTEC | 16 | 25 | 18 |
| **Tổng trên 640 nến/khung** | **130** | **113** | **109** |

Tổng cộng **352 ứng viên trên 1.920 nến**, trong đó **268 ứng viên DL tham khảo** từ model chưa vượt prior hoặc có cảnh báo miền feature. Không diễn giải 352 là số giao dịch, số thắng hay tín hiệu đủ điều kiện native. Các mã gồm sáu cặp FX, hai kim loại và hai chỉ số đang có trong profile; không gọi cả mười mã là mười cặp ngoại hối.

Cách đánh giá chặt 1.09 tạo tương ứng **0 / 2 / 0 ứng viên trên M5 / M15 / H1** với cùng các đầu vào chung được replay. So sánh này sử dụng giá, DNN và MTF; không phải replay đầy đủ mọi trạng thái lịch sử SMT/liquidity/OB của EA. Số mũi tên trên chart live có thể khác do cửa sổ 60 nến, thời điểm fit, dữ liệu mới và bằng chứng native bổ sung.

Kết quả có thể kiểm tra trong [CSV tổng hợp](../Tests/Reports/ICT_ANALYTICAL_MARKET_20261123.csv), [JSON có phương pháp và hash nguồn](../Tests/Reports/ICT_ANALYTICAL_MARKET_20261123.json) và [runner production MQL qua C#](../Tests/RunICTAnalyticalMarketReplay.ps1). Dữ liệu nến và manifest SHA256 nằm trong `Tests/.terminal/analysis-market-20261123/`. Đây là dữ liệu chart/cached history của terminal kết nối, chưa được nâng cấp thành chứng nhận Bid lịch sử hoặc coverage cho nghiên cứu lợi nhuận.

## Hiển thị và chẩn đoán trên MT5

Bản 1.10 thêm badge DL luôn nhìn thấy khi bật hiển thị: trạng thái đang học hoặc ba tỷ lệ tăng/giảm/ngang. Mũi tên lịch sử được vẽ ở tọa độ giá/nến thực; các ứng viên thử nghiệm dùng màu cam và tooltip phân biệt. Điểm tổng hợp là điểm bằng chứng, không phải xác suất thắng.

`Analysis_Export_Diagnostics=true` ghi CSV riêng cho từng chart vào `MQL5/Files/ICTAnalysisEvidence/`, gồm build, model ready, hiệu chỉnh, xác suất DNN, điểm, số mũi tên lịch sử và lý do native. `Analysis_Save_Chart_Evidence=true` lưu một PNG chỉ chứa chart sau khi DL sẵn sàng. Nhờ vậy có thể đối chiếu việc thực sự vẽ trên terminal, kể cả khi kênh điều khiển giao diện không kết nối.

Hai EA 1.10 đã được biên dịch **0 lỗi / 0 cảnh báo**, sao lưu và cập nhật đúng vị trí đã cài; SHA256 sau copy khớp workspace. [Manifest sao lưu](../Tests/.terminal/installed-ea-backups/dl-1_10-20261123-085456/manifest.json). Các chương trình fixture, indicator và script replay native liên quan cũng biên dịch sạch. **568 kiểm tra lõi đạt**.

**Trạng thái nghiệm thu ảnh:** Computer Use báo `native pipe is unavailable`. Một lần chạy replay chart bằng terminal cô lập nạp được script nhưng không tạo bằng chứng hoàn tất trong 180 giây; đã yêu cầu đóng đúng tiến trình cô lập. Vì vậy chưa ghi nhận PASS về ảnh native/live. Chỉ xác nhận hình ảnh khi đọc được PNG và CSV mới từ EA 1.10 đã nạp lại; việc chép EX5 không tự chứng minh các chart đang dùng binary mới trong bộ nhớ.

## Inputs cần kiểm tra khi nạp lại

| Input | Mặc định 1.10 |
| --- | --- |
| `Analysis_Enable`, `Analysis_Show_On_Chart` | true |
| `Analysis_Minimum_Score` | 55 |
| `Analysis_Minimum_Groups` | 2 |
| `Analysis_Minimum_Supporters` | 1 |
| `Analysis_Require_Deep_Learning` | true |
| `Analysis_Strict_MTF` | false, chỉ áp dụng tầng phân tích sớm |
| `Analysis_Allow_Experimental_DL` | true, có nhãn và giảm trọng số |
| `Analysis_Minimum_DL_Margin` | 0,04 |
| `Analysis_History_Bars` | 60 |
| `ML_Statistics_Replay_Reserve_Bars` | 64 |

Chart hoặc tệp `.set` lưu Inputs cũ có thể giữ 60/3/2 và cần chỉnh lại. DNN cần hoàn thành việc học qua timer sau khi gắn EA; badge và CSV cho biết tiến độ, không vẽ một tín hiệu giả để lấp thời gian chờ.
