# AZ OFFICE – Phân hệ Kinh doanh (server PostgreSQL)

Bản gốc chỉ lưu dữ liệu trong trình duyệt (`localStorage`), nên mỗi máy thấy một dữ liệu khác nhau
và xóa lịch sử trình duyệt là mất. Bản này thêm server **Node.js + PostgreSQL**: mọi người dùng chung một
kho dữ liệu, có lịch sử để khôi phục.

```
public/index.html   Giao diện (file gốc, đã sửa để đọc/ghi qua API)
server.js           Server Express: phục vụ trang + API /api/state
db/schema.sql       Lược đồ CSDL (tự tạo bảng khi server chạy)
.env.example        Mẫu cấu hình
docker-compose.yml  Chạy nhanh PostgreSQL bằng Docker (tùy chọn)
```

## Cài tự động (làm thay Bước 1–3)

- **Windows**: mở PowerShell bằng "Run as Administrator", `cd` vào thư mục dự án rồi chạy
  `powershell -ExecutionPolicy Bypass -File scripts\cai-dat-windows.ps1`
- **Ubuntu / macOS**: `bash scripts/cai-dat-linux-mac.sh` (macOS cần có Homebrew: https://brew.sh)

Script sẽ cài Node.js LTS và PostgreSQL, tạo CSDL `azoffice`, ghi file `.env` và chạy `npm install`.
Xong thì chỉ cần `npm start`. Nếu muốn tự làm từng bước, xem bên dưới.

## Bước 1 – Cài phần mềm

- **Node.js 18 trở lên**: https://nodejs.org (chọn bản LTS)
- **PostgreSQL 14 trở lên**, chọn một trong các cách:
  - Windows/macOS: tải bộ cài tại https://www.postgresql.org/download/ và nhớ mật khẩu user `postgres` lúc cài.
  - Ubuntu: `sudo apt install postgresql`
  - Hoặc có Docker thì chỉ cần: `docker compose up -d` (tự tạo CSDL `azoffice`, bỏ qua Bước 2).

## Bước 2 – Tạo CSDL và tài khoản

Mở **psql** (Windows: "SQL Shell (psql)" trong Start menu; Linux: `sudo -u postgres psql`) rồi chạy:

```sql
CREATE USER azoffice WITH PASSWORD 'doi_mat_khau_nay';
CREATE DATABASE azoffice OWNER azoffice;
```

Không cần tạo bảng: server tự chạy `db/schema.sql` khi khởi động.

## Bước 3 – Cấu hình

Sao chép `.env.example` thành `.env`, sửa `DATABASE_URL` cho đúng mật khẩu ở Bước 2:

```
DATABASE_URL=postgresql://azoffice:doi_mat_khau_nay@localhost:5432/azoffice
PORT=3000
```

Muốn bắt nhập mật khẩu khi mở trang, bỏ dấu `#` trước `APP_USER` và `APP_PASSWORD`.

## Bước 4 – Chạy

```bash
npm install
npm start
```

Mở http://localhost:3000. Lần đầu mở, dữ liệu mẫu được ghi vào PostgreSQL; từ đó mọi thay đổi được lưu
lên server (khoảng 0,4 giây sau mỗi thao tác). Máy khác trong cùng mạng truy cập qua
`http://<IP-máy-chủ>:3000`.

## Đưa lên tên miền (VPS Ubuntu)

1. Thuê VPS Ubuntu 22.04/24.04 (tối thiểu 1 CPU, 1–2 GB RAM) và mua tên miền.
2. Trỏ tên miền: tại trang quản lý DNS, tạo bản ghi **A**, tên `@` (hoặc tên miền con, ví dụ `kinhdoanh`),
   giá trị là **IP của VPS**. Chờ 5–30 phút.
3. Đăng nhập VPS: `ssh root@<IP-VPS>`, rồi:
   ```bash
   apt-get update && apt-get install -y git
   git clone -b claude/server-postgresql-setup-g6evcv https://github.com/giangle287/Giang.git /opt/az-office
   cd /opt/az-office
   bash scripts/cai-dat-linux-mac.sh
   sudo bash scripts/trien-khai-vps.sh ten-mien-cua-ban.vn email@cua-ban.vn
   ```
   Script thứ hai sẽ: bắt đặt mật khẩu đăng nhập trang, chạy nền bằng PM2 (tự khởi động lại khi VPS
   reboot), cấu hình Nginx, bật tường lửa, cấp HTTPS miễn phí, sao lưu CSDL mỗi ngày vào `/var/backups/azoffice`.
4. Cập nhật code về sau: `cd /opt/az-office && git pull && npm install && pm2 restart az-office`.

Không mở cổng 5432 (PostgreSQL) ra Internet; script chỉ mở SSH, HTTP và HTTPS.

## Sao lưu và khôi phục

Mỗi lần lưu, server ghi một bản sao vào bảng `app_state_history`.

```bash
# Sao lưu toàn bộ CSDL
pg_dump -U azoffice -d azoffice > backup.sql
# Khôi phục
psql -U azoffice -d azoffice < backup.sql
```

Quay về một phiên bản cũ (ví dụ version 42):

```sql
UPDATE app_state
SET data = (SELECT data FROM app_state_history WHERE version = 42 ORDER BY id DESC LIMIT 1),
    version = version + 1, updated_at = now()
WHERE id = 1;
```

Bảng lịch sử lớn dần theo thời gian; có thể dọn định kỳ:
`DELETE FROM app_state_history WHERE saved_at < now() - interval '90 days';`

## Lưu ý

- Nếu hai người sửa cùng lúc, người lưu sau sẽ nhận thông báo "Dữ liệu vừa được người khác cập nhật" và
  trang tải lại bản mới nhất (thao tác vừa làm của người đó cần làm lại).
- Nếu mất kết nối tới server, trang vẫn chạy bằng dữ liệu lưu trong trình duyệt nhưng thay đổi sẽ không lên server.
- Nút "Khôi phục dữ liệu mẫu" trong phần Cấu hình sẽ ghi đè dữ liệu chung của **mọi người**.
- Tính năng AI viết tin đăng chỉ chạy trong Claude; trên server riêng, ứng dụng tự dùng mẫu soạn sẵn.
