# Liquidity sweep rõ hơn, MSS sau sweep và ngữ cảnh DL — bản 1.07

Áp dụng cho cả [Smart EA](../Experts/ICTSmartDecisionEngineEA.mq5) và [DecisionSupport EA](../Experts/ICTDecisionSupportEA.mq5). Giữ nguyên wrapper, detector pool, snapshot/bridge, score, điều kiện duyệt tín hiệu và cơ chế quản lý lệnh hiện hữu. Phần bổ sung chỉ đọc sự kiện native để giải thích trên chart.

## Bổ sung 1.07 ngày 22/11 — untouched và first-touch

Đường SSL/BSL chưa bị quét/phá theo vòng đời native nay có nét liền 3 px, nhãn Semibold, đen trên nền sáng và trắng trên nền tối. Đầu dashboard có [mô hình thứ tự chạm riêng](ML_PREDICTION_EA.md), có ngữ cảnh xu hướng dài hạn D1 và gate dữ liệu/kiểm định. Nhánh này khác dự báo hướng giá tại reclaim mô tả bên dưới; không dùng xác suất DNN giá đóng để gọi xác suất chạm pool. Xem [định nghĩa, nghiên cứu và giới hạn OHLC](DEEP_LEARNING_ADVISORY_20261120.md).

## Cập nhật 22/11/2026 — dashboard, mũi tên và H1

- `Dashboard_Y=60` và `Position_Risk_Y=60` nâng hai bảng lên 20 px so với bản 1.05. Nếu chart/template còn lưu 80, sửa riêng hai Inputs này thành 60; không cần Reset tham số phân tích/rủi ro. Dashboard đã kéo thả tiếp tục dùng vị trí trong phiên, gắn lại EA để trở về vị trí Inputs.
- `Sweep_Focus_Arrow_Size=1` giảm mũi tên tập trung từ width 3 xuống 1, cho phép chỉnh 1–3. Nhãn vẫn cỡ 10 và đoạn pool/râu vẫn dày 3.
- `Sweep_Focus_Prefer_H1=true` xếp **thuận H1 trước → reclaim mới nhất → khung nguồn lớn hơn**. SSL có mũi tên tăng thuận H1 tăng; BSL có mũi tên giảm thuận H1 giảm. Mũi tên ngược H1 còn trong các vị trí được chọn dùng xám; H1 trung tính/thiếu dữ liệu không được gắn nhãn thuận. Tắt tùy chọn trả về thứ tự thời gian như bản 1.05.
- H1 dùng đúng detector HH/HL, LH/LL đã có, 120 nến đóng và `Range_Swing_Left/Right`, cố định theo thời điểm xác nhận reclaim của từng sự kiện. Không lấy hướng H1 hiện tại để chấm lại quá khứ. H1 chưa đóng bị loại; thiếu 120 nến, OHLC không hợp lệ hoặc thiếu giờ đóng gần nhất thì ghi chưa đủ dữ liệu/cấu trúc. Các khoảng nghỉ ở sâu trong lịch sử không được tự điền nến.
- Nhãn, tooltip và đầu dashboard ghi trạng thái thuận/ngược/trung tính/thiếu H1; tooltip ghi thời điểm đóng của H1 được dùng. Dashboard trình bày sweep ưu tiên đầu tiên, có thể là sự kiện cũ hơn khi thuận H1. Các sweep khác vẫn giữ trong snapshot và có thể có nhãn legacy ngoài nhóm tập trung.
- Không thêm thư mục hoặc module; tiếp tục sửa trong các thành phần và bộ fixture đang có. H1 chỉ là ưu tiên hiển thị, không thêm veto hoặc trọng số vào lệnh.

## Hành vi trên biểu đồ

- Đoạn ngang **BSL/SSL liquidity** dày 3 pixel tại đúng mức pool native, kết thúc tại nến có râu quét. Ưu tiên bắt đầu từ một lần chạm mức thực trong lịch sử gần; nếu không tìm được thì kéo lùi tối đa 20 nến làm mốc hiển thị, không khẳng định đó là thời điểm hình thành pool.
- Râu quét được tô đậm, mũi tên nhỏ chỉ vào cực trị, nhãn **Nến sweep BSL/SSL #n | TF | trạng thái H1** dùng cỡ chữ thật 10. Màu tự điều chỉnh theo nền chart, nhãn đi qua bộ tránh va chạm dashboard/nhãn khác.
- Mặc định chỉ nhấn mạnh **3 râu nến khác nhau**, ưu tiên thuận H1 rồi mới nhất. Nhiều pool cùng bị quét trên một râu được gộp, ưu tiên pool nguồn khung lớn hơn nếu cùng thời điểm xác nhận. Dữ liệu của các pool còn nguyên trong snapshot; nhãn nhỏ trùng trên râu đó được thay bằng nhãn tập trung.
- MSS có đường swing nét đứt và nhãn riêng: chờ, đã xác nhận, thiếu displacement, hết hạn hoặc không xác nhận. Nhãn MSS ghi khung nến sự kiện để phân biệt với điều kiện structure ở khung khác trong engine.
- Rê chuột lên đường/mũi tên/nhãn để xem pool ID, event ID, mức giá, thời gian wick/reclaim/MSS, H1 và ML/DL. Thông tin sweep được ưu tiên cũng đứng đầu dashboard, trước phần thống kê ML dài.
- Chỉ sự kiện `LIQUIDITY_SWEEP` **đã đóng và reclaim** mới được nhấn mạnh. False breakout, breakout và retest giữ nguyên loại; không đổi tên chúng thành sweep. Nhãn ứng viên của hệ thống cũ vẫn có thể hiện riêng.

Chart vẫn có thể ẩn nhãn khi thiếu chỗ, nhưng đoạn pool, râu quét và mũi tên là các object theo thời gian/giá độc lập. Các object mới dùng cùng prefix sở hữu của EA nên được dọn khi gỡ EA. Nút Algo Trading chỉ bật/tắt quyền giao dịch, không gỡ EA khỏi chart.

## Điều kiện MSS bổ sung, không thay đổi MSS native

Engine đã có `Range_Require_MSS=true` và `Range_Require_Displacement=true` trong [inputs hiện tại](../Include/ICTRangeInputs.mqh). Bản 1.05 **không thay hoặc bổ sung veto vào tín hiệu cũ**. Module mới kiểm tra một tiêu chí giải thích chặt chẽ trên **khung nến sweep**, độc lập với cấu trúc MTF được engine dùng để duyệt thiết lập.

Ví dụ BSL:

1. Lấy sự kiện quét BSL từ snapshot: wick vượt mức, nến xác nhận đóng lại bên dưới mức pool.
2. Cố định swing low gần nhất đã có đủ nến xác nhận bên phải **trước khi nến wick bắt đầu**. Không dùng đáy vừa được tạo sau sweep để viết lại mức MSS.
3. Nếu swing đã bị đóng xuyên trước hoặc ngay nến xác nhận sweep, ghi “swing đã bị phá”; không gọi đó là MSS xảy ra sau sweep.
4. Chờ **nến đóng sau nến xác nhận sweep** phá xuống dưới swing ít nhất buffer, mặc định 1 tick. Wick chọc qua không đủ. Nến đang chạy không được tính.
5. Mặc định yêu cầu nến phá giảm và thân >= `Range_Displacement_ATR × ATR14` của các nến trước nó; tỷ lệ thân/range >= `Range_Displacement_Body_Fraction`. Mặc định hiện có là 1 ATR và 0,60. Khi tắt yêu cầu displacement, chỉ điều kiện phá đóng được nới trong phần giải thích này.
6. Chỉ ghi **MSS giảm** nếu prefix trước sweep có HH/HL đã xác nhận. Khi xu hướng trước đó trung tính hoặc không phù hợp, ghi **phá swing**, không khẳng định market structure shift. SSL/MSS tăng dùng quy tắc đối xứng.
7. Chờ tối đa 12 nến giao dịch sau xác nhận. Trước MSS, đóng vượt cực trị wick theo phía quét và vượt buffer sẽ kết thúc trạng thái chờ. Một MSS đã xác nhận là sự kiện lịch sử; nến về sau không xóa sự kiện đó.

Đây là định nghĩa vận hành của lớp tham khảo, không tuyên bố mọi cách dùng thuật ngữ MSS đều giống nhau. Đồng thời MSS không tự chứng minh có lợi thế giao dịch.

## Deep learning được nối thế nào

[Module phân tích sweep](../Include/ICTSweepFocus.mqh) gọi DNN **32 → 12 → 6 → 3** đã học thật bằng backprop trong [bộ học local](../Include/ICTStatisticalLearning.mqh), kèm logistic đối chứng. Dữ liệu đầu vào được cố định tại **nến xác nhận reclaim**, kể cả khi sau đó đã xuất hiện MSS. Không lấy nến giảm/tăng mạnh sau sweep làm đầu vào cho dự báo tại sweep.

Điều kiện hiển thị xác suất:

- Model đã học xong và cùng khung với nến sự kiện.
- Nến cuối cùng làm nhãn train và hiệu chỉnh phải có timestamp **trước nến đặc trưng sự kiện**. Nếu không đạt, hiện lý do chờ, không lấy xác suất trên mẫu đã học để trang trí lịch sử.
- Cửa sổ đặc trưng tại sự kiện phải đủ và hợp lệ. Record native được đối chiếu với wick và giá đóng trong lịch sử; bản ghi không khớp bị loại khỏi overlay mới.
- Kết quả giữ đủ 3 lớp tăng/giảm/ngang. Đây là dự báo giá đóng sau H nến vượt biên ATR + spread ghi trong dữ liệu; **không phải xác suất sweep đúng, MSS đúng, TP trước SL hoặc lợi nhuận ròng**.

Giới hạn: model hiện dùng OHLC và bốn nhóm mẫu giá cơ bản; chưa được huấn luyện riêng bằng nhãn sweep/MSS, context SMT/Strong OB native đầy đủ. Với sự kiện lịch sử, đây là chấm lại bằng mô hình hiện có có train/calibration trước sự kiện, **không phải bản ghi dự báo live được lưu tại thời điểm đó**. Một model mới sau lần retrain có thể cho xác suất khác; pool/wick/MSS theo cùng prefix không đổi. Nguồn giá broker, lịch phiên và chi phí vẫn cần kiểm định như [tham mưu học sâu](DEEP_LEARNING_ADVISORY_20261120.md).

## Inputs và cách xem

Trong Inputs của EA bản 1.06:

| Input | Mặc định | Ý nghĩa |
| --- | --- | --- |
| `Sweep_Focus_Enable` | true | Bật phần hiển thị bổ sung |
| `Sweep_Focus_Maximum` | 3 | Số râu nến được nhấn mạnh, cho phép 1–6 |
| `Sweep_Focus_History_Bars` | 360 | Lịch sử đóng để tra swing/đặc trưng, cho phép 80–2000 |
| `Sweep_Focus_Font_Size` | 10 | Cỡ chữ thực, cho phép 8–16, không bị nhân 75% |
| `Sweep_Focus_Arrow_Size` | 1 | Cỡ mũi tên, cho phép 1–3 |
| `Sweep_Focus_Prefer_H1` | true | Ưu tiên thuận cấu trúc H1 tại reclaim, sau đó mới nhất |
| `Sweep_Focus_Compact_Duplicates` | true | Gộp nhãn nhỏ trùng trên râu đã nhấn mạnh |
| `Sweep_Focus_Show_MSS` | true | Hiện đường/nhãn MSS tham khảo |
| `Sweep_Focus_MSS_Window_Bars` | 12 | Số nến giao dịch tối đa để chờ, cho phép 1–100 |
| `Sweep_Focus_MSS_Buffer_Ticks` | 1 | Khoảng đóng vượt swing / cực trị khi kiểm tra |
| `Sweep_Focus_MSS_Require_Displacement` | true | Yêu cầu displacement trên nến phá |

`Enable_IRL_ERL`, `EnableLiquiditySweepDetection`, `Show_Liquidity`, `Range_Show_IRL/ERL` và `ShowSweep1/2/3Plus` tiếp tục được tôn trọng. Tắt Focus trả lại nhãn sweep cũ. Tắt dashboard không tắt các overlay chart được điều khiển riêng; gỡ EA sẽ dọn tất cả object thuộc EA.

Overlay mới hiển thị trên **Chart_Zone_Timeframe trùng khung sự kiện LTF native**; mặc định `PERIOD_CURRENT` theo chart. Smart tự map khung như cũ. Với DecisionSupport, muốn xem ví dụ XAUUSD M5, chart/vùng hiển thị và `Range_LTF` phải cùng M5; thay đổi các input phân tích cần giữ thứ tự HTF > MTF > LTF như kiểm tra cấu hình sẵn có.

## Hướng học sâu tiếp theo nên ưu tiên

Ưu tiên TCN causal W32 + context native như [lộ trình đã nghiên cứu](DEEP_LEARNING_ADVISORY_20261120.md), thay vì coi DNN OHLC hiện tại là bộ nhận dạng sweep chuyên biệt:

1. Export **mọi** event đủ điều kiện, bao gồm thất bại và timeout. Ghi event/pool ID, symbol, khung, wick/reclaim timestamp, pivot được biết trước, bias, depth/ATR, spread, SMT có sẵn, OB/FVG freshness và trạng thái MTF. Không chỉ export các sweep nhìn lại thấy đẹp.
2. Tách hai thời điểm quyết định: **sau reclaim** và **sau MSS**. MSS tương lai tuyệt đối không được làm feature của dự báo lúc reclaim. So sánh trên cùng nhóm sự kiện; đánh giá thêm coverage vì MSS làm giảm số mẫu.
3. Đặt nhãn TP/SL/timeout với entry, chi phí và horizon đã đóng băng. Nến OHLC chạm cả TP và SL phải được gắn cờ mơ hồ hoặc xử lý bảo thủ; không suy diễn thứ tự intrabar từ OHLC.
4. Walk-forward, purge/embargo các nhãn chồng lấn, calibration riêng, holdout cuối không dùng chọn cấu hình. So TCN với prior/logistic/DNN hiện có trên cùng cohort; đo log loss, Brier, độ tin cậy xác suất, coverage và kết quả ròng khi chi phí đã được xác minh.
5. Chỉ cân nhắc nối model chuyên biệt vào quyết định sau khi có bằng chứng ngoài mẫu và đối chiếu inference offline/MT5. Bản 1.05 chỉ nối ngữ cảnh dự báo đang có vào phần tham khảo.

Không có bằng chứng hiện tại để gọi một mô hình là “tối ưu nhất” hoặc cam kết hiệu quả giao dịch. Lợi ích cụ thể đã triển khai là nhìn rõ sự kiện native, phân biệt sweep với breakout, kiểm tra MSS theo thời gian và ngăn xác suất học từ tương lai xuất hiện trên sự kiện cũ.

## Kiểm chứng

- Bản 1.07: 498 kiểm tra lõi đạt, gồm nhãn first-touch và học mạng riêng; hai EA, indicator và ba fixture liên quan biên dịch 0 lỗi / 0 cảnh báo. Xem [kết quả và giới hạn](DEEP_LEARNING_ADVISORY_20261120.md). Chưa quan sát model fit hoặc chart thực sau nạp.
- Bản 1.06 ngày 22/11: **458 kiểm tra, 0 thất bại** trong runner pure core hiện có; tăng 22 ca cho cấu trúc H1 tăng/giảm/trung tính, nến đóng đúng reclaim, loại H1 đang chạy/tương lai, thiếu giờ gần nhất, thiếu lookback và ưu tiên/fallback. Các ca MSS/DL và hồi quy cũ vẫn chạy cùng bộ. Kết quả và hash nguồn trong [báo cáo core](../Tests/Reports/ICT_UNIFIED_CORE_FIXTURES.txt).
- Biên dịch bản 1.06: [DecisionSupport](../Experts/ICTDecisionSupportEA.ex5), [Smart](../Experts/ICTSmartDecisionEngineEA.ex5) và [fixture MQL](../Tests/ICTSweepFocusTests.ex5) đều **0 lỗi / 0 cảnh báo**. Nguồn trong runtime biên dịch được đối chiếu SHA256 với các file đã sửa của workspace, khớp đầy đủ. Log mới giữ trong `Tests/.terminal` với hậu tố `h1_focus_20261122.compile.log`; không ghi đè log 1.05.
- Kiểm tra trực quan ngày 22/11 chưa hoàn thành: hai lần lấy trạng thái Windows đều timeout. Chưa xác nhận vị trí thực trên chart hoặc việc nạp lại EA trong terminal.
- [Fixture sweep/MSS/DL](../Tests/ICTSweepFocusFixtures.mqh): xác nhận sau sweep, swing cố định trước wick, không đọc tương lai, wick-only, displacement, prebroken, invalidation, expiry, đối xứng SSL và gate train/calibration/timeframe.
- [Runner pure core](../Tests/RunICTCoreFixtures.ps1): bản 1.05 có 436 kiểm tra, bản 1.06 có 458; thực thi các hàm production qua adapter cú pháp MQL → C#. Không thay cho runtime MetaTrader hoặc backtest thị trường.
- [EA fixture MQL](../Tests/ICTSweepFocusTests.mq5) có cùng các ca để chạy trong Tester khi môi trường tài khoản/lịch sử sẵn sàng.
- 28 chương trình MQL5 trong nhóm log `sweep_mss_20261120` biên dịch 0 lỗi / 0 cảnh báo. Sau các chỉnh lý cuối, hai EA và fixture sweep được biên dịch lại: [DecisionSupport](ICTDecisionSupportEA.sweep_mss_final_20261120.compile.log), [Smart](ICTSmartDecisionEngineEA.sweep_mss_final_20261120.compile.log), [fixture MQL](ICTSweepFocusTests.sweep_mss_final_20261120.compile.log), đều 0 lỗi / 0 cảnh báo.
- Chưa có nghiệm thu hình ảnh chart thật trong phiên này vì kết nối điều khiển MT5 không khả dụng. Biên dịch và fixture không thay thế kiểm tra bố cục chart trực tiếp hay backtest broker.

### Cài đặt bản 1.07 ngày 22/11/2026

Đã sao lưu hai EA 1.06 và indicator của dự án trước khi thay binary mới tại đúng đường dẫn cài hiện có. [Manifest sao lưu/cài 1.07](../Tests/.terminal/installed-ea-backups/sweep-focus-20261122-210400/manifest.json) có nguồn, đích và SHA256 trước/sau, kiểm tra sau copy khớp build. Cần nạp lại EA/indicator để chạy phiên bản mới; chưa xác nhận chart đã nạp hoặc phát hành xác suất.

| Binary | SHA256 bản cài mới |
| --- | --- |
| DecisionSupport 1.07 | `D1BDD5F07E95D16BBE3839B502BC870351F702F5CF620D0FF9994AFB0F5949A1` |
| Smart 1.07 | `74862F25E0B8106B7AAD1550384C44987FF1AB495C3D29573F197029112035E0` |
| SmartRiskDashboard, renderer cập nhật | `31D9C1E95C259BBE98EE08BA3C39C78761BBA6FFA7758A72888A38CA29B66699` |

### Lịch sử cài đặt bản 1.06 ngày 22/11/2026

Đã sao lưu hai binary 1.05 và cập nhật hai EX5 1.06 vào đúng thư mục Experts `ict_engine_EA` của terminal đang dùng, đối chiếu SHA256 sau copy khớp với bản build. [Manifest sao lưu 1.05 và hash cài 1.06](../Tests/.terminal/installed-ea-backups/sweep-focus-20261122-204205/manifest.json) ghi đầy đủ nguồn, đích và bản dự phòng. Không đổi thư mục cài đặt hoặc cấu hình chart. Cần gỡ rồi gắn lại EA, đặt riêng `Dashboard_Y=60` và `Position_Risk_Y=60` nếu Inputs còn lưu 80. Chưa quan sát được phiên bản nạp trên chart do kết nối Windows timeout.

| Binary | SHA256 bản cài 1.06 |
| --- | --- |
| DecisionSupport | `0EAC3B4A78D60C0C7B320E3B19BE31896AB5FD67CC202E95120C929AE3BCB13F` |
| Smart | `C06A93993529A5A9046A5A60C211FA11F7E4543008137F1D2B4DC1A739334CAE` |

### Lịch sử cài đặt bản 1.05 ngày 20/11/2026

Hai binary 1.05 đã được sao lưu/cài vào thư mục Experts `ict_engine_EA` của terminal đang dùng, kiểm tra SHA256 sau copy khớp với bản build cuối. Bản 1.04 được giữ trong [thư mục sao lưu](../Tests/.terminal/installed-ea-backups/sweep-focus-20261120-235259/manifest.json). Tại thời điểm bàn giao 1.05, chưa quan sát trực tiếp thao tác nạp lại trên chart.

| Binary | SHA256 bản cài 1.05 |
| --- | --- |
| DecisionSupport | `145A2A675EAA3AD9EA9A3CA6EBEBA4A2BF7980482B5A52B014A936A6DE776A92` |
| Smart | `829AC6FC307B992C72B219899D39E1ED3579AE43B6349FE610EF57D1B576C1A0` |

Đồ họa dùng [OBJ_TREND](https://www.mql5.com/en/docs/constants/objectconstants/enum_object/obj_trend), tắt cả hai ray, và [OBJ_ARROW](https://www.mql5.com/en/docs/constants/objectconstants/enum_object/obj_arrow) với width/anchor rõ ràng theo tài liệu MQL5. Việc hiệu chỉnh temperature có cơ sở từ [Guo và cộng sự, ICML 2017](https://proceedings.mlr.press/v70/guo17a.html); nghiên cứu đó không chứng minh xác suất hay lợi nhuận trên thị trường của EA này.
