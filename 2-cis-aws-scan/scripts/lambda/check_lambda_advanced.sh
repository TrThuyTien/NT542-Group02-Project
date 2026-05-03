#!/bin/bash
# =============================================================================
# check_lambda_advanced.sh
# CIS AWS Lambda Benchmark — Advanced Controls
# Controls: 12.1, 12.3, 12.10, 12.11, 12.12
# NT542 Group02 — Person 4
# =============================================================================

set -euo pipefail

# Đường dẫn
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/../utils"
CHECKS_DIR="$SCRIPT_DIR/checks"
OUTPUT_FILE="${REPORT_OUTPUT:-reports/lambda_advanced_report.csv}"

# Cấu hình target (có thể override qua biến môi trường)
TARGET_REGION="${TARGET_REGION:-us-east-1}"
TARGET_FUNCTION="${TARGET_FUNCTION:-nt542-group02}"

# Source thư viện hàm dùng chung
# shellcheck source=../utils/common_functions.sh
source "$UTILS_DIR/common_functions.sh"

# Source các check modules
source "$CHECKS_DIR/check_12.1_config_conformance.sh"
source "$CHECKS_DIR/check_12.3_secrets_manager.sh"
source "$CHECKS_DIR/check_12.10_cross_account.sh"
source "$CHECKS_DIR/check_12.11_runtime_eol.sh"
source "$CHECKS_DIR/check_12.12_env_encryption.sh"

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    log_info "============================================================"
    log_info "CIS AWS Lambda Benchmark Audit — Advanced Controls"
    log_info "Controls: 12.1, 12.3, 12.10, 12.11, 12.12"
    log_info "Target  : Region=$TARGET_REGION | Function=$TARGET_FUNCTION"
    log_info "============================================================"
    echo ""

    # Kiểm tra AWS CLI credentials
    check_aws_configured

    # Khởi tạo file CSV
    mkdir -p "$(dirname "$OUTPUT_FILE")"
    init_csv "$OUTPUT_FILE"

    # Kiểm tra Lambda function tồn tại
    if ! lambda_exists "$TARGET_REGION" "$TARGET_FUNCTION"; then
        log_error "Lambda function '$TARGET_FUNCTION' not found in region '$TARGET_REGION'"
        log_error "Kiểm tra lại tên function và region trong file terraform.tfvars hoặc đặt biến môi trường:"
        log_error "  export TARGET_FUNCTION=<tên-function>"
        log_error "  export TARGET_REGION=<region>"
        exit 1
    fi

    log_info "Found Lambda function: $TARGET_FUNCTION"
    echo ""

    # Chạy từng check
    check_12_1_config_conformance  "$TARGET_REGION" "$TARGET_FUNCTION" "$OUTPUT_FILE"
    echo ""
    check_12_3_secrets_manager     "$TARGET_REGION" "$TARGET_FUNCTION" "$OUTPUT_FILE"
    echo ""
    check_12_10_cross_account      "$TARGET_REGION" "$TARGET_FUNCTION" "$OUTPUT_FILE"
    echo ""
    check_12_11_runtime_eol        "$TARGET_REGION" "$TARGET_FUNCTION" "$OUTPUT_FILE"
    echo ""
    check_12_12_env_encryption     "$TARGET_REGION" "$TARGET_FUNCTION" "$OUTPUT_FILE"
    echo ""

    # In tổng kết
    print_csv_summary "$OUTPUT_FILE" "Lambda Advanced Audit Summary (12.1, 12.3, 12.10, 12.11, 12.12)"
    log_info "Report saved: $OUTPUT_FILE"
}

main "$@"
