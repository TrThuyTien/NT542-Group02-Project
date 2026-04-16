# create-backend.sh

#!/bin/bash
###############################################################
# create-backend.sh — Tạo S3 bucket + DynamoDB table
# Cách dùng: ./create-backend.sh
###############################################################

set -e

BUCKET_NAME="nt542-architecture"
DYNAMODB_TABLE="terraform-locks"
REGION="us-east-1"

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

echo -e "${GREEN}=== Bắt đầu tạo Terraform Backend ===${NC}\n"

# 1. Tạo S3 bucket
echo -e "${YELLOW}[1/4] Tạo S3 bucket: ${BUCKET_NAME}...${NC}"
aws s3api create-bucket \
  --bucket "${BUCKET_NAME}" \
  --region "${REGION}"
echo -e "${GREEN}  ✓ Tạo bucket thành công${NC}\n"

# 2. Bật versioning
echo -e "${YELLOW}[2/4] Bật versioning cho bucket...${NC}"
aws s3api put-bucket-versioning \
  --bucket "${BUCKET_NAME}" \
  --versioning-configuration Status=Enabled
echo -e "${GREEN}  ✓ Bật versioning thành công${NC}\n"

# 3. Bật mã hóa
echo -e "${YELLOW}[3/4] Bật mã hóa AES256 cho bucket...${NC}"
aws s3api put-bucket-encryption \
  --bucket "${BUCKET_NAME}" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'
echo -e "${GREEN}  ✓ Bật mã hóa thành công${NC}\n"

# 4. Tạo DynamoDB table
echo -e "${YELLOW}[4/4] Tạo DynamoDB table: ${DYNAMODB_TABLE}...${NC}"
aws dynamodb create-table \
  --table-name "${DYNAMODB_TABLE}" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "${REGION}"
echo -e "${GREEN}  ✓ Tạo DynamoDB table thành công${NC}\n"

echo -e "${GREEN}=== Hoàn tất! Terraform backend đã sẵn sàng ===${NC}"
echo -e "  Bucket   : s3://${BUCKET_NAME}"
echo -e "  DynamoDB : ${DYNAMODB_TABLE}"
echo -e "  Region   : ${REGION}"