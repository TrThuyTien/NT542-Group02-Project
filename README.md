# NT542-Group02-Project
Đồ án môn học Lập trình kịch bản tự động hóa và bảo mật mạng

## A. Deploy Hạ tầng
- Sử dụng môi trường Learner Lab AWS
- Chạy trong thư mục **1-infrastructure**
### 1. Cấp quyền thực thi cho script
Chạy lệnh sau để cấp quyền cho các file shell script:

```bash
chmod +x create_backend.sh
chmod +x delete_backend.sh
```

### 2. Khởi tạo backend
Chạy script tạo backend:

```bash
sh create_backend.sh
```

### 3. Khởi tạo Terraform
Sau khi backend đã được tạo, khởi tạo Terraform:

```bash
terraform init
```

### 4. Triển khai hạ tầng
Áp dụng cấu hình Terraform để tạo hạ tầng:

```bash
terraform apply
```

### 5. Destroy hạ tầng và xóa backend

Trong trường hợp muốn xóa backend, chạy:

```bash
terraform destroy
sh delete_backend.sh
```
