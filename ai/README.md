# ICT Smart Money AI — Phase 1

Ứng dụng nghiên cứu ICT bằng Django. Phase 1 gồm metadata YouTube qua Data API chính thức, nhập transcript SRT/VTT đã có quyền xử lý, lưu đoạn văn bản có timestamp, embedding local bằng Ollama, tìm kiếm RAG, chat có dẫn nguồn, API và dashboard. Chưa có bộ phân tích giá, backtest hay giao dịch tự động.

## Yêu cầu trên Windows / VS Code

- Python 3.11+ và PostgreSQL 17 local.
- Ollama đã cài. Cần tải hai model theo cấu hình, ví dụ `ollama pull llama3.2` và `ollama pull nomic-embed-text`.
- YouTube Data API v3 key để thu thập metadata. Không cần key để nhập transcript cho video đã tồn tại trong database.

Trong PowerShell ở thư mục dự án:

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
```

Trong VS Code chọn interpreter `.venv\Scripts\python.exe`. Đặt `DJANGO_SECRET_KEY` ngẫu nhiên và `POSTGRES_PASSWORD` trong `.env`. PostgreSQL là backend mặc định; `DATABASE_URL` có thể thay cho các biến `POSTGRES_*` và có ưu tiên cao hơn. Không commit `.env`. Nếu mật khẩu chứa ký tự đặc biệt trong `DATABASE_URL`, hãy URL encode mật khẩu.

Tạo role và database riêng bằng pgAdmin hoặc từ `psql -U postgres -h 127.0.0.1 -d postgres` (lệnh sẽ hỏi mật khẩu quản trị):

```sql
CREATE ROLE ict_user LOGIN;
\password ict_user
CREATE DATABASE ict_ai_learning OWNER ict_user;
```

Nhập mật khẩu vừa đặt vào `POSTGRES_PASSWORD` trong `.env`, rồi kiểm tra `psql -U ict_user -h 127.0.0.1 -d ict_ai_learning -c "SELECT current_database();"`. Không dùng database của dự án khác.

```powershell
python manage.py check
python manage.py migrate
python manage.py createsuperuser
ollama serve
python manage.py runserver
```

`ollama serve` chỉ cần nếu Ollama chưa chạy nền. Mở `http://127.0.0.1:8000/` và `/admin/`.

## Nhập dữ liệu thật

```powershell
python manage.py collect_youtube --limit 50
python manage.py import_transcript VIDEO_ID C:\path\authorized.srt --language en --rights-note "Permission to process this subtitle file"
python manage.py index_knowledge --limit 100
```

Collector chỉ đọc metadata công khai từ kênh `@InnerCircleTrader` qua YouTube Data API. Lệnh nhập transcript không tải phụ đề từ YouTube; người vận hành phải có quyền với tệp được nhập. `rights_note` được lưu trong database để truy xuất. Không nhập dữ liệu giả dưới nhãn dữ liệu thật.

Để lấy key, bật YouTube Data API v3 trong Google Cloud project của bạn, tạo API key và hạn chế key cho API này. Đặt key trong `YOUTUBE_API_KEY` của `.env`. Collector dùng `channels.list` với `forHandle` và `playlistItems.list` cho uploads playlist. Ngày xuất bản được đọc từ `contentDetails.videoPublishedAt`; bản ghi thiếu ngày này sẽ được bỏ qua. Lỗi API được rút gọn để không in URL chứa key.

## API

- `GET /api/videos/` — tối đa 100 video mới nhất.
- `GET /api/search/?q=...` — trích đoạn và URL timestamp.
- `POST /api/chat/` với JSON `{"question":"..."}` — trả lời tiếng Việt, danh sách dẫn nguồn. Dashboard gửi CSRF token; API giới hạn 10 yêu cầu chat/giờ với khách vãng lai.

Nếu Ollama chưa chạy hoặc chưa có embedding model, API trả 503. Khi chưa nhập transcript, metadata chỉ hiển thị video, không được xem là đã nghiên cứu nội dung. Tìm kiếm hiện tính cosine trên các embedding lưu trong JSON; đủ cho kho nhỏ của Phase 1, cần pgvector hoặc chỉ mục vector khi dữ liệu tăng.

## Kiểm tra và điều kiện nghiệm thu

```powershell
python manage.py check
python manage.py test --settings=ict_ai.settings_test
python manage.py makemigrations --check --dry-run
```

Phase 1 được nghiệm thu trên máy vận hành khi: migration chạy với PostgreSQL 17; collector lấy metadata thực với key hợp lệ; transcript được cấp quyền nhập và tạo các chunk có timestamp; Ollama tạo embedding và trả lời dựa trên chunk với dẫn nguồn; dashboard và API hoạt động; test pass. Bộ unit test dùng SQLite in-memory qua `settings_test` để không đụng dữ liệu PostgreSQL. Các bước cần dịch vụ/key/dữ liệu thực chưa thể coi là nghiệm thu cho đến khi chạy trên máy đã cấu hình. Phase 2 chỉ bắt đầu sau các kiểm tra trên.
