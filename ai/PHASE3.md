# ICT Market Analysis — Phase 3

## Audit and status

The existing Django project has `knowledge` (YouTube metadata, authorized transcript import, ICT knowledge/RAG, Ollama chat, API, and dashboard) and `market` (OHLCV import/validation and timeframe tools). PostgreSQL 17 is the configured production database. The market tables from Phase 2 are migrated. At the Phase 3 audit, `market_marketcandle` contained **0 rows**, so no real market series was available to verify an analysis. No OHLCV fixtures were inserted into production.

## Implementation

`market/engine.py` contains deterministic system interpretations, not claims that the exact numerical rules appear in ICT source material:

- Pivot swings use strict high/low comparisons across configurable left/right bars. Equal extrema are rejected. Confirmation is at the **close** of the final right-side candle. Labels HH/HL/LH/LL compare confirmed pivots of the same type. The configurable window is the external scope; 1/1 pivots are stored as internal scope when different.
- BOS/MSS require a candle **close** beyond a previously confirmed pivot, with optional minimum break/displacement settings in the engine. The first break establishes direction as BOS; an opposing break after direction is established is MSS.
- Three-candle FVGs use the strict high/low gap rule. Later candles update state: open, touched, partial, filled, or invalidated. The mitigation threshold is configurable as touch, half, or full. History retains the time of each transition.
- Liquidity zones arise from confirmed swings. EQH/EQL require another confirmed same-side pivot within the configured price tolerance. A wick through the zone followed by a close inside is a sweep; a close outside is a breakout.
- The dealing range uses the most recent confirmed swing and the preceding confirmed opposite swing. Invalid or unavailable anchors yield `insufficient_structure`. Equilibrium is the midpoint.

`market/services.py` fetches one OHLCV series, validates order and price ranges, runs the engines, and stores signals in an atomic transaction. `ICTAnalysisRun` records each run. `ICTSignal` records version, parameters, source, confirmation time, evidence candle IDs, payload, and state history with a unique deterministic key. Repeating a run does not duplicate signals. Historical `as_of` queries reconstruct state before later mitigation/sweep transitions.

The API endpoints are `/api/ict/candles/`, `/api/ict/swings/`, `/api/ict/market-structure/`, `/api/ict/fvg/`, `/api/ict/liquidity/`, `/api/ict/liquidity-events/`, `/api/ict/premium-discount/`, and `/api/ict/analysis/`. They require `symbol` and `timeframe`, support `start`, `end`, `as_of`, `data_source`, `status`, `signal_type`, and a limit up to 2000. An empty selection returns an explicit empty message. `POST /api/ict/explain/` asks local Ollama to explain stored evidence; its prose is labeled as a hypothesis and the structured evidence is returned separately.

`/market/` offers a native canvas candlestick view with timeframe/date controls, toggles, signal list, details, and time/price anchored overlays. It redraws on resize, zoom, and pan. Staff can trigger analysis from the page. The existing dashboard links to it.

## Windows operation

In PowerShell, with the project's environment configured:

```powershell
.\.venv\Scripts\Activate.ps1
python manage.py check
python manage.py migrate market
python manage.py import_market_data C:\data\EURUSD_H1.csv --symbol EURUSD --exchange OANDA --timeframe H1 --data-source licensed-export --source-timezone America/New_York
python manage.py analyze_market --symbol EURUSD --timeframe H1 --data-source licensed-export --exchange OANDA --left-bars 2 --right-bars 2
python manage.py runserver
```

Open `http://127.0.0.1:8000/market/`. CSV requires timestamp/open/high/low/close; Parquet uses the same columns and requires optional pandas and pyarrow installation. Import only data you are entitled to use. No importer or analysis command trades automatically.

Run isolated unit/integration tests without modifying production data:

```powershell
python manage.py test market knowledge --settings=ict_ai.settings_test
python manage.py makemigrations --check --dry-run
```

## Limits and acceptance

PostgreSQL test-database creation requires a role with `CREATEDB` or a precreated test database. The current role could not create `test_ict_ai_learning`. Source corrections now create a separate signal revision using a cumulative OHLCV fingerprint through confirmation. Old revisions remain available through their analysis run. Session gaps currently fail validation; a source-specific exchange calendar is needed to analyze markets across closures. The canvas renders a finite 2,000-row page and is intended for research, not execution.

Phase 3 **cannot be marked accepted** until a licensed real OHLCV series is imported, the engines and overlay are checked on it, and PostgreSQL integration tests can run against an isolated test database.

## Bàn giao cập nhật 2026-11-04

### Kiểm tra và kế hoạch đã thực hiện

Đối chiếu các app `knowledge`, `market`, cấu hình database, migrations, importer, API, engine, dashboard và bộ test hiện có. Phase 2 đã có nhập CSV/Parquet, provenance, chuẩn hóa UTC, validation OHLCV và công cụ timeframe. Phase 3 đã có engine và API nhưng còn thiếu bảo vệ nến chưa đóng, lịch sử range, trạng thái FVG đơn điệu và phân biệt các bộ kết quả khi thay đổi tham số/dữ liệu.

Thứ tự triển khai: sửa engine → kiểm thử hồi quy → sửa orchestrator/lưu trữ → migration bổ sung → API/dashboard → kiểm tra trên PostgreSQL và trình duyệt. Giữ nguyên kiến trúc Django và dữ liệu cũ.

### Tệp đã sửa hoặc tạo trong lần cập nhật này

| Tệp | Thay đổi |
| --- | --- |
| [engine.py](market/engine.py) | Phiên bản `system-ict-2`; kiểm tra timezone, volume và khoảng trống; EQH/EQL cho swing bằng giá; FVG không lùi trạng thái; BOS không tái sử dụng mức cấu trúc cũ; lưu tolerance của liquidity |
| [services.py](market/services.py) | Chỉ phân tích nến đã đóng; cutoff `as_of`; displacement/mitigation; lưu các range lịch sử; khóa bao gồm series, cấu hình và fingerprint dữ liệu; danh sách signal của mỗi run |
| [models.py](market/models.py) | Thêm `ICTAnalysisRun.signal_keys` |
| [0003_ictanalysisrun_signal_keys.py](market/migrations/0003_ictanalysisrun_signal_keys.py) | Migration bổ sung JSONField, không xóa hoặc sửa nến |
| [views.py](market/views.py) | API chọn run mới nhất hoặc `run_id`; lọc phiên bản/series; status trước limit; loại nến đang mở; giải thích chỉ dùng signal của run hiện hành |
| [analysis.html](market/templates/market/analysis.html) | Chọn sàn/hợp đồng/loại giá; bật/tắt sweep; vùng Premium/Discount hai màu; đường BOS/MSS/equilibrium; giữ vùng bắt đầu ngoài cửa sổ xem; phân biệt vùng hết hiệu lực |
| [analyze_market.py](market/management/commands/analyze_market.py) | Thêm `--mitigation` và `--require-displacement` |
| [audit_market.py](market/management/commands/audit_market.py) | Lệnh chỉ đọc báo backend, số nến, series và provenance nhập liệu; không in mật khẩu |
| [test_analysis.py](market/test_analysis.py) | Hồi quy FVG, dữ liệu lỗi/gap, replay độc lập từng prefix cho các nhóm signal, phiên bản dữ liệu/cấu hình, lịch sử as_of, status/limit và tránh BOS lặp |
| [PHASE3.md](PHASE3.md) | Kế hoạch, kết quả thực tế và hướng dẫn bàn giao |

### Models và migration

Tiếp tục sử dụng `MarketCandle` làm PriceCandle; unique key gồm symbol/exchange/contract/timestamp/timeframe/source/price type, giá Decimal và FK provenance đến `ImportBatch`. `ICTSignal` lưu các category swing, structure, fvg, liquidity, liquidity_event và dealing_range thay vì tạo sáu bảng trùng cấu trúc. Signal có unique SHA-256, indexes, version, parameters, thời điểm hình thành/xác nhận, evidence IDs, payload và lịch sử chuyển trạng thái. `ICTAnalysisRun` ghi số nến, mốc cuối, cấu hình và danh sách khóa kết quả. Toàn bộ lưu kết quả nằm trong transaction.

`0003` đã áp dụng thành công trên PostgreSQL của ứng dụng. Migration `0001`, `0002` giữ nguyên. Phiên bản thuật toán cũ không bị xóa; API mặc định `system-ict-2`. Chạy lại phân tích để có bộ kết quả phiên bản mới sau khi có nến thực.

### Chạy và kiểm tra trên Windows

```powershell
.\.venv\Scripts\python.exe manage.py check
.\.venv\Scripts\python.exe manage.py migrate --noinput
.\.venv\Scripts\python.exe manage.py audit_market
.\.venv\Scripts\python.exe manage.py test --settings=ict_ai.settings_test
.\.venv\Scripts\python.exe manage.py makemigrations --check --dry-run
.\.venv\Scripts\python.exe manage.py analyze_market --symbol EURUSD --timeframe H1 --data-source licensed-export --exchange OANDA --mitigation full --require-displacement
.\.venv\Scripts\python.exe manage.py runserver 127.0.0.1:8000
```

Đặt thông tin kết nối thật trong `.env` theo `.env.example`; không cần sửa mẫu hoặc ghi bí mật vào mã nguồn. Ví dụ trên không cung cấp dữ liệu EURUSD; phải nhập tệp thật bằng importer trước. Ngưỡng gap/break/tolerance hiện dùng đơn vị giá tuyệt đối: người vận hành phải chọn bội số tick thích hợp của symbol.

API hỗ trợ `run_id` để xem lại một bộ kết quả cụ thể; mặc định lấy run mới nhất phù hợp symbol/timeframe/source/series và phiên bản thuật toán. `as_of` tái dựng trạng thái từ dữ liệu của run đã chọn; muốn xem trước một lần sửa dữ liệu nguồn phải chọn run cũ. Các timestamp API cần timezone; hệ thống chuẩn hóa UTC. API giới hạn tối đa 2.000 bản ghi, chưa có tải trang tiếp theo trên canvas.

Fingerprint tách phiên bản cho sửa đổi dữ liệu đến thời điểm xác nhận. Nếu sửa nến sau thời điểm xác nhận làm lịch sử trạng thái mâu thuẫn, orchestrator từ chối và rollback cả lần chạy; phải nhập dưới `data_source` có phiên bản mới. Không tự ghi đè lịch sử mâu thuẫn.

### Kết quả quan sát thực tế

- PostgreSQL kết nối thành công, có đầy đủ bảng market. `audit_market`: **0 nến, 0 series, 0 import batches**; chưa có nguồn OHLCV thực để nghiệm thu.
- Migration `market.0003_ictanalysisrun_signal_keys`: **OK** trên PostgreSQL.
- Django system check: **không có lỗi**. Kiểm tra migration: **No changes detected**.
- Toàn bộ **43 test đạt** trên SQLite in-memory, gồm **24 test market**. Fixtures chỉ nằm trong database test.
- Kiểm thử PostgreSQL `manage.py test market --noinput`: dừng trước khi chạy vì **permission denied to create database**. Chưa có bằng chứng integration test trên PostgreSQL.
- Trình duyệt mở `/market/` thành công; thấy trạng thái chưa có dữ liệu, bộ chọn series và sáu checkbox lớp hiển thị.
- Trình duyệt gọi candles/analysis với EURUSD H1: HTTP **200**, `count: 0`, thông báo không có dữ liệu/tín hiệu. Timeframe BAD: HTTP **400**.

### Phần chưa nghiệm thu và giới hạn

Chưa kiểm tra nến và overlay bằng dữ liệu thực, zoom/pan trên tín hiệu thực, hoặc giải thích Ollama trên kết quả thực. Ollama hiện được ràng buộc bằng prompt và trả kèm evidence; chưa có bộ kiểm chứng mọi phát biểu trong văn bản AI. Engine dùng quy tắc hệ thống, chưa có thống kê xác suất thắng. Validation hiện từ chối gap kể cả kỳ nghỉ thị trường; chưa tích hợp lịch phiên. Hiệu năng với lịch sử lớn chưa benchmark; engine hiện có các vòng quét lịch sử. Không tích hợp CFTC, Barchart, OI hoặc liên thị trường.

**Chưa đánh dấu hoàn tất Phase 3**: cần tệp OHLCV thật có nguồn, database kiểm thử PostgreSQL riêng có quyền phù hợp, và kiểm tra chart/AI trên dữ liệu đó.
