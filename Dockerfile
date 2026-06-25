# ============================================================
# Dockerfile — đóng gói Laravel 10 thành image để chạy trên EC2
#
# Cách đọc: từ trên xuống dưới, Docker thực hiện từng lệnh
# theo thứ tự để tạo ra một "hộp" chứa đầy đủ ứng dụng.
# ============================================================

# --- Bước 1: Chọn "nền tảng" ---
# php:8.2-apache = image có sẵn PHP 8.2 + Apache web server
# Không cần cài PHP hay Apache thủ công trên server nữa!
FROM php:8.2-apache

# --- Bước 2: Cài các thư viện hệ thống + PHP extension cho Laravel ---
RUN apt-get update && apt-get install -y \
    git curl zip unzip \
    libpng-dev libonig-dev libxml2-dev \
    nodejs npm \
 && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# --- Bước 3: Copy Composer từ image chính thức (không cài thủ công) ---
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# --- Bước 4: Đặt thư mục làm việc bên trong container ---
WORKDIR /var/www/html

# --- Bước 5: Copy toàn bộ source code vào image ---
# (file .dockerignore sẽ loại trừ vendor/, node_modules/, .env, ...)
COPY . .

# --- Bước 6: Cài package PHP (chỉ production, không cài dev tools) ---
RUN composer install --no-dev --optimize-autoloader --no-interaction

# --- Bước 7: Cài package frontend và build assets ---
RUN npm ci && npm run build

# --- Bước 8: Cấp quyền cho Laravel ghi vào thư mục storage và cache ---
RUN chown -R www-data:www-data storage bootstrap/cache \
 && chmod -R 775 storage bootstrap/cache

# --- Bước 9: Trỏ Apache vào thư mục public/ của Laravel ---
# Laravel bắt buộc: web server phải trỏ vào /public, không phải gốc dự án
ENV APACHE_DOCUMENT_ROOT /var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' \
        /etc/apache2/sites-available/*.conf \
 && sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' \
        /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf \
 && a2enmod rewrite

# --- Bước 10: Khai báo cổng container lắng nghe ---
EXPOSE 80

# Khi container khởi động, chạy Apache
CMD ["apache2-foreground"]
