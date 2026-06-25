# CLAUDE.md

File này hướng dẫn Claude Code (agent) cách làm việc trong dự án này.

---

## 0. Bối cảnh người dùng (RẤT QUAN TRỌNG — đọc kỹ)

- Người dùng là **newbie, gần như chưa biết gì về CI/CD, Jenkins, Docker và GitHub Actions**.
- Mục tiêu chính: **xây dựng luồng CI/CD cho dự án Laravel này bằng GitHub + Jenkins**.
- Vì vậy, khi làm việc, agent **bắt buộc**:
  1. **Trả lời bằng tiếng Việt**, từ ngữ đơn giản, dễ hiểu.
  2. **Giải thích trước khi làm**: thuật ngữ là gì (ví dụ: CI là gì, CD là gì, pipeline là gì, webhook là gì), tại sao cần bước đó.
  3. **Đi từng bước nhỏ**, không làm dồn nhiều thứ một lúc. Sau mỗi bước, nói rõ "bước này làm gì, kết quả mong đợi là gì, kiểm tra thế nào".
  4. **Không giả định người dùng biết các thao tác cài đặt**. Nếu cần cài Jenkins, tạo token, cấu hình GitHub... thì hướng dẫn click ở đâu, gõ lệnh gì.
  5. Khi có nhiều cách làm, **chọn cách đơn giản & phổ biến nhất cho người mới**, nói rõ lý do, rồi mới làm.
  6. Cảnh báo rõ những thao tác **không thể hoàn tác** hoặc liên quan **bí mật/credentials** (mật khẩu, token) trước khi thực hiện.

---

## 1. Dự án này là gì?

- Đây là một ứng dụng web **Laravel 10** (PHP framework), mới khởi tạo gần như mặc định.
- **PHP** `^8.1`, quản lý package backend bằng **Composer**.
- **Frontend** dùng **Vite** (Node.js), quản lý package bằng **npm**.
- **Test** dùng **PHPUnit** (cấu hình ở [phpunit.xml](phpunit.xml)).
- **Format code** dùng **Laravel Pint**.

### Cấu trúc thư mục chính
- [app/](app/) — code ứng dụng (Controllers, Models...).
- [routes/](routes/) — định nghĩa đường dẫn (URL) của web.
- [tests/](tests/) — test (`Unit` và `Feature`).
- [config/](config/) — cấu hình.
- `.env` — biến môi trường (chứa thông tin nhạy cảm, **KHÔNG commit lên Git**). Mẫu là [.env.example](.env.example).

---

## 2. Các lệnh thường dùng

> Lưu ý: máy đang chạy **Windows + PowerShell**.

### Cài đặt & chạy local
```bash
composer install            # cài package PHP
npm install                 # cài package frontend
copy .env.example .env      # tạo file .env (PowerShell: copy)
php artisan key:generate    # tạo APP_KEY
php artisan serve           # chạy web ở http://localhost:8000
npm run dev                 # chạy Vite (frontend) ở chế độ dev
```

### Kiểm thử & chất lượng code (đây là phần CI sẽ chạy)
```bash
php artisan test            # chạy toàn bộ test (cách khuyến nghị)
./vendor/bin/phpunit        # chạy test bằng PHPUnit trực tiếp
./vendor/bin/pint           # format code theo chuẩn Laravel
./vendor/bin/pint --test    # CHỈ kiểm tra format, không sửa (dùng trong CI)
npm run build               # build frontend cho production
```

---

## 3. Mục tiêu: Xây dựng luồng CI/CD (GitHub + Jenkins)

Đây là việc chính cần làm. Giải thích ngắn cho người mới:

- **CI (Continuous Integration)**: mỗi khi push code lên GitHub, hệ thống **tự động** cài dependency, format-check và chạy test → phát hiện lỗi sớm.
- **CD (Continuous Delivery/Deployment)**: sau khi CI pass, **tự động** đóng gói và đưa code lên server (deploy).
- **Jenkins**: công cụ chạy các bước tự động đó. "Công thức" của Jenkins viết trong file tên **`Jenkinsfile`** (đặt ở thư mục gốc dự án).
- **Webhook**: cầu nối để GitHub "báo" cho Jenkins biết "có code mới, chạy đi".

### Luồng tổng thể dự kiến
```
Dev push code → GitHub → (webhook) → Jenkins chạy pipeline:
   1) Checkout code
   2) composer install / npm install
   3) Pint --test (kiểm tra format)
   4) php artisan test (chạy test)
   5) Build (npm run build)
   6) Deploy (giai đoạn sau, làm khi các bước trên đã chạy ổn)
```

### Lộ trình gợi ý (làm tuần tự, từng bước)
1. **Chuẩn bị**: viết test chạy được ổn định ở local trước.
2. **Tạo `Jenkinsfile`** với pipeline CI cơ bản (install → lint → test).
3. **Cài & cấu hình Jenkins** (giải thích cách cài, tạo job/pipeline).
4. **Kết nối GitHub ↔ Jenkins** bằng webhook + credentials.
5. **Mở rộng sang CD** (deploy) — chỉ làm sau khi CI đã chạy xanh.

> Khi bắt đầu, agent nên hỏi người dùng: deploy lên đâu (server riêng, Docker, cloud?), Jenkins chạy ở đâu (máy local hay server?), để chọn cách phù hợp.

---

## Rules luôn áp dụng

Các quy tắc dưới đây LUÔN có hiệu lực (đọc kỹ trước khi làm việc liên quan):

@.claude/rules/security.md

## Tài liệu nghiệp vụ tham khảo

@.claude/docs/version-rollback-flow.md

---

## 4. Quy ước khi tạo/sửa file CI/CD

- File `Jenkinsfile` đặt ở **thư mục gốc** dự án.
- Nếu dùng GitHub Actions song song, file YAML đặt trong `.github/workflows/`.
- **Tuyệt đối không** ghi mật khẩu/token trực tiếp vào `Jenkinsfile` hay file YAML → dùng **Credentials của Jenkins** (hoặc **Secrets của GitHub**). Luôn giải thích cách thêm credential cho người dùng.
- Mỗi khi tạo file cấu hình mới, **giải thích từng dòng/từng `stage`** làm gì.
- Không commit `.env`, `vendor/`, `node_modules/` (đã có trong `.gitignore`).

---

## 5. Cách làm việc kỳ vọng

- Trước khi sửa nhiều file, **trình bày kế hoạch ngắn** rồi mới làm.
- Sau khi tạo file CI/CD, **chỉ cho người dùng cách kiểm tra** kết quả (push thử, xem log Jenkins ở đâu...).
- Nếu một bước cần thao tác thủ công ngoài code (bấm nút trên giao diện Jenkins/GitHub), **liệt kê rõ từng bước bấm**.
- Khi gặp lỗi, giải thích **lỗi nghĩa là gì** và **cách khắc phục**, đừng chỉ đưa lệnh.
