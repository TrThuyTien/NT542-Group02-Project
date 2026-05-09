#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKS_DIR="$SCRIPT_DIR/checks"

OUTPUT_FILE="reports/ecs_taskdef_report.csv"

TARGET_REGION="us-east-1"
TARGET_CLUSTER="nt542-group02-cluster"

mkdir -p "$(dirname "$OUTPUT_FILE")"

log_info() { echo "[INFO] $1"; }
log_warn() { echo "[WARN] $1"; }

init_csv() {
    echo "Region,Service,Control,Status,Finding,Severity,Details" > "$OUTPUT_FILE"
}

write_finding() {
    echo "\"$1\",\"$2\",\"$3\",\"$4\",\"$5\",\"$6\",\"$7\"" >> "$OUTPUT_FILE"
}

# load checks
source "$CHECKS_DIR/check_3.1_network_privileged_root.sh"
source "$CHECKS_DIR/check_3.3_pid_mode.sh"
source "$CHECKS_DIR/check_3.4_privileged_container.sh"
source "$CHECKS_DIR/check_3.5_readonly_root_filesystem.sh"
source "$CHECKS_DIR/check_3.6_no_secrets_in_env.sh"
source "$CHECKS_DIR/check_3.7_logging_configuration.sh"
source "$CHECKS_DIR/check_3.12_taskdef_tags.sh"
source "$CHECKS_DIR/check_3.13_trusted_registry.sh"

main() {
    init_csv

    SERVICES=$(aws ecs list-services \
        --cluster "$TARGET_CLUSTER" \
        --region "$TARGET_REGION" \
        --query "serviceArns[]" \
        --output text)

    for SERVICE_ARN in $SERVICES; do
        SERVICE_NAME=$(basename "$SERVICE_ARN")

        TASK_DEF=$(aws ecs describe-services \
            --cluster "$TARGET_CLUSTER" \
            --services "$SERVICE_ARN" \
            --region "$TARGET_REGION" \
            --query "services[0].taskDefinition" \
            --output text)

        log_info "Checking $SERVICE_NAME"

        check_3_1 "$TARGET_REGION" "$TARGET_CLUSTER" "$SERVICE_NAME" "$TASK_DEF"
        check_3_3 "$TARGET_REGION" "$SERVICE_NAME" "$TASK_DEF"
        check_3_4 "$TARGET_REGION" "$SERVICE_NAME" "$TASK_DEF"
        check_3_5 "$TARGET_REGION" "$SERVICE_NAME" "$TASK_DEF"
        check_3_6 "$TARGET_REGION" "$SERVICE_NAME" "$TASK_DEF"
        check_3_7 "$TARGET_REGION" "$SERVICE_NAME" "$TASK_DEF"
        check_3_12 "$TARGET_REGION" "$SERVICE_NAME" "$TASK_DEF"
        check_3_13 "$TARGET_REGION" "$SERVICE_NAME" "$TASK_DEF"

        echo ""
    done

    log_info "Report saved: $OUTPUT_FILE"
}

main "$@"