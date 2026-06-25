# Rule: Bảo mật & chống lộ bí mật (credentials)

> Quy tắc LUÔN có hiệu lực. Ngắn gọn, bắt buộc tuân theo trong mọi tình huống.

## 1. Không bao giờ lộ bí mật trong code/cấu hình
- **TUYỆT ĐỐI KHÔNG** ghi trực tiếp mật khẩu, token, API key, SSH key, chuỗi kết nối DB vào:
  `Jenkinsfile`, file `.github/workflows/*.yml`, `Dockerfile`, code, hay bất kỳ file nào được commit.
- Trong pipeline, **luôn** lấy bí mật từ:
  - **Jenkins Credentials** (dùng `credentials('id-cua-ban')` hoặc khối `withCredentials`).
  - **GitHub Secrets** (dùng `${{ secrets.TEN_SECRET }}`) nếu dùng GitHub Actions.
- Khi cần một bí mật mới: **dừng lại, hướng dẫn người dùng tự thêm credential** qua giao diện Jenkins/GitHub, rồi chỉ tham chiếu tới *ID* của nó. Không tự bịa giá trị.

## 2. File nhạy cảm không được commit
- Không commit: `.env`, `*.pem`, `*.key`, `id_rsa`, file backup DB, file chứa token.
- Trước khi tạo/sửa file để commit, kiểm tra file đó **không chứa** giá trị bí mật thật.
- Nếu phát hiện bí mật đã lỡ nằm trong file sắp commit → **cảnh báo người dùng ngay**, không tiếp tục.

## 3. Khi in/log
- Không `echo`/`print` giá trị bí mật ra log pipeline (log Jenkins/GitHub có thể bị người khác xem).
- Che bằng cơ chế mask của Jenkins/GitHub thay vì in ra.

## 4. Nguyên tắc tối thiểu quyền
- Token/credential chỉ cấp quyền vừa đủ cho việc cần làm (vd: chỉ đọc repo nếu chỉ cần checkout).
- Giải thích cho người dùng (newbie) vì sao mỗi quyền là cần thiết trước khi đề nghị tạo.

## 5. Khi nghi ngờ
- Nếu không chắc một giá trị có phải bí mật hay không → **coi như là bí mật** và xử lý theo các quy tắc trên.
