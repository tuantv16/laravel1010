// ============================================================
// Jenkinsfile — Pipeline CI/CD cho Laravel 10
//
// Sơ đồ luồng:
//   push code → GitHub → webhook → Jenkins chạy file này
//
// Các stage theo thứ tự:
//   1. Cài dependency (composer + npm)
//   2. Kiểm tra format code (Pint)
//   3. Chạy test tự động (PHPUnit)
//   4. Build Docker image
//   5. Push image lên AWS ECR
//   6. Deploy lên AWS EC2
// ============================================================

pipeline {

    // "agent any" = Jenkins tự chọn máy chạy pipeline.
    // Sau này có thể đổi thành agent Docker cụ thể nếu cần.
    agent any

    // ---- Biến môi trường dùng chung cho cả pipeline ----
    environment {
        // Vùng AWS bạn dùng — ap-southeast-1 là Singapore (gần VN nhất)
        AWS_REGION    = 'ap-southeast-1'

        // Tên repo trên AWS ECR (sẽ tạo ở Mốc 5)
        ECR_REPO_NAME = 'laravel10-app'

        // Tag image = số build Jenkins, ví dụ: laravel10-app:42
        // Mỗi build sẽ có tag khác nhau → dễ rollback về version cũ
        IMAGE_TAG     = "${env.BUILD_NUMBER}"
    }

    stages {

        // ================================================
        // STAGE 1: Cài đặt dependencies
        // ================================================
        // Tại sao cần? vendor/ và node_modules/ không commit lên Git
        // → phải cài lại mỗi lần CI chạy.
        stage('📦 Cài dependencies') {
            steps {
                // composer install: cài package PHP từ composer.json
                // --no-interaction: không hỏi gì, chạy tự động
                // --prefer-dist: tải bản nén (nhanh hơn)
                // --optimize-autoloader: tạo classmap tối ưu cho production
                sh 'composer install --no-interaction --prefer-dist --optimize-autoloader'

                // npm ci: giống npm install nhưng dùng package-lock.json
                // chính xác hơn → đảm bảo CI dùng đúng version như local
                sh 'npm ci'
            }
        }

        // ================================================
        // STAGE 2: Kiểm tra format code (Laravel Pint)
        // ================================================
        // Pint kiểm tra xem code có viết đúng chuẩn Laravel không.
        // --test = chỉ kiểm tra, KHÔNG tự sửa. Nếu sai format → stage fail.
        // Mục tiêu: buộc mọi người viết code sạch trước khi merge.
        stage('🔍 Kiểm tra format (Pint)') {
            steps {
                sh './vendor/bin/pint --test'
            }
        }

        // ================================================
        // STAGE 3: Chạy Test tự động
        // ================================================
        // Chạy toàn bộ test trong thư mục tests/.
        // Nếu có test fail → stage đỏ → pipeline dừng, không deploy.
        stage('🧪 Chạy Test') {
            steps {
                // Tạo .env từ .env.example để Laravel hoạt động
                sh 'cp .env.example .env'

                // Tạo APP_KEY (Laravel bắt buộc cần key để mã hoá)
                sh 'php artisan key:generate'

                // Chạy toàn bộ test
                // phpunit.xml đã cấu hình dùng SQLite in-memory → không cần DB thật
                sh 'php artisan test'
            }
        }

        // ================================================
        // STAGE 4: Build Docker Image
        // ================================================
        // Đóng gói toàn bộ app (code + runtime) vào 1 Docker image.
        // Image này sẽ chạy giống nhau trên mọi môi trường.
        stage('🐳 Build Docker Image') {
            steps {
                script {
                    // Lấy AWS Account ID tự động (không hardcode)
                    // withCredentials: lấy Access Key/Secret từ Jenkins Credentials
                    // → không bao giờ lộ trong code hay log
                    withCredentials([[
                        $class           : 'AmazonWebServicesCredentialsBinding',
                        credentialsId    : 'aws-credentials',   // ID bạn sẽ tạo trong Jenkins
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]]) {
                        env.AWS_ACCOUNT_ID = sh(
                            script: 'aws sts get-caller-identity --query Account --output text',
                            returnStdout: true
                        ).trim()
                    }

                    // Ghép địa chỉ ECR Registry đầy đủ
                    // Dạng: 123456789.dkr.ecr.ap-southeast-1.amazonaws.com
                    env.ECR_REGISTRY = "${env.AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

                    // Tên đầy đủ của image: registry/repo:tag
                    // Ví dụ: 123456789.dkr.ecr.ap-southeast-1.amazonaws.com/laravel10-app:42
                    env.IMAGE_FULL = "${env.ECR_REGISTRY}/${ECR_REPO_NAME}:${IMAGE_TAG}"

                    // Build image theo Dockerfile ở thư mục hiện tại (.)
                    sh "docker build -t ${env.IMAGE_FULL} ."
                }
            }
        }

        // ================================================
        // STAGE 5: Push image lên AWS ECR
        // ================================================
        // ECR = Elastic Container Registry = kho chứa Docker image trên AWS.
        // Giống Docker Hub nhưng private và nằm trong AWS account của bạn.
        stage('☁️ Push lên AWS ECR') {
            steps {
                withCredentials([[
                    $class           : 'AmazonWebServicesCredentialsBinding',
                    credentialsId    : 'aws-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    // Lấy password tạm thời từ AWS và đăng nhập vào ECR
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${env.ECR_REGISTRY}"

                    // Đẩy image lên ECR
                    sh "docker push ${env.IMAGE_FULL}"
                }
            }
        }

        // ================================================
        // STAGE 6: Deploy lên AWS EC2
        // ================================================
        // SSH vào máy EC2, kéo image mới từ ECR về và chạy container mới.
        // Container cũ bị dừng và xoá → container mới thay thế.
        stage('🚀 Deploy lên EC2') {
            steps {
                withCredentials([
                    // SSH private key để đăng nhập vào EC2
                    sshUserPrivateKey(
                        credentialsId : 'ec2-ssh-key',   // ID bạn sẽ tạo trong Jenkins
                        keyFileVariable : 'KEY_FILE',
                        usernameVariable: 'EC2_USER'
                    ),
                    // Địa chỉ IP của EC2 (lưu trong Jenkins Credentials dạng Secret Text)
                    string(credentialsId: 'ec2-host', variable: 'EC2_HOST'),
                    // AWS credentials để EC2 pull từ ECR
                    [
                        $class           : 'AmazonWebServicesCredentialsBinding',
                        credentialsId    : 'aws-credentials',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]
                ]) {
                    sh """
                        ssh -o StrictHostKeyChecking=no -i \${KEY_FILE} \${EC2_USER}@\${EC2_HOST} '
                            # Đăng nhập ECR trên máy EC2
                            aws ecr get-login-password --region ${AWS_REGION} | \\
                                docker login --username AWS --password-stdin ${env.ECR_REGISTRY}

                            # Kéo image mới nhất về
                            docker pull ${env.IMAGE_FULL}

                            # Dừng và xoá container đang chạy (nếu có)
                            docker stop laravel-app 2>/dev/null || true
                            docker rm   laravel-app 2>/dev/null || true

                            # Chạy container mới
                            # --env-file ~/laravel.env = đọc .env từ file trên EC2 (không bake vào image)
                            # --restart unless-stopped = tự khởi động lại nếu server reboot
                            docker run -d \\
                                --name laravel-app \\
                                -p 80:80 \\
                                --restart unless-stopped \\
                                --env-file ~/laravel.env \\
                                ${env.IMAGE_FULL}

                            echo "Deploy thành công: ${env.IMAGE_FULL}"
                        '
                    """
                }
            }
        }

    } // end stages

    // ================================================
    // post: chạy sau khi pipeline kết thúc (dù pass hay fail)
    // ================================================
    post {
        success {
            echo "✅ Pipeline PASS — Build #${BUILD_NUMBER} đã live trên EC2!"
        }
        failure {
            echo "❌ Pipeline FAIL — Xem stage màu đỏ trong log để tìm lỗi."
        }
    }

} // end pipeline
