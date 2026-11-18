# ICT SmartDecision — MTF / SMT / OB / Liquidity

## Audit trước thay đổi

Phạm vi: nâng cấp trực tiếp [EA hiện có](../Experts/ICTSmartDecisionEngineEA.mq5),
không tạo EA phân tích hay dashboard SMT riêng. Workspace không có metadata Git;
các thay đổi có sẵn được giữ lại. Prompt gốc là UTF-8 hợp lệ; lỗi chữ ở lần đọc
trước là do PowerShell dùng encoding mặc định, không phải bằng chứng file hỏng.

| Thành phần có sẵn | Khoảng trống xác định trước khi sửa |
| --- | --- |
| [DecisionSupport](../Experts/ICTDecisionSupportEA.mq5), [DecisionEngine](../Include/ICTDecisionEngine.mqh) | Có risk/protection và kế hoạch; nhãn candidate, chưa có lịch sử BUY/SELL tập trung bất biến. |
| [UnifiedAnalysis](../Include/ICTUnifiedAnalysis.mqh), [TimeframeMapper](../Include/ICTTimeframeMapper.mqh) | Có mapper và snapshot; chưa có ghi đè độc lập cả ba tầng hoặc kết quả quyết định trong snapshot. |
| [DynamicSMT](../Include/ICTDynamicSMT.mqh) | Có pivot/time alignment; quan hệ và readiness gộp hai peer; journal chỉ ghi khóa không phục hồi đầy đủ xác nhận. |
| [StrongOrderBlock](../Include/ICTStrongOrderBlock.mqh) | Có displacement, BOS và lifecycle; trọng số cố định, quality hiện tại chưa hạ đầy đủ theo touch/invalidation. |
| [RangeEngine](../Include/ICTRangeEngine.mqh) | Có IRL/ERL, sweep và targeting; breakout là trạng thái cuối, thiếu sự kiện false breakout/retest riêng. |
| [UnifiedRenderer](../Include/ICTUnifiedRenderer.mqh), [UnifiedBridge](../Include/ICTUnifiedBridge.mqh) | Một panel, nhưng chưa chia trạng thái peer và chưa truyền cùng SignalResult cho các consumer. |
| [RunICTTests](../Tests/RunICTTests.ps1) | Cache thị trường tùy chọn bị khóa có thể chặn toàn workflow compile; compiler-only cần độc lập với dữ liệu thị trường. |

Không thay đổi mã policy vốn, mức emergency 3%, trần risk 2%, quyền đặt/đóng
lệnh, hay mặc định auto-entry/auto-SLTP. Các EA/indicator bảo vệ và calculation
service hiện hữu vẫn dùng API cũ. Những chương trình đó được compile hồi quy,
không được tự gắn vào chart/tài khoản.

## Ma trận yêu cầu và cách kiểm chứng

| Yêu cầu | Module/hàm triển khai | Inputs chính | Trạng thái và kiểm chứng |
| --- | --- | --- | --- |
| 1. Ba khung bắt buộc | [ICTResolveTimeframes](../Include/ICTTimeframeMapper.mqh), [ICTBuildUnifiedSignal](../Include/ICTUnifiedDecisionAdapter.mqh), [ICTEvaluateSignal](../Include/ICTSignalResult.mqh) | `AutoTimeframeMapping`, `LTFOverride`, `MTFOverride`, `HTFOverride`; inputs `MTF_Mode` cũ còn giữ | Mã tích hợp; fixture mapping, thiếu tầng, xung đột, điểm 100 không vượt gate. |
| 2. BUY/SELL, lịch sử, risk | [SignalResult](../Include/ICTSignalResult.mqh), [SignalHistory](../Include/ICTSignalHistory.mqh), [AlertManager](../Include/ICTAlertManager.mqh) | `SignalHistoryClosedBars=60`, `ShowConfirmedSignals`, `Minimum_RR` và các risk inputs cũ | Append-only theo nến; journal phục hồi; mũi tên/panel/alert/log cùng ID/time. Fixture immutability và hình học RR; runtime/render cần MT5. |
| 3. SMT hai peer | [DynamicSMT](../Include/ICTDynamicSMT.mqh), [UnifiedAnalysis](../Include/ICTUnifiedAnalysis.mqh) | `SMTMode`, `SMTSymbol1/2`, `SMT_Peer1_Relation`, `SMT_Peer2_Relation`, `SMT_Timeframe_Mode`, `SMT_ManualTimeframe`, pivot/gap/lookback/correlation inputs | Readiness, relation, hướng, pivot và time riêng từng peer/TF. Fixture thuận/nghịch, thiếu peer, đổi mapping/TF, event cũ/future bị loại. |
| 4. OB mạnh | [StrongOrderBlock](../Include/ICTStrongOrderBlock.mqh), [UnifiedRenderer](../Include/ICTUnifiedRenderer.mqh) | `OB_Weight_*`, `OB_StrongThreshold=80`, `OB_ModerateThreshold=60`, `OB_TouchPenalty=5`, ATR/bounds/invalidation inputs | Điểm xác nhận đóng băng, điểm hiện tại giảm khi touch; invalidated không còn STRONG. Fixture weights, displacement/BOS, mitigation, expiry. |
| 5. Breakout/liquidity events | [RangeEngine](../Include/ICTRangeEngine.mqh), [RangeTypes](../Include/ICTRangeTypes.mqh), [RangeRenderer](../Include/ICTRangeRenderer.mqh) | `Range_Breakout_Confirmation_Bars`, breakout buffers/displacement options, retest window/buffers | Tách sự kiện sweep/breakout/false breakout/retest khỏi lifecycle; fixture hai chiều và chống đếm trùng. |
| 6. Liquidity → quyết định | [RangeEngine](../Include/ICTRangeEngine.mqh), [UnifiedDecisionAdapter](../Include/ICTUnifiedDecisionAdapter.mqh), [SignalHistory](../Include/ICTSignalHistory.mqh) | `Show_Liquidity`, `Range_Show_*`, sweep separation/rejection inputs | Pool source/target IDs và TF; Entry/SL/liquidity TP/RR; thiếu target ghi `TARGET UNAVAILABLE`. OB/FVG/BPR không được đổi tên thành pool. |
| 7. Một dashboard | [UnifiedRenderer](../Include/ICTUnifiedRenderer.mqh), [DashboardPanel](../Include/ICTDashboardPanel.mqh), [SmartRiskDashboard](../Indicators/SmartRiskDashboard.mq5) | Panel position/size/font, display layer inputs | Cùng shared snapshot; 6 nhóm có thu gọn; indicator không tính một tín hiệu giao dịch khác. Kiểm tra round-trip bridge; visual acceptance cần terminal. |

## Bản đồ timeframe

`PERIOD_CURRENT` trong các override mới nghĩa là giữ tầng tự động. Các override
khác được kiểm tra lại theo thời lượng `LTF < MTF < HTF`. Khi chọn MANUAL cũ,
`MTF_Override`/`HTF_Override` vẫn có hiệu lực nếu override mới không được đặt.

| Chart / LTF mặc định | MTF | HTF |
| --- | --- | --- |
| M1 | M15 | H4 |
| M5 | H1 | D1 |
| M15 | H1 | D1 |
| M30 | H4 | D1 |
| H1 | H4 | D1 |
| H4 | D1 | W1 |
| D1 | W1 | MN1 |
| M2/M3/M4 | M15 | H4 |
| M6/M10/M12/M20 | H1 | D1 |
| H2/H3 | H4 | W1 |
| H6/H8/H12 | D1 | W1 |
| W1 | MN1 | N/A — không xác nhận giao dịch |
| MN1 | N/A | N/A — không xác nhận giao dịch |

Đóng nến MN1 dùng tháng lịch, không giả định mọi tháng có 30 ngày. HTF/MTF chỉ
được dùng khi close time không mới hơn snapshot LTF.

## SMT AUTO / MANUAL / OFF

Chọn `SMTMode=SMT_SELECTION_AUTO`, `SMT_SELECTION_MANUAL` hoặc `SMT_SELECTION_OFF`.
Tên enum có prefix để không đụng các mode cũ. Manual symbol mới ưu tiên hơn
`SMT_Comparator*_Symbol` rồi đến `Comparison_Symbol_*` cũ. Peer có thể được tắt
riêng qua `SMT_Comparator*_Mode=SMT_SLOT_DISABLED`.

`SMT_Timeframe_Mode=AUTO_ALL` phân tích LTF/MTF/HTF; `AUTO_LTF`, `AUTO_MTF`,
`AUTO_HTF` hoặc `SMT_MANUAL` + `SMT_ManualTimeframe` giới hạn TF. Không khóa H1.
`SMTRequiredForConfirmation=false` giữ SMT tùy chọn; `Mandatory_SMT` cũ hoặc
input mới bật sẽ yêu cầu SMT đồng thuận, không có hướng đối nghịch còn hiệu lực.

| Symbol nền | Peer 1 ứng viên | Peer 2 ứng viên |
| --- | --- | --- |
| EURUSD | GBPUSD | DXY |
| GBPUSD | EURUSD | DXY |
| XAUUSD | XAGUSD | DXY |
| XAGUSD | XAUUSD | DXY |
| ES | NQ | YM |
| NQ | ES | YM |
| Symbol khác, US30/USTEC hoặc tên broker không khớp | N/A; chọn MANUAL | N/A; chọn MANUAL |

Đây là danh sách ứng viên của code, không phải khẳng định tương quan luôn đúng.
AUTO chỉ dùng tên có thực trong broker, hỗ trợ cùng prefix/suffix, kiểm tra tick,
độ dài lịch sử, timestamp và hai cửa sổ tương quan ổn định mặc định 60 mẫu,
`|rho| >= 0.60`. Không tìm thấy DXY không được thay bằng dữ liệu giả. Có thể sửa
`SMT_DefaultPairMap` bằng tên broker chính xác. AUTO relation dựa dữ liệu; MANUAL
cho chọn POSITIVE/NEGATIVE riêng hai peer. Peer thiếu dữ liệu hiển thị N/A, không
xóa trạng thái peer còn đủ dữ liệu và không đóng góp điểm.

## Quy tắc định lượng

- HTF: bias từ swing đã đủ right bars. MTF: cấu trúc cùng hướng và vùng setup
  còn hợp lệ. LTF: nến đóng có displacement và reaction hợp lệ của setup, hoặc
  BOS/MSS mới + retest vùng; không dùng trigger cũ để xác nhận lại ở nến sau.
- Chỉ sau các cổng trên mới dùng score và risk. Net RR phải đạt ngưỡng hiện có
  (ít nhất 2); entry/SL/TP phải có hình học đúng và qua calculator broker-aware,
  spread/quote/protection/vốn như trước. TP2 thiếu thì N/A, không suy ra bằng RR.
- OB: nhóm nến ngược trước displacement, ATR/body fraction, BOS crossing đã
  đóng, sweep hoặc continuation thuận HTF. Trọng số mặc định sweep 20,
  displacement 20, structure 15, FVG 15, HTF 15, PD 10, freshness 5 (tổng 100).
  Điểm/grade xác nhận không thay đổi; current quality giảm freshness/touch,
  mitigated/invalidated/expired mất hiệu lực. Không suy luận dòng tiền tổ chức
  từ tick volume.
- BSL/SSL là mức suy luận từ swing/EQH/EQL/previous-period extrema. Range gắn
  với swing đã xác nhận; pool ở biên/ngoài là ERL, pool bên trong là IRL.
  FVG/BPR/OB là vùng giá quan tâm, không phải dữ liệu lệnh chờ.
- Wick xuyên và close reclaim là `LIQUIDITY_SWEEP`. Outside close chỉ là
  candidate cho đến khi đạt count/displacement được cấu hình. Reclaim của
  candidate/breakout là `FALSE_BREAKOUT`; chạm rồi giữ hướng sau breakout trong
  cửa sổ là `RETEST_CONFIRMED`. Broken/consumed không tự trở lại fresh.
- Sweep lặp phải có khoảng tách và rearm; cùng nến/sự kiện không được tính lại.
  Pool ID giữ theo pivot nguồn, không theo lần đổi đầu kia của range.

Tất cả các mức mặc định là giả định kỹ thuật có thể cấu hình, không phải quy
luật thị trường tuyệt đối hay xác suất thắng.

## Lịch sử và hiển thị

Mũi tên BUY xanh / SELL đỏ chỉ được tạo từ `SignalResult.confirmed`. WATCH
không có mũi tên xác nhận và không phát popup/push/sound xác nhận. Tooltip có
ID, trigger candle, confirmation time, lý do và pool IDs. Đường pool nguồn,
Entry/SL/TP và bracket RR là kế hoạch tham khảo, không phải đường dự báo giá.

Journal tín hiệu nằm trong sandbox MQL5 Files, tách theo account/chart/symbol/
timeframe. Quan sát đầu tiên của mỗi nến đóng được lưu, không nâng WATCH cũ
thành xác nhận do quote/account thay đổi ở timer sau. Tín hiệu đã xác nhận không
bị đổi giá/hướng; chỉ dọn hình khi ra khỏi số nến đóng được cấu hình. Restart
đọc bản ghi gốc. Không backfill 60 nến bằng trạng thái tài khoản hiện tại: chart
mới chưa có journal sẽ tích lũy xác nhận từ lúc chạy. Payload SMT có version,
checksum và pivot đầy đủ để giữ nguyên xác nhận khi khởi động lại.

Dashboard chung gồm Market/Timeframes, Decision, SMT Analysis, Liquidity &
Breakout, Strong OB, Trade Plan & Risk. Click tiêu đề `[-]`/`[+]` để thu gọn/mở
nhóm; dùng `<`/`>` để chuyển trang, mắt để ẩn/hiện, kéo nền để di chuyển. Input
peer đổi qua hộp Inputs của EA, không mở cửa sổ SMT riêng. Quality 0–100 là
điểm bằng chứng theo trọng số, không phải tỷ lệ thắng.

## Kiểm thử và giới hạn bằng chứng

| Kiểm chứng | Kết quả thật |
| --- | --- |
| Runner regression (Pester) | 57 PASS, 0 FAIL. Có khóa file độc quyền, stale/partial cache, quyền truy cập và lỗi disk; không nuốt lỗi ngoài sharing/lock violation. |
| Thuật toán MQL thuần qua adapter C# | 167 PASS, 0 FAIL: mapping, calendar/as-of, SMT hai chiều/peer, OB, signal gates/history, liquidity hai chiều và bridge/payload round-trip. |
| Account-free Verify | PASS 14/14 bước: runner + core + prepare + 7 build Tester + 4 build offline script. |
| MetaEditor production/test build | 22 chương trình: 0 errors, 0 warnings; build cuối kiểm tra lại toàn bộ nguồn hiện tại. |
| Strategy Tester thật | NOT VERIFIED: runtime cô lập thiếu account; terminal thoát, không có assertion/runtime market nào được chạy. |
| Backtest đa symbol, visual, ảnh chart | Chưa xác minh do Tester chưa khởi chạy; không dùng ảnh hoặc log cũ để nhận PASS. |

Bằng chứng: [JSON verification](../Tests/Reports/ICT_VERIFICATION.json),
[core fixture log](../Tests/Reports/ICT_UNIFIED_CORE_FIXTURES.txt),
[runtime attempt](../Tests/Reports/ICT_RUNTIME_20261109.md),
[SmartDecision compiler log](ICTSmartDecisionEngineEA.mtf_20261109.compile.log),
[indicator compiler log](SmartRiskDashboard.mtf_20261109.compile.log).

Core fixtures chạy các hàm MQL thuần qua adapter cú pháp C#, không thay thế
runtime MetaTrader. Build dùng MetaEditor thật trong runtime cô lập. Verify
không chạy terminal hay nhập tài khoản. Cache lịch sử tùy chọn đang bị khóa
được ghi rõ unavailable và xóa bản sao cache cũ trong runtime; compiler-only
vẫn chạy. Không đóng MT5 của người dùng, không sao chép credentials/config.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tests\RunICTTests.ps1 -Mode Verify
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tests\CompileICT.ps1 -LogTag mtf_20261109
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tests\RunICTTests.ps1 -Mode Run -Expert ICTUnifiedTests -TimeoutSeconds 30
```

Để nghiệm thu visual/market: dùng runtime demo/Tester đã được người dùng thiết
lập; test EURUSD, GBPUSD, XAUUSD và symbol chỉ số có dữ liệu trên M1/M5/M15/H1,
đổi chart/peer/TF, tắt/mất một peer, xem arrow/panel/log cùng ID/time, chụp trước
và sau restart, kiểm tra đúng cửa sổ 60 nến và các nhóm ở nhiều kích thước chart.
Không có bằng chứng runtime/ảnh thì không coi compile hoặc core PASS là đã
nghiệm thu giao dịch, backtest hay hình ảnh.

## Cài đặt

Sau build, chép EX5 của EA hiện có và các include cùng phiên bản vào MT5 của
bạn hoặc compile trong project MT5. Gắn SmartDecision vào chart phân tích và
để các quyền tự giao dịch như cấu hình hiện hành. Protection EA phải được thiết
lập theo hướng dẫn cũ để một kế hoạch vượt risk gate; không chạy hai controller
bảo vệ cùng account. Không cần gắn thêm EA SMT. Indicator cùng chart chỉ đọc
snapshot từ EA và không dựng một tín hiệu giao dịch độc lập.

## Danh sách tệp nguồn/tài liệu thay đổi

- EA và indicator: [SmartDecision entry point](../Experts/ICTSmartDecisionEngineEA.mq5),
  [DecisionSupport](../Experts/ICTDecisionSupportEA.mq5),
  [SmartRiskDashboard](../Indicators/SmartRiskDashboard.mq5).
- Timeframes/quyết định/lịch sử: [TimeframeMapper](../Include/ICTTimeframeMapper.mqh),
  [UnifiedInputs](../Include/ICTUnifiedInputs.mqh),
  [UnifiedDecisionAdapter](../Include/ICTUnifiedDecisionAdapter.mqh),
  [SignalResult — mới](../Include/ICTSignalResult.mqh),
  [SignalHistory — mới](../Include/ICTSignalHistory.mqh),
  [DecisionBridge](../Include/ICTDecisionBridge.mqh), [AlertManager](../Include/ICTAlertManager.mqh).
- Phân tích/SMT/OB và snapshot: [DynamicSMT](../Include/ICTDynamicSMT.mqh),
  [StrongOrderBlock](../Include/ICTStrongOrderBlock.mqh),
  [UnifiedAnalysis](../Include/ICTUnifiedAnalysis.mqh), [UnifiedBridge](../Include/ICTUnifiedBridge.mqh).
- Liquidity/breakout: [RangeTypes](../Include/ICTRangeTypes.mqh),
  [RangeEngine](../Include/ICTRangeEngine.mqh), [RangeInputs](../Include/ICTRangeInputs.mqh),
  [RangeRenderer](../Include/ICTRangeRenderer.mqh), [RangeBridge](../Include/ICTRangeBridge.mqh).
- Dashboard: [UnifiedRenderer](../Include/ICTUnifiedRenderer.mqh),
  [DashboardPanel](../Include/ICTDashboardPanel.mqh).
- Kiểm thử/build: [RunICTTests](../Tests/RunICTTests.ps1),
  [runner common](../Tests/ICTTestRunner.Common.ps1),
  [runner regressions](../Tests/ICTTestRunner.Tests.ps1),
  [core adapter](../Tests/RunICTCoreFixtures.ps1),
  [shared fixtures](../Tests/ICTUnifiedCoreFixtures.mqh),
  [UnifiedTests](../Tests/ICTUnifiedTests.mq5), [RangeTests](../Tests/ICTRangeTests.mq5),
  [CompileICT](../Tests/CompileICT.ps1), [VS Code build task](../.vscode/tasks.json).
- Tài liệu: [README](../README.md), [gap matrix lịch sử](MTF_SMT_OB_GAP_MATRIX.md),
  báo cáo này và [runtime evidence](../Tests/Reports/ICT_RUNTIME_20261109.md).

EX5 trong workspace được build lại. Không deploy hay thay EX5 đang chạy trong
MT5 cài đặt của người dùng. Những nguồn risk/protection/auto-trader không nằm
trong danh sách sửa ở trên.
