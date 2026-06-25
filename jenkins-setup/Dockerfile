# ============================================================
# Jenkins tùy chỉnh — thêm các công cụ cần thiết cho pipeline:
#   - Docker CLI  : để build và push Docker image
#   - AWS CLI     : để tương tác với ECR và EC2
#   - PHP 8.2     : để chạy composer install + php artisan test
#   - Composer    : quản lý package PHP
#   - Node.js/npm : để chạy npm ci + npm run build
# ============================================================
FROM jenkins/jenkins:lts-jdk17

# Chuyển sang root để cài phần mềm (jenkins user không có quyền apt)
USER root

# ---- Cài các tool hệ thống + PHP ----
# Debian Bookworm (nền tảng của Jenkins LTS) mặc định có PHP 8.2
# Tên package không cần số version (php thay vì php8.2)
RUN apt-get update && apt-get install -y \
    ca-certificates curl gnupg lsb-release \
    git zip unzip \
    php php-cli php-curl php-mbstring \
    php-xml php-zip php-sqlite3 php-gd php-bcmath \
    nodejs npm \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# ---- Cài Docker CLI (để Jenkins gọi docker build, docker push) ----
# Chỉ cần CLI, không cần Docker daemon (daemon dùng của Docker Desktop)
RUN install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/debian/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
 && chmod a+r /etc/apt/keyrings/docker.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null \
 && apt-get update && apt-get install -y docker-ce-cli \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# ---- Cài Composer (lấy từ image composer chính thức, không cần cài thủ công) ----
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# ---- Cài AWS CLI v2 ----
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip \
 && unzip /tmp/awscliv2.zip -d /tmp/ \
 && /tmp/aws/install \
 && rm -rf /tmp/awscliv2.zip /tmp/aws/

# Chuyển lại user jenkins (nguyên tắc bảo mật: không chạy app bằng root)
USER jenkins
