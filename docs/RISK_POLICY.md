Năm dòng chính: bảo vệ tự động, P/L đang mở, rủi ro SL + chờ, P/L ngày và vị thế rủi ro nhất kèm RR ròng. Các chỉ số portfolio còn lại, giá vào, SL/TP và RR từng vé nằm trong tooltip; RR không hợp lệ hoặc thiếu dữ liệu hiển thị `RR --`.
Mặc định 420 × tối đa 420 px. Font tự giảm khi cần; cửa sổ quá thấp ưu tiên các dòng đầu và ghi rõ số mục đang hiện, không tạo trang thứ hai. Bảng chính chỉ giữ năm chỉ số khác ý nghĩa để tránh lặp; các thông tin chi tiết xem bằng tooltip. Nếu chọn một symbol, bảng ghi rõ phạm vi và không suy ra dư địa toàn tài khoản từ dữ liệu một phần. Thiếu SL/định giá phải hiện **CHƯA ĐỦ**, không đổi thành 0% rủi ro.
# Kiểm soát rủi ro cho tài khoản thật

Cập nhật 24/11/2026 — DecisionSupport / Smart 1.11, Auto Trader 1.31.

## Giới hạn theo yêu cầu: 3% mỗi lệnh, 6% mỗi ngày

**Trần mỗi lệnh là 3%; trần ngày là 6%.** Không cho cấu hình vượt các mức này trong đường tính rủi ro và mở lệnh đã tích hợp. Rủi ro mục tiêu mặc định giữ ở **0,25%/lệnh** để bắt đầu thận trọng; đây là lựa chọn quy mô, không phải bắt buộc sử dụng hết trần 3%.

Trong lúc chưa có lựa chọn khác về cách tính ngày, dùng cả hai chốt: **lỗ ngày dự kiến không quá 6%** và **tổng ngân sách rủi ro của các lệnh mở trong ngày không quá 6%**. Chốt thứ hai không hoàn lại ngân sách khi chốt lời. Có thể chọn chỉ dùng chốt lỗ ngày bằng `Daily_Risk_Budget_Enable=false`; giới hạn lỗ ngày vẫn phải dương và không quá 6%.

Đề xuất bổ sung tổng rủi ro đồng thời tối đa **3%**, gồm vị thế, lệnh chờ và lệnh mới; margin dự kiến sau mở lệnh tối đa **20% Equity**. Hai mức này là lựa chọn thiết kế thận trọng của dự án, không phải chuẩn an toàn do cơ quan quản lý bảo đảm. Chưa biết vốn, broker, mã giao dịch và drawdown người dùng chấp nhận, nên đây là cấu hình khởi đầu, chưa phải phương án đã cá nhân hóa.

| Điều kiện | Trước thay đổi | Mặc định / hành vi mới |
| --- | --- | --- |
| Rủi ro mục tiêu | 1%/lệnh | 0,25%/lệnh; có thể chọn cao hơn trong trần |
| Trần mỗi lệnh | 2% ở các gate | 3%, theo yêu cầu người dùng |
| Ngày | Tắt ở EA quyết định; Auto Trader chưa có gate ngày | Tối đa 6%; dự phòng cả rủi ro lệnh mới |
| Ngân sách đã dùng trong ngày | Chưa có | Dựng lại từ các deal mở hôm nay và SL ban đầu; thắng không hoàn lại ngân sách |
| Tổng exposure | Chủ yếu hiển thị thông tin | Gate mặc định 3%, gồm pending và đề xuất mới |
| Vốn tính lot | Có thể dùng reference lớn hơn vốn hiện tại | `min(reference bảo vệ, Balance, Equity)` trong hai EA quyết định / Auto Trader |
| SL hoặc định giá chưa rõ | Có thể chỉ được ghi nhận trong thông tin portfolio | Chặn thêm rủi ro qua các đường đã tích hợp |
| Margin Auto Trader | Chỉ kiểm tra đủ free margin | Thêm `OrderCheck.margin / OrderCheck.equity <= 20%` |
| Bảng bên phải | Nhiều trang; mặc định một symbol | Một trang; mặc định toàn tài khoản, gồm thủ công / EA khác / pending |
| Quote của hai EA quyết định | 60 giây | 10 giây |

### Một trang để quan sát nhanh

12 dòng cố định: bảo vệ tự động, P/L đang mở, rủi ro SL + chờ, phần có thể giảm thêm tới SL, P/L ngày, risk ngày đã dùng + chờ, dư địa sau SL, margin, Balance/Equity, số vị thế/pending, vị thế rủi ro nhất, trần lệnh/ngày. TP/RR, giá vào, SL/TP và chi tiết từng vé nằm trong tooltip.

Đỏ cho lỗi, số âm hoặc dữ liệu rủi ro chưa đầy đủ; vàng khi gần trần hoặc bảo vệ chưa bật; xanh cho P/L dương và bảo vệ đang giám sát; các dòng khác xen kẽ nền tối. Màu luôn có nhãn chữ. Từ 80% ngân sách tổng chuyển vàng, vượt trần chuyển đỏ. Margin/Equity từ 20% chuyển vàng, từ 33,33% chuyển đỏ; đây là cảnh báo hiển thị, không tự đóng lệnh.

Mặc định 420 × tối đa 420 px. Font tự giảm khi cần; cửa sổ quá thấp ưu tiên các dòng đầu và ghi rõ số mục đang hiện, không tạo trang thứ hai. Nếu chọn một symbol, bảng ghi rõ phạm vi và không suy ra dư địa toàn tài khoản từ dữ liệu một phần. Thiếu SL/định giá phải hiện **CHƯA ĐỦ**, không đổi thành 0% rủi ro.

### Công thức và hành động đã triển khai

Với mỗi vị thế, dùng tiền tệ tài khoản, khối lượng còn mở, entry thực tế và `OrderCalcProfit()`:

```text
net_at_stop = gross_P/L(entry -> SL) + swap - dự phòng phí
risk_from_entry = max(0, -net_at_stop)
additional_equity_risk = max(0, floating_profit_plus_swap - net_at_stop)
```

Cộng từng khoản không âm, không lấy lời của lệnh này bù rủi ro lệnh khác. Ví dụ lệnh đang lời 500 USD, SL giữ 13 USD sau phí: rủi ro mất vốn từ entry là 0 nhưng vẫn có thể trả lại **487 USD** từ Equity hiện tại. Cả bảng và gate tổng đều xét khoản thứ hai.

```text
capital = min(reference bảo vệ, Balance hiện tại, Equity hiện tại)
new_trade_risk <= capital * 3%
sum(risk_from_entry) + pending_risk + new_trade_risk <= capital * portfolio_limit
sum(additional_equity_risk) + pending_risk + new_trade_risk <= capital * portfolio_limit
```

Lệnh chờ dùng volume còn lại, entry dự kiến, SL và dự phòng phí; stop-limit dùng giá limit. Thiếu SL, sai phía SL hoặc lỗi định giá làm ngân sách chưa đủ dữ liệu. Các gate chỉ kiểm soát đường giao dịch đã tích hợp; không ngăn được người dùng hoặc EA khác gửi lệnh trực tiếp tới broker.

Mỗi lệnh đã được tính lot theo ngân sách, làm tròn xuống bước lot, cộng commission/dự phòng và trượt giá SL, kiểm tra tick grid, stop/freeze, quote, spread, RR ròng tối thiểu 2 và margin. Auto Trader thêm dự phòng giá vào, `OrderCheck()`, rồi kiểm tra lại protection, reference, exposure và ngân sách trước `OrderSend()`.

### Hai chốt ngày

**Chốt lỗ:** `day_net` = tổng profit + swap + commission + fee trên deal BUY/SELL từ 00:00 giờ broker, cộng profit + swap của mọi vị thế đang mở. Chặn nếu không đọc đủ lịch sử, `day_net <= -daily_budget`, hoặc sau khi trừ thêm rủi ro từ hiện tại tới SL, pending và lệnh mới sẽ vượt lỗ ngày. Ví dụ vốn 10.000 USD, budget 600 USD, `day_net=-400`, lệnh mới risk 300 USD: bị chặn vì kịch bản tới SL thành âm 700 USD.

**Chốt ngân sách đã dùng:** đọc các deal `IN`/`INOUT` hôm nay, lấy giá khớp, volume và SL gốc trên history order, ước lượng risk + dự phòng phí; cộng cả lệnh đã đóng. Chặn khi `spent_risk + pending_risk + new_trade_risk > daily_budget`. Ví dụ đã dùng 5,5% risk hôm nay, lệnh kế tiếp 1% bị chặn ngay cả khi các lệnh trước đều thắng. Dựng lại từ lịch sử broker giúp giữ ngân sách sau restart; không phụ thuộc biến đếm trong RAM. Exit/partial close không hoàn lại ngân sách; reversal `INOUT` được tính trên toàn volume để dự phòng thận trọng.

**Giới hạn của phép đo:** `day_net` không phải drawdown từ Equity đầu ngày. Floating giữ qua đêm được tính toàn bộ; broker hạch toán commission bằng loại deal riêng ngoài BUY/SELL có thể chưa được cộng. Dự phòng tại SL có thể chồng commission đã ghi trong ngày. Ngân sách đã dùng là ước lượng theo SL gốc, chi phí cấu hình và điều kiện định giá hiện tại; chưa phải sổ ghi bất biến của risk dự kiến tại thời điểm gửi. Giao dịch mở không có SL gốc hoặc thiếu history order làm chốt cộng dồn chưa xác định và chặn mở thêm. Không dựng lại SL gốc bằng SL trailing hiện tại.

Chưa có latch lỗ ngày lưu bền vững dựa trên Equity đầu ngày; nếu chạm lỗ do floating rồi hồi phục, chốt lỗ có thể cho phép lại nếu ngân sách cộng dồn còn đủ. Cần bổ sung latch để đáp ứng quy tắc dừng hết ngày sau lần chạm ngưỡng đầu tiên. Các mức 3%/6% là giới hạn tính toán và cấp phép mở mới, không bảo đảm lỗ thực thi không vượt khi gap/trượt giá.

### Margin, SL và controller khẩn cấp

`OrderCalcMargin()` không tính đầy đủ ảnh hưởng vị thế và pending hiện có. Auto Trader dùng thêm kết quả `OrderCheck()` và trần margin 20% Equity, tương đương margin level 500% khi margin dương. Mức này không đo trực tiếp gross leverage và không bảo đảm an toàn khi gap. Stop Out broker có thể theo % hoặc tiền tệ; phải đọc đúng đơn vị. [MQL5 — OrderCalcMargin](https://www.mql5.com/en/docs/trading/ordercalcmargin), [account margin settings](https://www.mql5.com/en/book/automation/account/account_margin).

Đặt SL thực phía server ngay trong yêu cầu mở lệnh, kiểm tra server chấp nhận. Không dựa riêng vào SL ảo/trailing/EA: MetaTrader xử lý SL/TP phía server còn trailing ở platform. SL vẫn có thể khớp kém hơn mức đặt khi giá nhảy hoặc thiếu thanh khoản. [MetaTrader — Executing Trades](https://www.metatrader5.com/en/terminal/help/trading/performing_deals), [SEC Investor.gov — Stop Orders](https://www.investor.gov/introduction-investing/general-resources/news-alerts/alerts-bulletins/investor-bulletins-15).

Không thay đổi hành động đóng lệnh của controller trong đợt này: reference vẫn là Balance lưu từ lần đầu, ngưỡng khẩn cấp mặc định 3% lỗ thả nổi của **một vị thế**, có thể hủy pending và đóng **toàn tài khoản** khi đã được bật/đúng xác nhận. Đây không phải controller lỗ ngày 6%. Hàm policy tham khảo 3%/5% trong module telemetry cũng không phải lệnh tự đóng đang chạy. Không tự bật quyền đóng toàn tài khoản hoặc sửa SL-TP khi cập nhật giao diện.

Nếu dùng target gần trần 3%, cần demo riêng tương tác giữa SL 3%/lệnh và controller khẩn cấp 3%/vị thế: dự phòng phí có thể khiến controller đóng toàn tài khoản trước khi SL từng lệnh xử lý xong. Không giảm ngưỡng emergency xuống dưới risk đã cho phép mỗi lệnh mà chưa thiết kế lại hành động và cảnh báo.

## Đề xuất bảo toàn vốn tiếp theo

Các mục dưới **chưa được triển khai** trong đợt này:

| Lớp | Đề xuất | Mục đích |
| --- | --- | --- |
| Equity ngày | Snapshot đầu ngày theo giờ broker, lưu bền vững, điều chỉnh nạp/rút; latch sau lần chạm 6% hoặc mức thấp hơn người dùng chọn | Dừng hết ngày kể cả restart hoặc floating hồi phục |
| Tuần / toàn kỳ | Ngưỡng nghỉ tuần và drawdown đỉnh Equity; khởi thảo thận trọng 3%/tuần, 5% toàn kỳ để người dùng đánh giá | Có thể chặn sớm hơn trần ngày 6%; chưa thể coi các con số là tối ưu |
| Tương quan | Một cụm cùng USD/chỉ số/vàng có trần riêng thấp hơn tổng 3% | Không coi nhiều mã là độc lập |
| Nhịp giao dịch | Nghỉ, rà soát sau 3 lệnh thua liên tiếp; không martingale / tăng lot để gỡ | Hạn chế tích lũy rủi ro khi điều kiện đổi |
| Tin, phiên, spread | Không mở quanh tin mạnh/rollover; hiệu chỉnh spread, slippage theo ATR hoặc khoảng SL và từng broker | Không áp một số điểm cố định cho mọi tài sản |
| Vận hành | VPS, heartbeat ngoài terminal, cảnh báo bảo vệ offline, kiểm tra SL trên server | Terminal không tự báo được khi chính nó đã dừng |
| Broker | Xác minh đúng pháp nhân, điều kiện rút tiền, bảo vệ số dư âm | Bảo vệ phần vốn ngoài phạm vi logic EA |

Với chiến lược chưa nghiệm thu ngoài mẫu sau phí, đề xuất tiếp tục demo hoặc giữ target 0,10–0,25% thay vì dùng hết 3%. Không dùng điểm ICT hoặc xác suất DNN để tăng lot khi chưa có ước lượng lợi thế đáng tin cậy. Trần 3%/6% đáp ứng yêu cầu; tự chúng không chứng minh chiến lược có lợi nhuận.

## Căn cứ nghiên cứu

1. [CME — Proper Position Size](https://www.cmegroup.com/education/courses/trade-and-risk-management/proper-position-size): đặt SL hợp lý và ngân sách trước, tính lot sau. Áp dụng bằng định giá broker và làm tròn lot xuống.
2. [CME — The 2% Rule](https://www.cmegroup.com/education/courses/trade-and-risk-management/the-2-percent-rule): 2% là một ví dụ quản lý rủi ro, không phải mức tối ưu bắt buộc. Các trần 3%/6% là yêu cầu người dùng; target 0,25%, cap tổng 3% và margin 20% là đề xuất thiết kế của dự án.
3. [CME — Risk Management and Your Trade Plan](https://www.cmegroup.com/education/courses/building-a-trade-plan/risk-management-and-your-trade-plan): cần xác định đòn bẩy, lỗ mỗi lệnh, lỗ ngày và tổng exposure. Đây là cơ sở cho các gate tách biệt.
4. [CME — Controlling Risk](https://www.cmegroup.com/education/courses/trade-and-risk-management/controlling-risk): rủi ro theo phần trăm vốn giúp giảm tốc độ sụt vốn trong chuỗi thua; không loại trừ chuỗi thua hay bảo đảm lợi nhuận.
5. [MQL5 — OrderCalcProfit](https://www.mql5.com/en/docs/trading/ordercalcprofit): P/L ước lượng trong tiền tệ tài khoản, theo điều kiện thị trường; không dùng một giá trị pip cố định cho mọi mã.
6. [MQL5 — OrderCalcMargin](https://www.mql5.com/en/docs/trading/ordercalcmargin), [account margin settings](https://www.mql5.com/en/book/automation/account/account_margin): phân biệt margin, free margin, margin level, đơn vị Stop Out và giới hạn phép tính giả định.
7. [MetaTrader — Executing Trades](https://www.metatrader5.com/en/terminal/help/trading/performing_deals): phân biệt SL/TP trên server và trailing ở platform; giữ SL thực, xem EA là lớp bổ sung.
8. [SEC Investor.gov — Stop, Stop-Limit, and Trailing Stop Orders](https://www.investor.gov/introduction-investing/general-resources/news-alerts/alerts-bulletins/investor-bulletins-15): giá stop không bảo đảm giá khớp; stop-limit có thể không khớp. Nguồn nói về chứng khoán Mỹ; cơ chế sản phẩm MT5 phải đối chiếu broker.
9. [FCA — Contract for differences](https://www.fca.org.uk/firms/contract-for-differences): khách hàng CFD retail thuộc đúng phạm vi FCA có các bảo vệ đòn bẩy, margin close-out, số dư âm. Không mặc định tài khoản Việt Nam/offshore được hưởng. Close-out 50% là tỷ lệ so với margin cần duy trì, không phải cho phép mất 50% vốn.
10. [CFTC — Eight Things You Should Know Before Trading Forex](https://www.cftc.gov/LearnAndProtect/AdvisoriesAndArticles/CustomerAdvisory_MustKnowForex.html): rủi ro OTC dealer, đòn bẩy và từ chối rút tiền; chọn pháp nhân/broker cũng là quản lý rủi ro. Quy định Mỹ không áp nguyên xi cho nơi khác.

Tự tính minh họa, không phải backtest: sụt vốn sau `n` lệnh thua đúng `r` của vốn còn lại là `1-(1-r)^n`. Chưa gồm phí/gap và chưa áp dừng ngày:

| Risk/lệnh | 10 lệnh thua | 20 lệnh thua |
| ---: | ---: | ---: |
| 0,25% | 2,472% | 4,883% |
| 0,50% | 4,889% | 9,539% |
| 1,00% | 9,562% | 18,209% |
| 2,00% | 18,293% | 33,239% |
| 3,00% | 26,258% | 45,621% |

## Áp dụng và kiểm tra

Nạp [preset 3% / 6%](ICT_LIVE_CONSERVATIVE.set) vào hai EA quyết định 1.11 hoặc đặt Inputs theo [cấu hình](CONFIGURATION.md). Preset chỉ thay trường được liệt kê, không tự hiệu chỉnh phí, spread, slippage hoặc các quyền tự động khác đã lưu. Chart/set cũ có thể giữ cap 2%, ngày tắt và chỉ một symbol; cập nhật EX5 không tự cập nhật Inputs. Ngày bằng 0 hiện bị từ chối; cần cập nhật cấu hình.

Kiểm tra thuật toán mới nhất: **616/616** qua adapter C# chạy các hàm MQL thuần, gồm trần 3%/6%, cộng dồn ngày, không hoàn ngân sách sau thắng, thiếu history SL, pending và lợi nhuận có thể trả lại. Đây không phải giao dịch MT5, backtest hay nghiệm thu broker. Xem [core fixtures](../Tests/Reports/ICT_UNIFIED_CORE_FIXTURES.txt) và mục 1.11 trong [ma trận cập nhật](MTF_SMT_OB_GAP_MATRIX.md) về biên dịch và giới hạn kiểm tra hình ảnh.

Trước khi nghiệm thu thực tế cần thử SL server, Netting/Hedging, partial fill/close, pending/stop-limit, history SL gốc, phí, qua ngày broker, restart, disconnection, reject/requote và hết retry. Các gate không thể bảo đảm mức lỗ tối đa khi thực thi kém hơn dự phòng. Xem [kế hoạch Phase 2](../Tests/Phase2_Test_Plan.md) và [các vấn đề còn mở](OPEN_ISSUES.md).

## Cơ chế controller hiện hữu

The planner and advisory components provide **previews only**. The separate protection EA monitors the entire account and can cancel pending orders and close positions; it never opens a new trade or applies planned SL/TP.

The risk budget is preview capital × risk percent / 100. Estimated loss uses `OrderCalcProfit()` at the planned stop moved adversely by the configured slippage, plus known commission and the unspecified-cost buffer. The lot is rounded down to the broker step and checked again against the budget. Net estimated reward subtracts the same round-turn cost reserve. A plan is blocked if RR falls below 2, the minimum lot exceeds the budget, symbol data is invalid, prices violate the tick or stop constraints, the quote is stale, or estimated free margin is insufficient.

The protection reference is the balance saved on first activation and bound to account login and server; deposits and withdrawals do not automatically change it. Each position's estimated floating net P/L includes position profit and swap, available deal commissions and fees, an exit-cost reserve and, when history is unavailable, an additional configured reserve. Default warning levels are 1%, 2%, and 2.5% loss relative to the reference. With automatic protection enabled, the default emergency threshold is 3% loss on **one** position. The threshold is configurable, and takes precedence over any higher warning level. Disarming retains an existing latch but withholds further close requests; account-wide closing requires automatic protection and the correct account confirmation.

The emergency applies to **all** account positions and pending orders, including those opened manually or by other EAs. The emergency state, trigger ticket, time and equity are saved before any close/cancel request. An exclusive account file allows only one controller; attempts use tickets, bounded retries and delays, logged trade-server retcodes, and a subsequent existence check. Retry counts are per EA session. If the initial emergency state cannot be saved, close requests are withheld. After exposure is cleared, the controller remains locked and processes newly opened exposure. Failures or unavailable trading can produce CRITICAL status; restart does not automatically unlock the persistent state. An invalid or missing previously initialized state prevents automatic reinitialization. Reset requires the explicit [reset script](../Tests/ResetProtectionState.mq5) and account confirmation; consult the [installation instructions](INSTALLATION.md).

Neither the configured trigger nor broker-hosted Stop Loss can guarantee a maximum realized loss during gaps, slippage, disconnection, or terminal downtime. The controller requires a running terminal, connectivity and permission to trade; it cannot stop other EAs or manual trading from opening orders at broker level. Costs are estimates dependent on available history and configured reserves.

The protection code compiles, and a simulated Hedging fixture exercised cancellation of one pending order and closure of two positions. Threshold-driven behavior, restart persistence, Netting, disconnect, rejection, partial close and retry exhaustion remain unaccepted. See [open issues](OPEN_ISSUES.md) and the [Phase 2 test plan](../Tests/Phase2_Test_Plan.md); the fixture does not establish demo acceptance of the complete system.
