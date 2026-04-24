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

# Output configuration
OUTPUT_FILE="reports/ecs_service_report.csv"
TEMP_DIR="tmp/ecs_audit_$$"

# Target configuration
TARGET_REGION="us-east-1"
TARGET_CLUSTER="nt542-group02-cluster"
TARGET_SERVICE="nt542-group02-service"

# Create necessary directories
mkdir -p "$TEMP_DIR"
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Initialize CSV file
init_csv() {
    echo "Region,Resource_Name,Control,Status,Finding,Severity,Details" > "$OUTPUT_FILE"
    log_info "Initialized report file: $OUTPUT_FILE"
}

# Write finding to CSV
write_finding() {
    local region="$1"
    local resource="$2"
    local control="$3"
    local status="$4"
    local finding="$5"
    local severity="$6"
    local details="$7"
    
    echo "\"$region\",\"$resource\",\"$control\",\"$status\",\"$finding\",\"$severity\",\"$details\"" >> "$OUTPUT_FILE"
}

# Source all check modules (Person 2 Responsibilities)
source "$CHECKS_DIR/check_3.2_public_ip_service.sh"
source "$CHECKS_DIR/check_3.8_fargate_version.sh"
source "$CHECKS_DIR/check_3.9_insights.sh"
source "$CHECKS_DIR/check_3.10_service_tags.sh"
source "$CHECKS_DIR/check_3.11_cluster_tags.sh"
source "$CHECKS_DIR/check_3.14_public_ip_task_set.sh"

main() {
    log_info "Starting CIS AWS ECS Service & Cluster Audit"
    log_info "Target Controls: 3.2, 3.8, 3.9, 3.10, 3.11, 3.14"
    log_info "Target: Region=$TARGET_REGION, Cluster=$TARGET_CLUSTER"
    echo ""
    
    # Initialize CSV
    init_csv
    
    log_info "================================================"
    log_info "Processing region: $TARGET_REGION"
    log_info "================================================"
    
    # Verify if Cluster exists
    if ! aws ecs describe-clusters --clusters "$TARGET_CLUSTER" --region "$TARGET_REGION" --query 'clusters[0]' --output text | grep -q "$TARGET_CLUSTER"; then
        log_error "Cluster '$TARGET_CLUSTER' not found in region '$TARGET_REGION'"
        exit 1
    fi

    log_info "Found target Cluster: $TARGET_CLUSTER"
    echo ""

    # Execute checks (Person 2 Responsibilities)
    check_ecs_public_ip_service "$TARGET_REGION" "$TARGET_CLUSTER" "$TARGET_SERVICE"     	# Control 3.2
    check_fargate_platform_version "$TARGET_REGION" "$TARGET_CLUSTER" "$TARGET_SERVICE" 	# Control 3.8
    check_container_insights "$TARGET_REGION" "$TARGET_CLUSTER"                          	# Control 3.9
    check_ecs_service_tags "$TARGET_REGION" "$TARGET_CLUSTER" "$TARGET_SERVICE" 		# Control 3.10
    check_ecs_cluster_tags "$TARGET_REGION" "$TARGET_CLUSTER"                   		# Control 3.11
    check_ecs_public_ip_task_set "$TARGET_REGION" "$TARGET_CLUSTER" "$TARGET_SERVICE"    	# Control 3.14

    echo ""
    
    # Cleanup
    rm -rf "$TEMP_DIR"
    
    # Summary Header
    log_info "================================================"
    log_info "Audit Complete!"
    log_info "================================================"
    log_info "Report saved to: $OUTPUT_FILE"
    
    # Summary Statistics Calculation
    local total=0
    local passed=0
    local failed=0
    local manual=0
    local warned=0
    
    # Use awk to count status (Column 4 in CSV)
    eval "$(awk -F',' '
    BEGIN {
        total=0; passed=0; failed=0; manual=0; warned=0
    }
    NR>1 {
        total++
        status=$4
        gsub(/"/, "", status) # Remove quotes
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", status) # Trim whitespace
        
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
    log_info "   Total Checks: $total"
    log_info "   Passed: $passed"
    log_info "   Failed: $failed"
    log_info "   Warnings: $warned"
    log_info "   Manual Review: $manual"
    echo ""
    
    # Exit logic based on failures
    if [ "$failed" -gt 0 ]; then
        log_warn "Found $failed failed check(s). Review the report for details."
        exit 1
    else
        log_info "All automated ECS checks passed!"
        exit 0
    fi
}

# Run main function
main "$@"
