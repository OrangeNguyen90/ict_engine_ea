# MT5 Smart Risk Manager Pro

Nâng cấp Liquidity V2 ngày 2026-11-13: [audit, thay đổi, kết quả kiểm thử và các phần chưa nghiệm thu](docs/LIQUIDITY_V2_DELIVERY_20261113.md). Tài liệu bao gồm bản nguồn baseline; hiện chưa có backtest so sánh hoặc kết quả fixture MQL native mới.

Nâng cấp SmartDecision ngày 2026-11-09: [audit, ma trận yêu cầu 1–7 và hướng dẫn](docs/MASTER_MTF_DELIVERY_20261109.md).
Delta prompt đa khung ngày 2026-11-10: [triển khai, giới hạn và bằng chứng kiểm thử](docs/MASTER_MTF_DELIVERY_20261110.md).
EA hiện có dùng snapshot chung cho ba khung bắt buộc, hai peer SMT độc lập,
OB có trọng số/lifecycle, liquidity sweep/breakout/retest và lịch sử BUY/SELL
được lưu theo nến đóng. Không bật thêm quyền giao dịch hoặc đổi policy vốn.
Kết quả account-free không thay thế Strategy Tester/backtest/visual acceptance.

Kiến trúc đích gồm **ICT Smart Decision Engine** và **EA Smart Risk Manager Pro**, theo [master prompt](docs/MASTER_PROMPT.md), [kiến trúc và kế hoạch](docs/ICT_ARCHITECTURE.md) và [feature matrix](docs/FEATURE_MATRIX.md). Việc hợp nhất chưa hoàn thành. Theo yêu cầu bổ sung, ICTAutoTraderEA 1.30 là EA riêng có thể tự mở lệnh khi bật rõ ràng; chưa có bằng chứng runtime cho thay đổi này. File EX5 đã cài trong MT5 không tự cập nhật từ workspace. Xem [hướng dẫn ICT Auto Trader](docs/ICT_AUTO_TRADER.md).

Hai EA chuyển tiếp: [ICTSmartDecisionEngineEA](Experts/ICTSmartDecisionEngineEA.mq5) dùng lại DecisionSupport và có đề xuất symbol SMT từ Market Watch; [EASmartRiskManagerPro](Experts/EASmartRiskManagerPro.mq5) dùng lại controller bảo vệ. Hai điểm vào này chưa hoàn tất hợp nhất chức năng hoặc tích hợp risk calculator. Không gắn đồng thời EA bảo vệ mới và `RiskProtectionEA` cho cùng tài khoản. ICTAutoTraderEA được giữ riêng theo yêu cầu bổ sung.

Trên biểu đồ của hai EA quyết định, `Chart_Zone_Timeframe` mặc định là `PERIOD_CURRENT`: chỉ vẽ vùng thuộc khung thời gian của biểu đồ. Có thể chọn một khung đang được EA phân tích để xem các vùng của khung đó; nếu khung được chọn không có dữ liệu phân tích thì không có vùng tương ứng. Các vùng giá trùng nhau được ưu tiên theo thứ tự vẽ, với vùng vào lệnh đã xác nhận được ưu tiên trước; nền Premium/Discount được giữ riêng làm bối cảnh. Dashboard Smart cho biết khung vùng và số vùng bị ẩn do trùng lặp. Chú thích trên biểu đồ không có khung; cỡ chữ hiển thị bằng 75% giá trị `Chart_Label_Font_Size` từ 8 đến 16, chẳng hạn giá trị 10 hiển thị thành 8 sau khi làm tròn. Cỡ hiển thị được làm tròn đến số nguyên. Nhãn tự tránh nhau và dashboard khi đổi kích thước hoặc cuộn biểu đồ; nếu không đủ chỗ, nhãn được ẩn. Di chuột vào vùng hoặc tín hiệu tương ứng để xem tooltip chi tiết khi có. Việc lọc chỉ ảnh hưởng hiển thị, không thay đổi tính toán hay điều kiện giao dịch.

Dashboard ICT dùng tiếng Việt và mặc định rộng 380 pixel. Trong Inputs, đặt `Dashboard_Width` từ 300 trở lên để đổi chiều rộng; cấu hình EA đã lưu trước đó có thể vẫn giữ giá trị cũ. Các mã kỹ thuật và ID được giữ nguyên, còn chẩn đoán chưa có bản dịch được hiện kèm nội dung gốc để không mất thông tin. Nhãn phân tích được xếp theo pixel với khoảng cách tối thiểu 4 pixel; khi quanh một vị trí không còn chỗ, nhãn ưu tiên thấp sẽ tạm ẩn và xuất hiện lại nếu có chỗ sau khi đổi kích thước hoặc di chuyển biểu đồ.

Smart Decision EA có tùy chọn thử nghiệm [tự đặt SL/TP theo kế hoạch](docs/SMART_DECISION_SLTP.md) cho vị thế mới cùng symbol; mặc định tắt và chưa được nghiệm thu runtime.

Ứng dụng Django nghiên cứu ICT đã được đưa vào [ai/](ai/). Xem [hướng dẫn tích hợp MT5 và AI](docs/MT5_AI_INTEGRATION.md) để thiết lập và chuyển dữ liệu nến đã đóng từ MT5 sang ứng dụng. Hai bộ phân tích vẫn dùng quy tắc độc lập; kết quả AI mang tính nghiên cứu và không điều khiển giao dịch.

Current extension: [ICT Internal/External Range Liquidity delivery](docs/IRL_ERL_DELIVERY.md), [audit/design](docs/IRL_ERL_DESIGN.md), and [verification](docs/IRL_ERL_VERIFICATION.md). The new range mode extends the existing engine; it remains advisory-only. Runtime and visual acceptance must be checked separately from compilation.

Offline statistical signal research is documented in [the research proposal](docs/STATISTICAL_SIGNAL_RESEARCH_20261118.md), [the export, audit and replay guide](docs/RESEARCH_EXPORT.md), and [the ML research design](docs/ML_RESEARCH.md). The optional RR study compares a fixed target grid using net-R regression, with a deep feedforward MLP and normalized closed-candle windows as research options. This work is separate from the production ICT decision path; no broker-history outcome or live probability has been validated yet.

Both Smart and DecisionSupport **1.04** now show [local ML/DL price statistics](docs/ML_PREDICTION_EA.md) by default: logistic and a two-hidden-layer neural classifier learn from closed MT5 candles, estimate up/down/neutral moves over a defined horizon, and report a chronological validation baseline plus four pattern families. The optional frozen Python snapshot feed is also available in both EAs and retains its model/source/time gates. Neither path changes native ICT signals or SL/TP. Synthetic fixtures and compilation do not establish market profitability; replacing installed EX5 files and reattaching the EA are required to load this version.

Latest delivery: [ICT Smart upgrade and validation, 2026-11-04](docs/ICT_SMART_DELIVERY_20261104.md), with [module audit](docs/ICT_SMART_AUDIT_20261104.md). All 14 MQL5 programs compile with zero errors/warnings. Both fresh Tester attempts stopped before EA initialization because no tester account was specified; runtime and visual acceptance remain incomplete. The older Phase 4 gate below is historical planning context; the current request authorized the advisory implementation described in the latest delivery.

The copied development workspace includes an experimental ICT decision engine in the calculation service and an optional standalone EA. See [ICT architecture](docs/ICT_ARCHITECTURE.md), [delivery and acceptance status](docs/ICT_ACCEPTANCE.md), and the [research/specification draft](docs/ICT_RESEARCH_AND_SPEC.md). The modified programs have compiled, but their runtime behavior and trading outcomes have not been tested.

Phase 1 provides a **trade planner** for a multi-asset MT5 chart. The custom indicator draws draggable planned Entry, Stop Loss, and Take Profit lines. A separate calculation-only EA estimates the maximum lot, cash risk, reward, RR, costs, and margin using broker data. Phase 2 adds an account-wide protection EA. Phase 3 adds a closed-bar ICT/SMC advisory panel. The planner and advisor never send or modify trades; the protection EA sends only emergency cancel/close requests.

## Architecture

| Component | Responsibility |
| --- | --- |
| `Indicators/SmartRiskDashboard.mq5` | Planned lines, account and actual-position display, buttons, input settings. |
| `Experts/RiskCalculationService.mq5` | Receives a plan and calls `OrderCalcProfit()` and `OrderCalcMargin()`; publishes a result. No trade calls. |
| `Include/RiskCalculator.mqh` | Risk, RR, lot-step, quote-age, stop-distance, and margin gates. |
| `Include/SymbolSpecification.mqh` | Reads and validates broker point, tick, contract, volume, and stop specifications. |
| `Include/RiskTypes.mqh` / `RiskBridge.mqh` | Shared result types and numeric chart-to-EA message protocol. |
| `Include/DashboardComponents.mqh` | Chart object layout. |
| `Experts/RiskProtectionEA.mq5` | Account-wide risk scan, persistent initial-balance reference, emergency close and lock. |
| `Include/PositionMonitor.mqh` | Per-position floating net-loss calculation, including available deal costs. |
| `Include/EmergencyController.mqh` | Cancel pending orders, close positions by ticket, verify results, bounded retries. |
| `Include/ProtectionPersistence.mqh` | Account/server-bound reference and lock state in an on-disk snapshot. |
| `Tests/ResetProtectionState.mq5` | Explicit one-shot reset script requiring account confirmation. |
| `Include/MarketStructure.mqh`, `LiquidityDetector.mqh`, `FVGDetector.mqh`, `TradeAdvisor.mqh` | Closed-bar setup analysis and risk-gated advisory. |
| `Include/AdviceBridge.mqh` | Per-chart numeric advisory message protocol. |
| `Experts/TradingAdvisoryEA.mq5` | Optional standalone advisory with an Order Block overlay and Experts log. |
| `Include/MarketContext.mqh` | Read-only closed-bar market-context snapshot for chart overlays. |

MQL5 prohibits `OrderCalcProfit()` and `OrderCalcMargin()` inside custom indicators. Attach **both** the indicator and `RiskCalculationService` to the same chart, using the same `Instance_ID`. MT5 permits only one EA on a chart: attach `RiskProtectionEA` to another chart, and do not substitute the standalone `TradingAdvisoryEA` for the calculation service. If the service is absent or its result is stale, the plan remains BLOCKED.

## Scope and assumptions

- Defaults are `Risk_Per_Trade=0.25%`, `Max_Risk_Per_Trade=3%`, and `Minimum_RR=2`. The per-trade ceiling is 3% and the DecisionSupport/Smart 1.11 / Auto Trader 1.31 daily ceiling is 6%, as requested. New-entry gates also reserve pending and SL risk, with an optional cumulative daily-risk budget enabled by default. Lot is rounded down; minimum lots exceeding budget are blocked. See the [live-account risk review](docs/RISK_POLICY.md) and [preset](docs/ICT_LIVE_CONSERVATIVE.set). Updating EX5 does not change saved Inputs.
- Phase 1's capital input defaults to **current balance** (`Use_Equity_As_Reference=false`). It is a provisional planning baseline. The Phase 2 protection EA separately stores an account/server-bound `INITIAL_BALANCE` reference on first activation and does not raise it or reset it after restart or deposits/withdrawals.
- BUY PREVIEW initializes Entry from Ask and SELL PREVIEW from Bid. After dragging, Entry is a hypothetical price. Spread is reflected in the initialized market side and displayed separately. The estimator includes configured adverse stop slippage and round-turn commission plus an unspecified-cost buffer. Defaults are 2 points of slippage and 10 account-currency units per lot of cost buffer. Adjust them for the broker and asset. These estimates cannot guarantee actual fills or costs.
- Prices must align with the symbol's tick size. The symbol specification must be valid, quotes fresh, and the terminal connected. The planned SL and TP must exceed the broker's stop/freeze distance from planned Entry. The EA checks free margin for the calculated volume; actual margin can differ because `OrderCalcMargin()` does not include all existing-position effects.
- Forex symbols with a 3 or 5 digit quote show pips, points, and ticks. Metals, indices, energy, and futures show points and ticks. The calculator uses broker-aware `OrderCalcProfit()`, without a fixed Forex pip-value formula.
- The dashboard distinguishes **planned** lines from the **actual** position. It shows the first current-symbol position by ticket and a count if there are more. Actual floating P/L includes swap but may omit already-incurred commission that is not exposed as a position property.
- `PLAN: VALID PREVIEW` means only that the numeric Phase 1 gates passed. It is not a trading signal or account protection state.

## Phase 2 protection

Default policy: monitor **every open position**; when the estimated net floating loss on any one position reaches 3% of the saved reference capital, persist an emergency lock, cancel all account pending orders, and close all account positions by ticket. The EA checks each trade-server response and whether the order or position still exists. Attempts are bounded per ticket, with delays. Another chart running the EA becomes passive while one account controller holds an exclusive file lock. A locked controller continues canceling/closing exposure opened by other programs after the first emergency.

The dashboard reads the controller heartbeat and shows `EA OFFLINE` if it stops. This is terminal-side protection: MT5/VPS and broker connectivity are required. It cannot prevent manual trading or other EAs from opening new trades at broker level. Phase 2 has compiled cleanly; a simulated Hedging test passed cancellation of one pending order and closure of two positions. Threshold-driven production behavior, restart, Netting, disconnection, and rejection scenarios still require demo/Tester evidence before operational acceptance.

## Phase 3 advisory

The calculation service publishes a per-chart advisory and a separate closed-bar market-context snapshot about every five seconds when enabled. The left dashboard panel shows NO TRADE, WAIT, or TRADE READY (advisory only), plus H4/H1 swing levels, BOS/MSS, M15 FVG, equilibrium and previous-day liquidity. Optional overlays draw the latest confirmed levels and advisory Entry/SL/TP. TRADE READY requires a healthy, unlocked protection controller, aligned H4/H1 structure, a closed H1 BOS, an unmitigated M15 FVG, a previous-day sweep, a closed M5 trigger, and passing spread, risk, RR, lot, and margin gates. A stale or offline service clears the active plan. The optional standalone advisory EA writes analysis to the Experts log and never sends orders. These deterministic definitions are experimental and have not been market-validated. See the [Phase 3 recovery report](Docs/PHASE3_FIX_REPORT.md) and [gap analysis](Docs/GAP_ANALYSIS.md) before interpreting the panel.

See [installation](Docs/INSTALLATION.md), [configuration](Docs/CONFIGURATION.md), [risk policy](Docs/RISK_POLICY.md), [advisory rules](Docs/ADVISORY_RULES.md), [Phase 1 test plan](Tests/Phase1_Test_Plan.md), [Phase 2 test plan](Tests/Phase2_Test_Plan.md), [Phase 3 test plan](Tests/Phase3_Test_Plan.md), [test report](Docs/TEST_REPORT.md), and [open issues](Docs/OPEN_ISSUES.md). The [Phase 4 plan](Docs/PHASE4_IMPLEMENTATION_PLAN.md) remains gated on Phase 3 runtime acceptance.

## Isolated ICT verification

Run these commands from the project root. `-ExecutionPolicy Bypass` applies only
to the launched PowerShell process; it does not change the system policy.

```powershell
# Complete account-free verification: regression tests, algorithms, preparation,
# seven Tester builds and four offline-script builds. Writes the JSON report.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tests\RunICTTests.ps1 -Mode Verify

# Account-free algorithm fixtures (mechanical MQL-to-C# adapter, not MT5 execution).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tests\RunICTTests.ps1 -Mode CoreFixtures

# Runner regression tests with Windows PowerShell's installed Pester module.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Pester -Script .\Tests\ICTTestRunner.Tests.ps1 -EnableExit"

# Prepare only, or compile one Tester expert with its shared headers.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tests\RunICTTests.ps1 -Mode Prepare
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tests\RunICTTests.ps1 -Mode Compile -Expert ICTDecisionTests
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tests\RunICTTests.ps1 -Mode Run -Config ict_decision.ini

# Run chooses the matching default config and recompiles current sources first.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tests\RunICTTests.ps1 -Mode Run -Expert ICTUnifiedTests

# Compile an offline MQL script without starting MT5.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tests\RunICTFixtures.ps1 -Suite ICTUnifiedTests -CompileOnly

# Execute that script in the isolated terminal (requires an initialized chart).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tests\RunICTTests.ps1 -Mode Fixtures -Expert ICTUnifiedTests
```

The [main runner](Tests/RunICTTests.ps1) still defaults to `Prepare`, not test
execution. `Verify` performs all 14 account-free steps and writes
[ICT_VERIFICATION.json](Tests/Reports/ICT_VERIFICATION.json), including each
step's exit code, output and duration. It records MT5 runtime, market backtests
and broker execution as `NotRun`; an offline verification pass does not imply
those have passed. A failed prerequisite is recorded as failed, with dependent
builds skipped and a nonzero exit code for the workflow.

Use `-Expert` with `Verify` to restrict its build matrix to one approved expert.
Use `-ReportPath` to select a different JSON report. `Prepare` and `Verify` accept
`-TerminalInstallPath` and `-MarketCachePath` for other local installations/cache
locations; paths may contain spaces. An unavailable market cache is reported
explicitly and does not block compiler-only checks.

No mode imports accounts or starts the installed trading terminal. `Run` uses
the expert named by an explicit config, or selects a matching default config
from `-Expert`. An explicitly supplied, different expert/config pair is rejected
before compilation. `Run` always rebuilds the selected expert and its headers
before starting the isolated Tester, so it cannot execute a stale build.
Timeouts, stale or ambiguous build logs, zero executed assertions and a Tester
that did not start fail with a nonzero exit code. Only newly appended runtime
logs are considered. Offline script initialization failures also fail the run,
even if no fixture failure has yet been counted.

Verified on 2026-11-09: 57 runner regression checks and 167 core algorithm checks
passed; all seven approved Tester experts and all four offline fixture scripts
compiled with zero errors and warnings. The missing shared fixture header and
the Range script's failure-counter mismatch are fixed. The core adapter can be
run repeatedly in the same PowerShell process without a duplicate type error.
Strategy Tester still cannot start without an account in the isolated runtime;
its account-free startup attempt fails with exit code 1. No MT5 assertion pass,
market backtest or broker-execution acceptance is claimed by these results.

The full 22-program workspace build also passes with zero errors/warnings.
See the [current delivery](docs/MASTER_MTF_DELIVERY_20261109.md) and the
[fresh isolated runtime attempt](Tests/Reports/ICT_RUNTIME_20261109.md).
