# ICT SmartDecision — delta của master prompt (1), 2026-11-10

## Kết quả audit

Prompt mới giữ nguyên các yêu cầu 1–7 của [bản giao trước](./MASTER_MTF_DELIVERY_20261109.md), nhưng bổ sung điều kiện: mọi lớp phải truy được TF nguồn và chiếu lên chart hiện tại; SMT AUTO theo đúng chart TF, kể cả khi LTF override khác chart; cửa sổ SMT là 60 nến **chart** đã đóng. Cấu trúc trước sửa đã có ba `SICTTierSnapshot` cho cấu trúc/FVG/BPR, OB đa khung, pool liquidity có source TF và SMT độc lập cho LTF/MTF/HTF. Các khoảng trống xác định: SMT chỉ có tối đa ba layer; `display_start` lấy LTF đã override; premium/discount và BSL/SSL unified chỉ vẽ tầng trên; range event chưa có ID riêng và marker close vẽ ở open của nến.

Không sửa risk policy, quyền đặt/đóng lệnh, hay mặc định auto trading. `SICTRangeSnapshot` vẫn giữ một dealing range HTF làm ngữ cảnh ra quyết định; MTF/LTF cung cấp pool/zone và unified tiers. Chưa có ba state machine breakout độc lập theo mỗi source TF — đây là giới hạn còn lại so với cách diễn giải nghiêm ngặt của prompt mới.

## Ma trận yêu cầu → triển khai → kiểm chứng

| Yêu cầu | Module / input | Trạng thái và bằng chứng |
| --- | --- | --- |
| 1. Quyết định ba khung | `ICTResolveTimeframes`, `ICTBuildUnifiedSignal`; `AutoTimeframeMapping`, `LTFOverride`, `MTFOverride`, `HTFOverride` | Giữ nguyên các hard gate của bản giao trước; 170 core fixtures PASS. |
| 1.3. Phân tích/hiển thị đa khung | `SICTTierSnapshot`, `ICTRenderUnifiedOverlays`; `Context_ShowLTF/MTF/HTF` | Mỗi tier dùng dữ liệu cấu trúc/FVG/BPR riêng; bổ sung premium/discount và BSL/SSL của cả ba tier, gắn TF, timestamp xác nhận; OB cùng filter TF. Chưa xác nhận trực quan trên MT5. |
| 2. BUY/SELL, 60 nến và risk | `ICTSignalResult`, `ICTSignalHistory`, `ICTAlertManager`; `SignalHistoryClosedBars` | Giữ nguyên đường dữ liệu tập trung và journal từ bản trước; không thay risk policy. Native runtime chưa chạy. |
| 3. SMT chart TF và ba tầng | `ICTSMTTimeframes`, `CICTUnifiedAnalysis`, `ICTUnifiedBridge`, renderer; `SMT_Timeframe_Mode`, `SMT_ShowCurrentChart` | AUTO giữ LTF/MTF/HTF riêng; nếu chart TF khác cả ba, thêm layer thứ tư, không tính trùng; MANUAL vẫn cố định. `display_start` dùng đúng 60 nến chart đã đóng tính tới `asof`. Bridge schema 3 và payload journal v2, có đọc/migrate v1 cho identity tương thích. Fixture thêm ca override/matching/manual. |
| 4. OB mạnh | `ICTStrongOrderBlock`, renderer; OB score/grade inputs và context TF filters | Logic điểm/lifecycle bản trước giữ nguyên; filter hiển thị theo tier mới. |
| 5. Breakout/IRL/ERL | `ICTRangeTypes`, `ICTRangeEngine`, `ICTRangeBridge`, renderer; breakout/retest inputs | Range event có ID bất biến `pool|type|confirmed_at`, source/event TF, close/wick, bridge schema 4 kiểm tra ID; marker close ở thời điểm xác nhận. Vẫn một range HTF và sự kiện quan sát trên LTF, chưa có breakout state machine riêng từng TF. |
| 6. Liquidity → BUY/SELL | `ICTRangeEngine`, `ICTUnifiedDecisionAdapter`; `Range_Show_*` | Pool LTF/MTF/HTF đã mang TF nguồn, source/target IDs giữ nguyên; chart unified thêm high/low mỗi tier. Chưa visual verify. |
| 7. Dashboard SMT thống nhất | `ICTUnifiedRenderer`, `ICTUnifiedBridge`; panel inputs | SMT layer `@Current Chart` được đánh dấu và shared snapshot có `chart_tf`; bridge từ chối snapshot khác chart TF. Không tạo dashboard thứ hai. |

## Các tệp sửa trong lượt này

- `Include/ICTDynamicSMT.mqh`: tập SMT sources có chart TF trong AUTO, dedup, MANUAL cố định.
- `Include/ICTUnifiedAnalysis.mqh`: snapshot/config chart TF, bốn layer, tám cursor, cửa sổ chart as-of, payload migration.
- `Include/ICTUnifiedInputs.mqh`: chart TF thực, context tier filters và SMT fourth-layer filter.
- `Include/ICTUnifiedBridge.mqh`: schema 3, truyền và kiểm tra chart TF, tối đa bốn SMT layers.
- `Include/ICTUnifiedRenderer.mqh`: ba tầng premium/discount + structural BSL/SSL, nhãn SMT current chart, marker tại confirmation time.
- `Include/ICTRangeTypes.mqh`, `Include/ICTRangeEngine.mqh`, `Include/ICTRangeBridge.mqh`, `Include/ICTRangeRenderer.mqh`: event ID và chart semantics, schema 4.
- `Tests/ICTUnifiedCoreFixtures.mqh`, `Tests/ICTUnifiedTests.mq5`, `Tests/ICTRangeTests.mq5`: ca chart SMT độc lập, bridge TF/ID.

## Cấu hình, ý nghĩa hiển thị và bằng chứng

Bản đồ LTF/MTF/HTF, bảng ứng viên symbol → peer 1/2, thuật toán liquidity/OB/breakout/decision gates, ngưỡng và màu mặc định ở [báo cáo gốc](./MASTER_MTF_DELIVERY_20261109.md). AUTO SMT sử dụng ba tier và tái sử dụng current chart nếu trùng; chart khác do override được thêm như nguồn thứ tư. `SMT_MANUAL` là chế độ duy nhất ghim SMT tại `SMT_ManualTimeframe`. `SMT_ShowCurrentChart` chỉ điều khiển hình vẽ của nguồn thứ tư; `Context_ShowLTF/MTF/HTF` điều khiển các overlay unified theo tầng. Nhãn `BSL/SSL` là pool suy luận từ swing, không phải lệnh chờ thực tế. OB/FVG/BPR vẫn là vùng giá riêng, không bị đổi tên thành liquidity pool.

`RunICTCoreFixtures.ps1`: 170 checks, 0 failures. `ICTTestRunner.Tests.ps1`: 57 passed, 0 failed. MetaEditor biên dịch toàn bộ 22 `.mq5`: 0 errors, 0 warnings; log `*.mtf_20261110b.compile.log` trong thư mục này. Sau chỉnh sửa cuối của fixture range, `RunICTTests.ps1 -Mode Compile -Expert ICTRangeTests` tiếp tục 0 errors, 0 warnings. Đây là bằng chứng compile, không phải bằng chứng các MQL assertion đã chạy trong terminal. Strategy Tester, multi-symbol visual test, ảnh chart/dashboard và backtest **chưa có bằng chứng mới**. Runtime isolated lần trước thiếu account; không sao chép tài khoản/credentials từ terminal đang chạy. Không cài EX5 vào MT5 live.
