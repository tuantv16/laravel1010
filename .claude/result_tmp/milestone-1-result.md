# Mốc 1 — Hoàn thành ✅
**Ngày:** 2026-06-25  
**Mục tiêu:** Chuẩn bị nền tảng CI/CD — viết Jenkinsfile, đóng gói app bằng Docker, chạy Jenkins trên máy local.

---

## Kết quả đạt được

| Hạng mục | Trạng thái |
|---|---|
| `Dockerfile` cho Laravel 10 | ✅ |
| `.dockerignore` | ✅ |
| `Jenkinsfile` (6 stage CI/CD) | ✅ |
| `jenkins-setup/Dockerfile` (Jenkins + PHP + Docker CLI + AWS CLI) | ✅ |
| `jenkins-setup/docker-compose.yml` | ✅ |
| Jenkins chạy tại `http://localhost:8080` | ✅ |
| Jenkins đang cài suggested plugins | ✅ |

---

## Files đã tạo

```
laravel10/
├── Dockerfile                        ← đóng gói Laravel thành Docker image
├── .dockerignore                     ← loại vendor/, .env ra khỏi image
├── Jenkinsfile                       ← pipeline CI/CD 6 stage
└── jenkins-setup/
    ├── Dockerfile                    ← Jenkins + PHP + Docker CLI + AWS CLI
    └── docker-compose.yml            ← chạy Jenkins bằng 1 lệnh
```

---

## Chi tiết từng file

### 1. `Dockerfile` — đóng gói Laravel

**Base image:** `php:8.2-apache`  
**Làm gì:** Cài PHP extensions → copy code → `composer install --no-dev` → `npm ci && npm run build` → cấp quyền storage → trỏ Apache vào `/public`.  
**Kết quả:** 1 container chạy được Laravel trên cổng 80.

### 2. `.dockerignore`

Loại khỏi image: `vendor/`, `node_modules/`, `.env`, `.git/`, `tests/`, `storage/logs/`.  
**Lý do:** Giảm kích thước image, tránh lộ thông tin nhạy cảm.

### 3. `Jenkinsfile` — pipeline CI/CD

| Stage | Công cụ | Làm gì |
|---|---|---|
| 📦 Cài dependencies | `composer`, `npm` | `composer install` + `npm ci` |
| 🔍 Kiểm tra format | Laravel Pint | `./vendor/bin/pint --test` |
| 🧪 Chạy Test | PHPUnit | `php artisan test` |
| 🐳 Build Docker Image | Docker | `docker build` → tag theo `BUILD_NUMBER` |
| ☁️ Push lên AWS ECR | AWS CLI | Login ECR → `docker push` |
| 🚀 Deploy lên EC2 | SSH | Pull image mới → stop/rm container cũ → `docker run` |

**Credentials cần tạo trong Jenkins (chưa làm — Mốc 3):**
| ID | Loại | Nội dung |
|---|---|---|
| `aws-credentials` | AWS Credentials | Access Key + Secret Key |
| `ec2-ssh-key` | SSH Username with private key | File `.pem` của EC2 |
| `ec2-host` | Secret text | IP address của EC2 |

### 4. `jenkins-setup/Dockerfile` — Jenkins tùy chỉnh

**Base image:** `jenkins/jenkins:lts-jdk17` (Debian Bookworm)  
**Thêm vào:** PHP 8.2, Composer 2, Docker CLI, AWS CLI v2, Node.js/npm.  
**Lý do cần custom:** Jenkins gốc không có PHP/Docker CLI → pipeline không chạy được.

**Lỗi gặp và cách fix:**

| Lỗi | Nguyên nhân | Cách fix |
|---|---|---|
| `permission denied /var/run/docker.sock` | WSL session chưa nhận quyền nhóm `docker` | `wsl --shutdown` → mở WSL mới |
| `php8.2 not found (exit code 100)` | Debian Bookworm không có package `php8.2-xxx` theo tên này | Đổi sang `php`, `php-cli`... (không có số version) |

### 5. `jenkins-setup/docker-compose.yml`

```yaml
volumes:
  - jenkins_home:/var/jenkins_home      # data Jenkins persist sau restart
  - /var/run/docker.sock:/var/run/docker.sock  # Docker outside of Docker
```

**Lệnh chạy:**
```bash
cd jenkins-setup
docker compose up -d --build
```

---

## Luồng CI/CD tổng thể (sau khi hoàn thành tất cả mốc)

```
Dev push code
  → GitHub (webhook)
    → Jenkins tại localhost:8080
      → install dependencies
      → pint --test (format check)
      → php artisan test
      → docker build → tag :BUILD_NUMBER
        → docker push lên AWS ECR
          → SSH vào EC2
            → docker pull → docker run
              → App live trên EC2 ✅
```

---

## Mốc tiếp theo — Mốc 2: Hoàn tất cài đặt Jenkins

- [ ] Hoàn tất wizard: tạo tài khoản admin, đặt Jenkins URL
- [ ] Cài thêm plugin cần thiết: **Pipeline**, **Git**, **Docker Pipeline**, **Amazon ECR**, **SSH Agent**
- [ ] Tạo Pipeline Job đầu tiên, trỏ vào repo GitHub
- [ ] Chạy pipeline tay lần đầu → xem log từng stage
