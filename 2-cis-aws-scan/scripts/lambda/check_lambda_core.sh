#!/bin/bash

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKS_DIR="$SCRIPT_DIR/checks"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Output file
OUTPUT_FILE="reports/lambda_core_report.csv"
TEMP_DIR="tmp/lambda_audit_$$"

# Target configuration
TARGET_REGION="us-east-1"
TARGET_FUNCTION="nt542-group02"

# Create temp directory
mkdir -p "$TEMP_DIR"
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Initialize CSV file
init_csv() {
    echo "Region,Function_Name,Control,Status,Finding,Severity,Details" > "$OUTPUT_FILE"
    log_info "Initialized report file: $OUTPUT_FILE"
}

# Write finding to CSV
write_finding() {
    local region="$1"
    local function_name="$2"
    local control="$3"
    local status="$4"
    local finding="$5"
    local severity="$6"
    local details="$7"
    
    echo "\"$region\",\"$function_name\",\"$control\",\"$status\",\"$finding\",\"$severity\",\"$details\"" >> "$OUTPUT_FILE"
}

# Source all check modules
source "$CHECKS_DIR/check_12.2_lambda_insights.sh"
source "$CHECKS_DIR/check_12.4_least_privilege.sh"
source "$CHECKS_DIR/check_12.5_unique_iam_role.sh"
source "$CHECKS_DIR/check_12.6_public_access.sh"
source "$CHECKS_DIR/check_12.7_active_execution_role.sh"
source "$CHECKS_DIR/check_12.8_code_signing.sh"
source "$CHECKS_DIR/check_12.9_admin_privileges.sh"


main() {
    log_info "Starting CIS AWS Lambda Benchmark Audit"
    log_info "Controls: 12.2, 12.4, 12.5, 12.6, 12.7, 12.8, 12.9"
    log_info "Target: Region=$TARGET_REGION, Function=$TARGET_FUNCTION"
    echo ""
    
    # Initialize CSV
    init_csv
    
    # Process target region
    local region="$TARGET_REGION"
    log_info "================================================"
    log_info "Processing region: $region"
    log_info "================================================"
    
    # Verify Lambda function exists in target region
    if ! aws lambda get-function \
        --region "$region" \
        --function-name "$TARGET_FUNCTION" \
        &>/dev/null; then
        log_error "Function '$TARGET_FUNCTION' not found in region '$region'"
        exit 1
    fi
    
    log_info "Found target Lambda function: $TARGET_FUNCTION"
    echo ""
    
    # Check 12.5 for the specific function
    check_unique_iam_role "$region"
    
    # Audit the target function
    log_info "Auditing function: $TARGET_FUNCTION"
    
    # Run all checks
    check_lambda_insights "$region" "$TARGET_FUNCTION"
    check_least_privilege "$region" "$TARGET_FUNCTION"
    check_public_access "$region" "$TARGET_FUNCTION"
    check_active_execution_role "$region" "$TARGET_FUNCTION"
    check_code_signing "$region" "$TARGET_FUNCTION"
    check_admin_privileges "$region" "$TARGET_FUNCTION"
    
    echo ""
    
    # Cleanup
    rm -rf "$TEMP_DIR"
    
    # Summary
    echo ""
    log_info "================================================"
    log_info "Audit Complete!"
    log_info "================================================"
    log_info "Report saved to: $OUTPUT_FILE"
    
    # Print summary statistics
    local total=0
    local passed=0
    local failed=0
    local manual=0
    local warned=0
    
    # Use awk to count each status (column 4) - handles quoted CSV format
    eval "$(awk -F',' '
    BEGIN {
        total=0; passed=0; failed=0; manual=0; warned=0
    }
    NR>1 {
        total++
        status=$4
        # Remove surrounding quotes from status field
        gsub(/"/, "", status)
        # Trim whitespace
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", status)
        if (status == "PASS") passed++
        else if (status == "FAIL") failed++
        else if (status == "MANUAL") manual++
        else if (status == "WARN") warned++
    }
    END {
        print "total=" total "; passed=" passed "; failed=" failed "; manual=" manual "; warned=" warned
    }' "$OUTPUT_FILE")"
    
    echo ""
    log_info "Summary Statistics:"
    log_info "  Total Checks: $total"
    log_info "  Passed: $passed"
    log_info "  Failed: $failed"
    log_info "  Warnings: $warned"
    log_info "  Manual Review: $manual"
    echo ""
    
    if [ "$failed" -gt 0 ]; then
        log_warn "Found $failed failed check(s). Review the report for details."
        exit 1
    else
        log_info "All automated checks passed!"
        exit 0
    fi
}

# Run main function
main "$@"