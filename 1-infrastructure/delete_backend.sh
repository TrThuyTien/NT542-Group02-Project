# delete-backend.sh

#!/bin/bash
###############################################################
# delete-backend.sh — Xóa S3 bucket + DynamoDB table
# Cách dùng: ./delete-backend.sh
###############################################################

set -e

BUCKET_NAME="nt542-architecture"
DYNAMODB_TABLE="terraform-locks"
REGION="us-east-1"

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

echo -e "${RED}⚠️  Cảnh báo: Thao tác này sẽ xóa vĩnh viễn bucket và toàn bộ tfstate!${NC}"
read -r -p "Bạn có chắc chắn muốn xóa? (yes/no): " confirm
if [ "${confirm}" != "yes" ]; then
  echo "Đã hủy thao tác xóa."
  exit 0
fi

echo -e "${RED}=== Bắt đầu xóa Terraform Backend ===${NC}\n"

# 1. Xóa toàn bộ versions trong bucket
echo -e "${YELLOW}[1/3] Xóa toàn bộ objects trong bucket (kể cả versions)...${NC}"
aws s3api list-object-versions \
  --bucket "${BUCKET_NAME}" \
  --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
  --output json 2>/dev/null | \
aws s3api delete-objects \
  --bucket "${BUCKET_NAME}" \
  --delete file:///dev/stdin 2>/dev/null || true

# Xóa delete markers
aws s3api list-object-versions \
  --bucket "${BUCKET_NAME}" \
  --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' \
  --output json 2>/dev/null | \
aws s3api delete-objects \
  --bucket "${BUCKET_NAME}" \
  --delete file:///dev/stdin 2>/dev/null || true
echo -e "${GREEN}  ✓ Xóa objects thành công${NC}\n"

# 2. Xóa S3 bucket
echo -e "${YELLOW}[2/3] Xóa S3 bucket: ${BUCKET_NAME}...${NC}"
aws s3api delete-bucket \
  --bucket "${BUCKET_NAME}" \
  --region "${REGION}"
echo -e "${GREEN}  ✓ Xóa bucket thành công${NC}\n"

# 3. Xóa DynamoDB table
echo -e "${YELLOW}[3/3] Xóa DynamoDB table: ${DYNAMODB_TABLE}...${NC}"
aws dynamodb delete-table \
  --table-name "${DYNAMODB_TABLE}" \
  --region "${REGION}"
echo -e "${GREEN}  ✓ Xóa DynamoDB table thành công${NC}\n"

echo -e "${RED}=== Hoàn tất! Đã xóa toàn bộ Terraform backend ===${NC}"