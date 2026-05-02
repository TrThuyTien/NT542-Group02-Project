#!/bin/bash
# =============================================================================
# common_functions.sh — Thư viện hàm dùng chung cho tất cả CIS check scripts
# NT542 Group02 — Person 4
# =============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# =============================================================================
# Logging Functions
# =============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

log_master() {
    echo -e "${CYAN}[MASTER]${NC} $1"
}

# =============================================================================
# CSV Functions
# =============================================================================

# Khởi tạo file CSV với header chuẩn
# Usage: init_csv <output_file>
init_csv() {
    local output_file="$1"
    mkdir -p "$(dirname "$output_file")"
    echo "Region,Resource_Name,Control,Status,Finding,Severity,Details" > "$output_file"
    log_info "Initialized report: $output_file"
}

# Ghi một kết quả kiểm tra vào file CSV
# Usage: write_finding <output_file> <region> <resource_name> <control> <status> <finding> <severity> <details>
write_finding() {
    local output_file="$1"
    local region="$2"
    local resource_name="$3"
    local control="$4"
    local status="$5"
    local finding="$6"
    local severity="$7"
    local details="$8"

    # Escape double quotes trong details
    details="${details//\"/\'}"

    echo "\"$region\",\"$resource_name\",\"$control\",\"$status\",\"$finding\",\"$severity\",\"$details\"" >> "$output_file"

    # In ra terminal với màu theo status
    case "$status" in
        PASS)   echo -e "  ${GREEN}[PASS]${NC} $control — $finding" ;;
        FAIL)   echo -e "  ${RED}[FAIL]${NC} $control — $finding" ;;
        WARN)   echo -e "  ${YELLOW}[WARN]${NC} $control — $finding" ;;
        MANUAL) echo -e "  ${BLUE}[MANUAL]${NC} $control — $finding" ;;
        *)      echo -e "  [UNKNOWN] $control — $finding" ;;
    esac
}

# =============================================================================
# Summary Functions
# =============================================================================

# Đọc file CSV và in bảng thống kê
# Usage: print_csv_summary <csv_file> <title>
print_csv_summary() {
    local csv_file="$1"
    local title="${2:-Report Summary}"

    if [ ! -f "$csv_file" ]; then
        log_error "Report file not found: $csv_file"
        return 1
    fi

    local total passed failed warned manual
    eval "$(awk -F',' '
    BEGIN { total=0; passed=0; failed=0; warned=0; manual=0 }
    NR>1 {
        total++
        status=$4
        gsub(/"/, "", status)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", status)
        if (status=="PASS") passed++
        else if (status=="FAIL") failed++
        else if (status=="WARN") warned++
        else if (status=="MANUAL") manual++
    }
    END {
        print "total=" total "; passed=" passed "; failed=" failed "; warned=" warned "; manual=" manual
    }' "$csv_file")"

    local score=0
    if [ "$total" -gt 0 ]; then
        score=$(awk "BEGIN { printf \"%.1f\", ($passed / $total) * 100 }")
    fi

    echo ""
    log_info "================================================"
    log_info "$title"
    log_info "================================================"
    log_info "  Total Checks     : $total"
    log_info "  ✅ PASS          : $passed"
    log_info "  ❌ FAIL          : $failed"
    log_info "  ⚠️  WARN          : $warned"
    log_info "  📋 MANUAL REVIEW : $manual"
    log_info "  Compliance Score : $score%"
    echo ""
}

# =============================================================================
# AWS Helper Functions
# =============================================================================

# Kiểm tra AWS CLI đã được cấu hình chưa
check_aws_configured() {
    if ! aws sts get-caller-identity &>/dev/null; then
        log_error "AWS CLI is not configured or credentials are invalid."
        log_error "Run: aws configure"
        exit 1
    fi
}

# Lấy AWS Account ID hiện tại
get_account_id() {
    aws sts get-caller-identity --query "Account" --output text 2>/dev/null
}

# Kiểm tra Lambda function có tồn tại không
# Usage: lambda_exists <region> <function_name>
lambda_exists() {
    local region="$1"
    local function_name="$2"
    aws lambda get-function \
        --region "$region" \
        --function-name "$function_name" \
        &>/dev/null
}

# Lấy toàn bộ config của Lambda function
# Usage: get_lambda_config <region> <function_name>
get_lambda_config() {
    local region="$1"
    local function_name="$2"
    aws lambda get-function-configuration \
        --region "$region" \
        --function-name "$function_name" \
        --output json 2>/dev/null
}
