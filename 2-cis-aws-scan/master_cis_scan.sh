#!/bin/bash
# =============================================================================
# master_cis_scan.sh
# Script điều phối tất cả CIS check scripts và merge thành báo cáo tổng hợp
# NT542 Group02 — Person 4
#
# Usage:
#   bash master_cis_scan.sh
#   TARGET_REGION=us-east-1 TARGET_CLUSTER=my-cluster TARGET_FUNCTION=my-fn bash master_cis_scan.sh
# =============================================================================

set -euo pipefail

# Đường dẫn
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/scripts/utils"
REPORTS_DIR="$SCRIPT_DIR/reports"

# Source thư viện hàm dùng chung
source "$UTILS_DIR/common_functions.sh"

# Cấu hình — có thể override qua biến môi trường
export TARGET_REGION="${TARGET_REGION:-us-east-1}"
export TARGET_CLUSTER="${TARGET_CLUSTER:-nt542-group02-cluster}"
export TARGET_FUNCTION="${TARGET_FUNCTION:-nt542-group02}"

# Tên file báo cáo
DATE=$(date +%Y-%m-%d_%H-%M-%S)
export REPORT_OUTPUT=""  # mỗi script tự quản lý output của mình

REPORT_ECS_TASKDEF="$REPORTS_DIR/ecs_taskdef_report.csv"
REPORT_ECS_SERVICE="$REPORTS_DIR/ecs_service_report.csv"
REPORT_LAMBDA_CORE="$REPORTS_DIR/lambda_core_report.csv"
REPORT_LAMBDA_ADV="$REPORTS_DIR/lambda_advanced_report.csv"
REPORT_FULL="$REPORTS_DIR/CIS_FULL_REPORT_$DATE.csv"

CSV_HEADER="Region,Resource_Name,Control,Status,Finding,Severity,Details"

# =============================================================================
# Step runner
# =============================================================================

run_step() {
    local step_num="$1"
    local step_name="$2"
    local script_path="$3"
    shift 3
    local args=("$@")

    echo ""
    log_master "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_master "STEP $step_num: $step_name"
    log_master "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ ! -f "$script_path" ]; then
        log_warn "Script not found: $script_path — Skipping"
        return 0
    fi

    local exit_code=0
    bash "$script_path" "${args[@]}" || exit_code=$?

    if [ $exit_code -eq 0 ]; then
        log_master "✅ $step_name completed successfully"
    else
        log_warn "⚠️  $step_name completed with exit code $exit_code (check report for details)"
    fi
}

# =============================================================================
# Merge tất cả report CSV thành một file tổng hợp
# =============================================================================

merge_all_reports() {
    log_master "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_master "MERGING ALL REPORTS → $REPORT_FULL"
    log_master "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    mkdir -p "$REPORTS_DIR"
    echo "$CSV_HEADER" > "$REPORT_FULL"

    local report_files=(
        "$REPORT_ECS_TASKDEF"
        "$REPORT_ECS_SERVICE"
        "$REPORT_LAMBDA_CORE"
        "$REPORT_LAMBDA_ADV"
    )

    local merged_count=0
    for report in "${report_files[@]}"; do
        if [ -f "$report" ]; then
            local line_count
            line_count=$(tail -n +2 "$report" | wc -l | tr -d ' ')
            tail -n +2 "$report" >> "$REPORT_FULL"
            log_info "  ✅ Merged $(basename "$report") ($line_count findings)"
            merged_count=$((merged_count + 1))
        else
            log_warn "  ⚠️  Missing: $(basename "$report") — skipping"
        fi
    done

    echo ""
    log_master "Merged $merged_count report(s) into: $REPORT_FULL"
}

# =============================================================================
# In bảng tổng kết cuối cùng
# =============================================================================

print_final_summary() {
    if [ ! -f "$REPORT_FULL" ]; then
        log_error "Full report not found: $REPORT_FULL"
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
    }' "$REPORT_FULL")"

    local score=0
    if [ "$total" -gt 0 ]; then
        score=$(awk "BEGIN { printf \"%.1f\", ($passed / $total) * 100 }")
    fi

    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║         CIS AWS Full Audit — FINAL REPORT            ║"
    echo "╠══════════════════════════════════════════════════════╣"
    printf "║  %-20s %-30s  ║\n" "Date:"      "$DATE"
    printf "║  %-20s %-30s  ║\n" "Region:"    "$TARGET_REGION"
    printf "║  %-20s %-30s  ║\n" "Cluster:"   "$TARGET_CLUSTER"
    printf "║  %-20s %-30s  ║\n" "Function:"  "$TARGET_FUNCTION"
    echo "╠══════════════════════════════════════════════════════╣"
    printf "║  %-20s %-30s  ║\n" "Total Checks:"    "$total"
    printf "║  ✅ %-18s %-30s  ║\n" "PASS:"    "$passed"
    printf "║  ❌ %-18s %-30s  ║\n" "FAIL:"    "$failed"
    printf "║  ⚠️  %-17s %-30s  ║\n" "WARN:"   "$warned"
    printf "║  📋 %-18s %-30s  ║\n" "MANUAL:"  "$manual"
    echo "╠══════════════════════════════════════════════════════╣"
    printf "║  %-20s %-30s  ║\n" "Compliance Score:" "$score%"
    echo "╠══════════════════════════════════════════════════════╣"
    printf "║  %-20s %-30s  ║\n" "Full Report:" "$(basename "$REPORT_FULL")"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""

    # Liệt kê các FAIL để dễ review
    if [ "$failed" -gt 0 ]; then
        log_warn "Failed checks (review required):"
        awk -F',' '
        NR>1 {
            status=$4; gsub(/"/, "", status)
            if (status=="FAIL") {
                control=$3; gsub(/"/, "", control)
                finding=$5; gsub(/"/, "", finding)
                resource=$2; gsub(/"/, "", resource)
                printf "  ❌ [%s] %s — %s\n", control, resource, finding
            }
        }' "$REPORT_FULL"
        echo ""
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    log_master "╔══════════════════════════════════════════════════════╗"
    log_master "║    NT542 Group02 — CIS AWS Compute Full Audit        ║"
    log_master "╚══════════════════════════════════════════════════════╝"
    log_master "Region   : $TARGET_REGION"
    log_master "Cluster  : $TARGET_CLUSTER"
    log_master "Function : $TARGET_FUNCTION"
    log_master "Date     : $DATE"

    # Kiểm tra AWS CLI
    check_aws_configured
    mkdir -p "$REPORTS_DIR"

    # Step 1: ECS Task Definition Check (Person 1)
    run_step 1 "ECS Task Definition (Person 1 — CIS 3.1, 3.3–3.7, 3.12, 3.13)" \
        "$SCRIPT_DIR/scripts/ecs/check_ecs_taskdef.sh" \
        "$TARGET_CLUSTER"

    # Step 2: ECS Service & Cluster Check (Person 2)
    run_step 2 "ECS Service & Cluster (Person 2 — CIS 3.2, 3.8–3.14)" \
        "$SCRIPT_DIR/scripts/ecs/check_ecs_service.sh"

    # Step 3: Lambda Core Check (Person 3)
    run_step 3 "Lambda Core Security (Person 3 — CIS 12.2, 12.4–12.9)" \
        "$SCRIPT_DIR/scripts/lambda/check_lambda_core.sh"

    # Step 4: Lambda Advanced Check (Person 4)
    run_step 4 "Lambda Advanced (Person 4 — CIS 12.1, 12.3, 12.10–12.12)" \
        "$SCRIPT_DIR/scripts/lambda/check_lambda_advanced.sh"

    # Merge tất cả reports
    merge_all_reports

    # In kết quả tổng hợp
    print_final_summary
}

main "$@"
