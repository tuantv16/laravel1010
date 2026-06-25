---
name: jenkins-pipeline
description: Hướng dẫn xây dựng pipeline CI/CD bằng Jenkins cho dự án Laravel 10 (PHP). Dùng khi người dùng cần tạo/sửa Jenkinsfile, dựng pipeline install → lint (Pint) → test (PHPUnit) → build → deploy, cấu hình stage/agent/credentials trong Jenkins, hoặc kết nối GitHub với Jenkins qua webhook. Giải thích theo kiểu newbie, từng bước, tiếng Việt.
---

# Skill: Xây dựng Jenkins Pipeline cho Laravel 10

Mục tiêu: giúp người dùng (newbie) dựng pipeline CI/CD bằng Jenkins. Luôn giải thích **trước khi làm**, đi **từng bước nhỏ**, **tiếng Việt**. Tuân thủ `rules/security.md` (không lộ bí mật).

---

## 1. Khái niệm nền (giải thích cho newbie)

- **Pipeline**: chuỗi các bước tự động chạy nối tiếp nhau.
- **`Jenkinsfile`**: file văn bản đặt ở **thư mục gốc** dự án, mô tả pipeline. Commit cùng code.
- **Stage**: một "chặng" trong pipeline (vd: chặng Test). Mỗi stage gồm nhiều **step** (lệnh cụ thể).
- **Agent**: nơi pipeline chạy (máy/agent của Jenkins, hoặc trong 1 container Docker).
- **Declarative pipeline**: kiểu viết `Jenkinsfile` đơn giản, dễ đọc nhất cho người mới → **luôn ưu tiên kiểu này**.

---

## 2. Pipeline CI cơ bản nên dựng (theo thứ tự)

```
Checkout → Cài dependency → Kiểm tra format (Pint) → Chạy test (PHPUnit) → Build frontend
```

Các lệnh tương ứng trong dự án này:
| Stage | Lệnh | Ý nghĩa |
|---|---|---|
| Install (PHP) | `composer install --no-interaction --prefer-dist` | cài package backend |
| Install (JS) | `npm ci` | cài package frontend (chuẩn cho CI) |
| Lint | `./vendor/bin/pint --test` | kiểm tra format, KHÔNG sửa file |
| Test | `php artisan test` | chạy toàn bộ test PHPUnit |
| Build | `npm run build` | build asset frontend |

> Lưu ý môi trường test: cần có `.env` cho testing và `APP_KEY`. Trong CI thường: `cp .env.example .env && php artisan key:generate`. Nếu test dùng DB, cấu hình SQLite in-memory (bỏ comment `DB_CONNECTION=sqlite` và `DB_DATABASE=:memory:` trong [phpunit.xml](phpunit.xml)).

---

## 3. Mẫu Jenkinsfile (Declarative) — giải thích từng phần

Đây là khung khởi đầu. Khi tạo thật, **giải thích từng `stage` cho người dùng** và điều chỉnh theo môi trường thực tế của họ.

```groovy
pipeline {
    agent any                       // chạy trên agent bất kỳ của Jenkins

    options {
        timestamps()                // thêm mốc thời gian vào log
        timeout(time: 20, unit: 'MINUTES')
    }

    stages {
        stage('Checkout') {         // lấy code từ Git
            steps { checkout scm }
        }

        stage('Cài đặt PHP') {
            steps { sh 'composer install --no-interaction --prefer-dist --no-progress' }
        }

        stage('Chuẩn bị môi trường') {
            steps {
                sh 'cp -n .env.example .env || true'
                sh 'php artisan key:generate'
            }
        }

        stage('Kiểm tra format (Pint)') {
            steps { sh './vendor/bin/pint --test' }
        }

        stage('Chạy test') {
            steps { sh 'php artisan test' }
        }

        stage('Build frontend') {
            steps {
                sh 'npm ci'
                sh 'npm run build'
            }
        }
    }

    post {
        success { echo '✅ Pipeline chạy thành công.' }
        failure { echo '❌ Pipeline thất bại — xem log stage bị đỏ.' }
    }
}
```

> Trên Windows agent, đổi `sh` thành `bat`. Hỏi người dùng Jenkins chạy trên Linux hay Windows trước khi chốt.

---

## 4. Dùng credentials đúng cách (xem rules/security.md)

Không ghi bí mật vào file. Ví dụ lấy token deploy an toàn:

```groovy
stage('Deploy') {
    steps {
        withCredentials([string(credentialsId: 'deploy-token', variable: 'DEPLOY_TOKEN')]) {
            sh 'echo "Đang deploy..." && ./deploy.sh'   // KHÔNG echo $DEPLOY_TOKEN
        }
    }
}
```
Hướng dẫn người dùng tạo credential: **Manage Jenkins → Credentials → (chọn store) → Add Credentials**, rồi dùng lại bằng `credentialsId`.

---

## 5. Kết nối GitHub ↔ Jenkins (tóm tắt các bước thủ công)

1. Cài plugin **Git** / **GitHub** trong Jenkins.
2. Tạo job kiểu **Pipeline** (hoặc **Multibranch Pipeline**), trỏ tới repo GitHub.
3. Chọn "Pipeline script from SCM" → Jenkins sẽ đọc `Jenkinsfile` trong repo.
4. Thêm **Webhook** ở GitHub: repo → **Settings → Webhooks → Add webhook** → URL `http(s)://<jenkins>/github-webhook/`.
5. Push thử 1 commit → kiểm tra Jenkins có tự chạy không, xem log.

> Nếu Jenkins chạy ở máy local (không có IP public), webhook từ GitHub không tới được → giải thích lựa chọn: dùng *poll SCM* (Jenkins tự hỏi định kỳ) hoặc tunnel (ngrok). Chọn cách đơn giản phù hợp hoàn cảnh người dùng.

---

## 6. Mở rộng sang CD (deploy)

Chỉ làm **sau khi CI đã chạy xanh ổn định**. Trước khi viết stage deploy, hỏi người dùng:
- Deploy lên đâu? (server riêng qua SSH, Docker, cloud...)
- Deploy khi nào? (mọi push lên `main`, hay khi tạo tag/release?)

Rồi mới thiết kế stage deploy phù hợp, vẫn dùng credentials an toàn.

---

## 7. Cách kiểm tra & gỡ lỗi (hướng dẫn người dùng)

- Mỗi lần chạy, vào job trên Jenkins → xem **Stage View** để biết stage nào đỏ.
- Bấm vào stage đỏ → đọc log → giải thích lỗi nghĩa là gì và cách sửa.
- Lỗi hay gặp: thiếu `APP_KEY`, thiếu `.env`, sai phiên bản PHP/Node trên agent, quên `npm ci`.
