# Tích hợp MT5 và ICT AI

Workspace gồm mã MT5 ở các thư mục gốc và ứng dụng Django trong `ai/`. Ứng dụng giữ nguyên kho kiến thức, RAG, API và phân tích nến của dự án ICT AI. Script `Tests/ExportMarketCandles.mq5` xuất OHLCV từ MT5; importer hiện có ghi dữ liệu và nguồn vào Django. Đây là luồng chuyển tệp thủ công một chiều, không đồng bộ liên tục, không chuyển tín hiệu của EA và không gửi lệnh giao dịch. Hai engine ICT có quy tắc riêng, không mặc định cho kết quả giống nhau.

## Cấu hình ứng dụng

Làm theo `ai/README.md`: tạo môi trường Python, cài `ai/requirements.txt`, sao chép `ai/.env.example` thành `ai/.env`, cấu hình PostgreSQL và Ollama, sau đó chạy migration và server từ `ai/`. Bản sao không chứa `.env`, môi trường ảo hay database SQLite của dự án cũ. Nếu cần dùng dữ liệu PostgreSQL cũ, cấu hình kết nối tới database hiện có; kiểm tra và sao lưu trước khi chạy migration. Nếu dữ liệu nằm trong SQLite cũ, cần di chuyển riêng; không có thao tác di chuyển dữ liệu tự động.

## Chuyển nến từ MT5

1. Biên dịch `Tests/ExportMarketCandles.mq5` trong MetaEditor và chạy script trên chart của symbol cần xuất. Chọn timeframe được Django hỗ trợ: M1, M5, M15, H1, H4, D1, W1 hoặc MN1. Đặt số nến và tên tệp. Script bỏ nến đang hình thành, ghi tick volume và xuất tối đa số nến MT5 thực sự có. Tệp nằm trong `MQL5/Files` của terminal; mở thư mục dữ liệu qua MT5 để tìm đường dẫn chính xác. Tên tệp trùng sẽ bị ghi đè.
2. Xác định múi giờ lịch sử của máy chủ broker, kể cả quy tắc DST. Timestamp xuất ra là giờ server không kèm offset; không giả định đó là UTC. Nếu broker đổi offset không theo một múi giờ IANA cố định hoặc có giờ DST mơ hồ, chuẩn hóa tệp sang timestamp ISO 8601 kèm offset trước khi nhập. Không đoán múi giờ.
3. Trong PowerShell tại `ai/`, sau khi kích hoạt môi trường:

```powershell
python manage.py import_market_data C:\path\ict_market_candles.csv --symbol EURUSD --exchange BrokerName --timeframe H1 --data-source mt5-broker --volume-type tick --price-type bid --source-timezone Europe/Helsinki
python manage.py analyze_market --symbol EURUSD --timeframe H1 --data-source mt5-broker --exchange BrokerName --price-type bid
python manage.py runserver
```

Thay mọi giá trị ví dụ bằng symbol, timeframe, múi giờ và loại giá thực tế của broker. Lệnh nhập báo số dòng không hợp lệ; xem cảnh báo trước khi phân tích. Bản nhập mặc định bỏ qua bản ghi trùng; `--update-existing` sửa dữ liệu cũ và có thể ảnh hưởng tính nhất quán của lịch sử phân tích. Xem kết quả tại `/market/`. Cần xác nhận giá chart thực sự là Bid trước khi dùng `--price-type bid`.

Importer và engine hiện không tự xử lý lịch nghỉ thị trường; dữ liệu có khoảng trống có thể bị engine từ chối. Tham khảo `ai/PHASE3.md` cho giới hạn, điều kiện nghiệm thu và API. Không coi kết quả compile hoặc unit test là kiểm chứng dữ liệu broker, độ chính xác chiến lược hay vận hành thực tế.
