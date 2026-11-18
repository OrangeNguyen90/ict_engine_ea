# ICT SmartDecision — Liquidity V2: audit và tình trạng triển khai

Ngày: 2026-11-13. Phạm vi chính là SmartDecision và các module dùng chung; không thay đổi chính sách vốn hoặc mã nguồn EA bảo vệ. Kết quả dưới đây là kiểm tra mã, fixture thuật toán và biên dịch; **chưa phải nghiệm thu giao dịch hay bằng chứng lợi nhuận**.

## Chẩn đoán dựa trên mã trước khi sửa

1. [CICTRangeEngine::Step](../Include/ICTRangeEngine.mqh) ban đầu đánh dấu một pool mới `IR_LEVEL_INVALIDATED` nếu thời điểm pool có thể biết được nằm trước nến LTF đầu tiên trong cửa sổ replay. `Range_Lookback=240` nến trên từng khung tương đương chỉ 20 giờ M5, nhưng một pivot D1 với hai nến xác nhận bên phải thường cũ hơn. Đây là nguyên nhân trực tiếp có thể khiến biên HTF và các mức D/W/M không được dùng, không phải bằng chứng về tần suất xảy ra trong một bộ dữ liệu cụ thể.
2. [ICTBuildUnifiedSignal](../Include/ICTUnifiedDecisionAdapter.mqh) trước sửa yêu cầu trên chính nến LTF retest vừa có BOS/MSS, vừa displacement. Phần range đã có chuỗi sự kiện riêng và displacement ở bước cấu trúc, nên bộ ghép áp thêm điều kiện cùng nến không thuộc chuỗi đó. Nó cũng yêu cầu BOS là sự kiện MTF mới nhất, dù setup còn giữ sự kiện cấu trúc trước đó.
3. Bộ máy range trước sửa dừng hẳn tại `IR_TARGET_REACHED` hoặc `IR_SETUP_INVALIDATED` đến khi có dealing range mới. Một sự kiện mới trong cùng range vì thế không mở setup tiếp theo. Các swing nội bộ được tạo nhưng trước đó chỉ sự kiện external mới khởi tạo nhánh sweep.
4. `Sweep_2_Required` trước sửa cộng các bản ghi sweep của nhiều pool đối diện rồi mô tả kết quả là hai sweep của cùng pool. Kiểm tra giờ được giới hạn vào pool nguồn thực tế và sau thời điểm range được xác nhận.
5. Nhánh legacy trong [ICTDecisionEngine.mqh](../Include/ICTDecisionEngine.mqh) vốn đã hỗ trợ FVG **hoặc** OB theo `Entry_Zone_Mode`; không có cơ sở kết luận toàn dự án bắt buộc đồng thời OB và FVG. Tuy vậy, detector FVG legacy coi cả lần chạm một phần là `mitigated`, còn mode range có trạng thái partial riêng: đây vẫn là một khác biệt cần đánh giá trong replay.
6. SmartDecision dùng ánh xạ chart tự động và SMT đa khung trong [ICTTimeframeMapper.mqh](../Include/ICTTimeframeMapper.mqh) và [ICTDynamicSMT.mqh](../Include/ICTDynamicSMT.mqh); M1 → M15/H4, M5 → H1/D1. SMT không mặc định bắt buộc. Các chương trình legacy vẫn có input timeframe riêng, trong đó có mặc định H1; không áp đặt lại cấu hình của chúng.
7. Tín hiệu còn phụ thuộc dữ liệu nến, HTF/MTF cùng hướng, pool mục tiêu, vùng giá, spread, RR ròng, tính hợp lệ của giá và heartbeat bộ bảo vệ. Dashboard/nhật ký hiển thị nhiều lý do từ chối. Không có journal thị trường mới để xếp hạng nguyên nhân chặn theo tần suất.

## Thành phần hiện có và khoảng trống

| Thành phần | Kết quả audit |
| --- | --- |
| Swing, BOS, MSS | [MarketStructure.mqh](../Include/MarketStructure.mqh) xác nhận pivot hai phía từ nến đóng; BOS/MSS dùng break nến đóng. Chưa thấy một đối tượng CHoCH độc lập. |
| FVG, BPR, OB | Có detector và lifecycle FVG, BPR, Strong OB; range có mã breaker, nhưng chưa xác nhận đầy đủ breaker trong đường unified runtime. FVG/OB là vùng giá, không phải bằng chứng có lệnh chờ. |
| BSL/SSL, IRL/ERL | Có swing, EQH/EQL, PD/PW/PM, biên range và phân loại theo range HTF. Các mức được dựng lại từ nến LTF với giới hạn lịch sử; không quan sát trực tiếp stop-loss/pending orders. |
| Sweep/breakout | Có phân biệt wick reclaim, breakout, false breakout, retest và lifecycle. Chuỗi Sweep 1/2 có khoảng cách và chống đếm trùng, nhưng sequence hiện chỉ được theo dõi cho hai boundary pool, chưa bao phủ mọi pool nội bộ. |
| SMT/MTF | SmartDecision có snapshot theo từng khung, hai peer SMT và kiểm tra đồng bộ; giao diện có trạng thái peer `NONE`/`N/A`. Thiếu runtime/visual test mới. |
| Điểm, dashboard, rủi ro | Có điểm trọng số 0–100 và dashboard từ snapshot chung; risk gate dựa trên dữ liệu broker, RR ròng và bảo vệ. Điểm hiện hành là giả thuyết cấu hình, không phải xác suất hoặc trọng số đã tối ưu. Chẩn đoán chưa phân loại đầy đủ PASS/FAIL/UNKNOWN/INVALID cho mọi điều kiện. |
| Chưa hoàn thiện | Chưa có detector đầy đủ riêng cho high/low Asian, London, New York theo timezone/DST, trendline liquidity, round-number liquidity, relative equal highs/lows, inducement hoặc liquidity-zone strength theo đặc tả. Bộ đếm replay mới chưa bao phủ mọi cơ hội và mọi điều kiện của đường unified. |

## Thay đổi trong lượt này

- [ICTRangeEngine.mqh](../Include/ICTRangeEngine.mqh): tái dựng pool từ lịch sử LTF dài hơn, chỉ dùng nến đóng trước thời điểm replay; tính vòng đời từ thời điểm xác nhận pivot riêng, không gán sự kiện cho range trước khi range hình thành. Pool thiếu lịch sử vẫn không được coi là mới. Bộ đếm hạn chế thời gian reclaim; quá hạn không tạo tín hiệu đảo chiều.
- Thêm continuation **sweep nội bộ → reclaim đóng → BOS MTF về sau → FVG hoặc OB hợp lệ → phản ứng LTF → mục tiêu ERL → kiểm tra risk**. Sau khi một setup hoàn tất/bị hủy, chỉ sự kiện liquidity mới mới cho phép khởi tạo setup khác trong cùng range. Nhánh reversal và continuation cũ vẫn được giữ.
- Breakout continuation yêu cầu break cấu trúc xảy ra sau thời điểm breakout nguồn. Nhánh này vẫn dùng phản ứng ở vùng giá làm xác nhận entry; chưa nên gọi đó là kiểm chứng đầy đủ mọi biến thể breakout/retest.
- [ICTSignalResult.mqh](../Include/ICTSignalResult.mqh) và [ICTUnifiedDecisionAdapter.mqh](../Include/ICTUnifiedDecisionAdapter.mqh): kiểm tra nến phản ứng đóng sau cấu trúc và zone, loại zone bị xuyên hết; không yêu cầu BOS và displacement lặp lại trên cùng nến retest khi displacement đã được xác nhận trong setup. Không cho dùng cấu trúc tương lai hoặc BOS ngược hướng.
- [ICTRangeTypes.mqh](../Include/ICTRangeTypes.mqh) và [ICTRangeInputs.mqh](../Include/ICTRangeInputs.mqh): tolerance EQH/EQL bằng `max(ticks × tick size, ATR × hệ số, spread lịch sử × hệ số)`; các hệ số được cấu hình, chưa tối ưu. Dữ liệu point không hợp lệ bị từ chối.
- [ICTDecisionEngine.mqh](../Include/ICTDecisionEngine.mqh): mô tả và tính evidence cho continuation sweep nội bộ; tính số sweep cho chính source pool, giữ nguyên các cổng protection, chi phí, RR, spread và hạn mức vốn.
- [ICTRangeTests.mq5](../Tests/ICTRangeTests.mq5) thêm kịch bản MQL đối xứng cho continuation và tái khởi tạo. [ICTUnifiedCoreFixtures.mqh](../Tests/ICTUnifiedCoreFixtures.mqh) thêm fixture cho chronology, dữ liệu tương lai, full mitigation, history coverage, sweep quá hạn và tolerance thích nghi.
- [ICTRangeReplayEA.mq5](../Tests/ICTRangeReplayEA.mq5) ghi thêm số sự kiện sweep/breakout quan sát đúng nến hiện tại, số candidate bị chặn vì đang có trạng thái paper, hình học, risk hoặc điểm, và số candidate được nhận vào paper ledger. `REASON_SNAPSHOTS` đếm số **nến** ở từng mã lý do, không được hiểu là số giao dịch bị từ chối; các sự kiện đã xảy ra trong phần warmup/replay trước nến đang quan sát không được cộng lại.

## Xác minh và giới hạn

| Hạng mục | Bằng chứng |
| --- | --- |
| Baseline trước sửa | [ICT_Baseline_20261113_pre_v2.zip](../Tests/Baselines/ICT_Baseline_20261113_pre_v2.zip), SHA-256 `3A78E3DA9F08A4C7B9D5384AEBCA4A9FF76F7BD065E218E2DA411CF905880F86`. Chỉ chứa mã nguồn MQL, cấu hình tester và script, không chứa tài khoản/runtime. Fixture thuật toán baseline: 170 kiểm tra, 0 lỗi. |
| Candidate, thuật toán thuần | [ICT_UNIFIED_CORE_FIXTURES.txt](../Tests/Reports/ICT_UNIFIED_CORE_FIXTURES.txt): 217 kiểm tra, 0 lỗi. Chạy hàm MQL thuần qua bộ chuyển cú pháp C#; không phải runtime MT5. |
| Bộ chạy kiểm thử | Pester: 57 đạt, 0 lỗi. |
| Biên dịch | Xem [ICT_V2_BUILD_20261113.csv](../Tests/Reports/ICT_V2_BUILD_20261113.csv): 22 chương trình MQL được biên dịch trong terminal cách ly. Không sao chép EX5 vào thư mục EA đang sử dụng. |
| Strategy Tester | Đã thử `ICTRangeTests`: terminal báo `tester not started because the account is not specified`; không có assertion MT5 hoặc backtest được thực thi. Chạy script fixture MQL độc lập cũng hết thời gian chờ mà không có kết quả. Các scenario mới trong `ICTRangeTests` vì vậy mới được biên dịch, chưa được xác nhận chạy native. |
| So sánh thị trường | Số pool, sweep, setup, tín hiệu, giao dịch, precision, expectancy, profit factor và drawdown của baseline/candidate: **chưa có dữ liệu**, không điền số ước đoán. Chưa có visual acceptance, out-of-sample hoặc kiểm thử broker execution. |

## Cấu hình và kiểm thử tiếp

1. Biên dịch nguồn candidate trong MetaEditor và chọn đúng EX5 mới. Bản EX5 đã cài trong MT5 không tự thay đổi theo workspace; baseline có thể được giải nén sang thư mục riêng và biên dịch với cùng cấu hình.
2. Bắt đầu với `AutoTimeframeMapping=true`, `Enable_IRL_ERL=true`, `Range_Allow_Continuation=true`. `Range_Liquidity_Seed_Bars=10000` là giới hạn lịch sử LTF, không phải cam kết luôn đủ dữ liệu; phải lớn hơn hoặc bằng `Range_Lookback`, tối đa 50000. Tăng số này chỉ khi terminal có lịch sử tương ứng và theo dõi chi phí tải/replay.
3. `Range_Equal_Threshold_Ticks=3`, `Range_Equal_Threshold_ATR=0.02`, `Range_Equal_Spread_Multiplier=1` là giá trị khởi tạo. `Sweep_Validation_Window_Bars` giới hạn reclaim; `SweepMode=SWEEP_2_REQUIRED` hiện chỉ hỗ trợ nguồn boundary đã có sequence, nên setup dùng pool nội bộ sẽ chờ thay vì tự vượt điều kiện đó. Không hạ RR, spread hay risk gate để bù tín hiệu thiếu.
4. Chạy `Tests/RunICTTests.ps1 -Mode CoreFixtures`, rồi các fixture `ICTRangeTests`, `ICTUnifiedTests`, `ICTDecisionTests`, `ICTDetectorTests` trong terminal/tester đã cấu hình tài khoản kiểm thử. Đối chiếu dashboard với source/target pool, thời điểm pivot/sweep/BOS/reaction, lý do chặn và lịch sử tín hiệu sau restart.
5. Chạy baseline và candidate trên cùng nguồn nến, spread, commission, slippage và cấu hình tài khoản cho EURUSD, GBPUSD, XAUUSD và US100/NAS100 nếu broker hỗ trợ, trên M1/M5/M15. Tách in-sample/out-of-sample; đo số cơ hội, tín hiệu đủ chuẩn, số bị loại theo từng gate, giao dịch, tín hiệu/1.000 nến, expectancy theo R, win rate, profit factor và max drawdown. [ICTRangeReplayEA.mq5](../Tests/ICTRangeReplayEA.mq5) chỉ là mô phỏng paper và không thay thế kiểm thử execution.

Không tuyên bố tăng số tín hiệu đủ chuẩn hay hoàn thành toàn bộ tiêu chí chấp nhận cho đến khi các kiểm thử native, visual và so sánh ngoài mẫu có bằng chứng thực tế.
