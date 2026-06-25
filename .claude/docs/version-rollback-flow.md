# Nghiệp vụ: Chọn version log trên giao diện → Rollback CI/CD

> Tài liệu này mô tả toàn bộ luồng công việc cần xây dựng để người dùng có thể
> click chọn một phiên bản trong lịch sử build và hệ thống tự động deploy lại
> đúng phiên bản đó (rollback).

---

## Tổng quan luồng

```
Build thành công
    → Lưu metadata version
    → Lưu artifact (image/tarball)
        → API trả danh sách version
            → Giao diện hiển thị bảng version log
                → Người dùng click "Rollback"
                    → Jenkins chạy pipeline rollback
                        → Deploy version cũ lên server
                            → Xác nhận & thông báo
```

---

## Giai đoạn 1 — Lưu metadata sau mỗi lần build thành công

**Mục tiêu:** Sau khi Jenkins build & deploy thành công, ghi lại thông tin phiên
bản để sau này có thể rollback.

**Dữ liệu cần lưu** (dạng JSON hoặc DB):
```json
{
  "id": "build-20260625-001",
  "version": "v1.3.2",
  "commit_sha": "a22593b",
  "branch": "master",
  "build_time": "2026-06-25T10:00:00Z",
  "deployer": "tuantv",
  "status": "success",
  "artifact_path": "releases/v1.3.2.tar.gz"
}
```

**Nơi lưu (chọn 1):**
- File `versions.json` trên server deploy
- Database (bảng `deployments`)
- Jenkins build description / artifact metadata

**Bước trong Jenkinsfile:**
```groovy
stage('Save Version Metadata') {
    steps {
        // Ghi thông tin build vào file hoặc gọi API lưu DB
        sh '''
            echo "{\"version\": \"${BUILD_NUMBER}\", \"commit\": \"${GIT_COMMIT}\"}" \
            >> /var/deployments/versions.json
        '''
    }
}
```

---

## Giai đoạn 2 — API lấy danh sách version & trigger rollback

**Mục tiêu:** Cung cấp 2 endpoint để giao diện gọi.

### Endpoint 1: Lấy danh sách version
```
GET /api/versions
Response:
[
  { "id": "build-003", "version": "v1.3.2", "build_time": "...", "status": "live" },
  { "id": "build-002", "version": "v1.3.1", "build_time": "...", "status": "passed" },
  { "id": "build-001", "version": "v1.3.0", "build_time": "...", "status": "passed" }
]
```

### Endpoint 2: Trigger rollback
```
POST /api/rollback
Body: { "version_id": "build-002" }
Response: { "job_url": "http://jenkins/job/rollback/123", "status": "triggered" }
```

**Cách trigger Jenkins từ API:**
- Gọi Jenkins Remote API: `POST http://jenkins/job/deploy/buildWithParameters?VERSION=v1.3.1`
- Cần Jenkins API Token (lưu trong Credentials, không hardcode)

---

## Giai đoạn 3 — Giao diện hiển thị version log

**Mục tiêu:** Trang web có bảng lịch sử deploy, mỗi dòng là 1 phiên bản.

### Layout bảng

| Version | Thời gian build  | Người deploy | Commit   | Trạng thái   | Hành động       |
|---------|------------------|--------------|----------|--------------|-----------------|
| v1.3.2  | 2026-06-25 10:00 | tuantv       | a22593b  | ✅ Live      | *(đang chạy)*   |
| v1.3.1  | 2026-06-24 09:00 | tuantv       | f1b2c3d  | ✅ Passed    | [Rollback]      |
| v1.3.0  | 2026-06-23 14:00 | tuantv       | e4d5c6b  | ✅ Passed    | [Rollback]      |

**Quy tắc hiển thị:**
- Version đang chạy (`status: live`) → không hiện nút Rollback, hiện badge "Live"
- Version đã pass → hiện nút "Rollback" màu cam/đỏ
- Version bị lỗi (`status: failed`) → mờ đi, không cho rollback

**Xác nhận trước khi rollback:**
- Hiện dialog: *"Bạn có chắc muốn rollback về v1.3.1? Phiên bản hiện tại v1.3.2 sẽ bị thay thế."*
- Có 2 nút: **Xác nhận** / Hủy

---

## Giai đoạn 4 — Jenkins pipeline rollback

**Mục tiêu:** Jenkins nhận version cần rollback, deploy lại artifact của version đó.

```groovy
pipeline {
    agent any
    parameters {
        string(name: 'VERSION', defaultValue: '', description: 'Version cần rollback về')
    }
    stages {
        stage('Lấy artifact') {
            steps {
                // Tải artifact (tarball/image) của version được chỉ định
                sh "aws s3 cp s3://my-bucket/releases/${params.VERSION}.tar.gz ."
                // Hoặc docker pull myapp:${params.VERSION}
            }
        }
        stage('Deploy') {
            steps {
                sh '''
                    tar -xzf ${VERSION}.tar.gz -C /var/www/laravel
                    php artisan migrate --force
                    php artisan config:cache
                    php artisan route:cache
                    sudo systemctl restart php-fpm
                '''
            }
        }
        stage('Health Check') {
            steps {
                sh 'curl -f http://localhost/health || exit 1'
            }
        }
        stage('Cập nhật trạng thái') {
            steps {
                // Ghi lại version vừa rollback là "live"
                sh "curl -X POST http://api/versions/${params.VERSION}/set-live"
            }
        }
    }
    post {
        success {
            // Gửi thông báo Slack/email
            echo "Rollback về ${params.VERSION} thành công"
        }
        failure {
            echo "Rollback thất bại! Cần can thiệp thủ công."
        }
    }
}
```

---

## Giai đoạn 5 — Xác nhận & thông báo

**Sau khi rollback xong:**
1. Giao diện tự động refresh danh sách version
2. Version vừa rollback về → badge chuyển sang "✅ Live"
3. Version cũ bị thay thế → badge chuyển sang "Passed"
4. Gửi thông báo: *"Rolled back to v1.3.1 by tuantv at 2026-06-25 11:00"*

---

## Lộ trình làm tuần tự

```
Bước 1  Jenkinsfile cơ bản chạy xanh (install → test → build)
Bước 2  Thêm stage lưu metadata version sau mỗi build thành công
Bước 3  Tạo Jenkinsfile riêng cho pipeline "rollback" (nhận param VERSION)
Bước 4  Tạo API 2 endpoint: GET /versions và POST /rollback
Bước 5  Xây dựng giao diện bảng version log + nút Rollback
Bước 6  Kết nối giao diện → API → Jenkins rollback pipeline
Bước 7  Test end-to-end: push code → build → rollback → kiểm tra version
```

---

## Lưu ý bảo mật

- **Không bao giờ** expose Jenkins trực tiếp ra internet — đặt sau reverse proxy (Nginx).
- Nút Rollback chỉ hiển thị với user có quyền (authentication).
- Jenkins API Token lưu trong **Jenkins Credentials**, không hardcode vào code hay file config.
- Log mọi hành động rollback: ai làm, lúc nào, rollback về version nào.
