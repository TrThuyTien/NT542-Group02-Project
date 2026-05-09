#!/bin/bash

CLUSTER_NAME=$1
REGION="${AWS_DEFAULT_REGION:-us-east-1}"

if [ -z "$CLUSTER_NAME" ]; then
    echo "Usage: $0 <cluster-name>"
    exit 1
fi

# ── CSV Report Setup ─────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPORT_DIR="${SCRIPT_DIR}/../../reports"
mkdir -p "$REPORT_DIR"
REPORT_FILE="${REPORT_DIR}/ecs_taskdef_report.csv"

# CSV Header
echo "Region,Resource,ControlID,Status,Finding,Severity,Details" > "$REPORT_FILE"

# Helper: write one row to CSV
write_csv() {
    local resource="$1" control="$2" status="$3" finding="$4" severity="$5" details="$6"
    echo "${REGION},${resource},${control},${status},${finding},${severity},${details}" >> "$REPORT_FILE"
}

function check_fail() {
    echo "[FAIL] $1"
}

function check_pass() {
    echo "[PASS] $1"
}

SERVICES=$(aws ecs list-services --cluster "$CLUSTER_NAME" --query "serviceArns[]" --output text)

if [ -z "$SERVICES" ]; then
    echo "No services found"
    exit 0
fi

for SERVICE_ARN in $SERVICES; do
    echo "Checking service: $SERVICE_ARN"

    TASK_DEF_ARN=$(aws ecs describe-services \
        --cluster "$CLUSTER_NAME" \
        --services "$SERVICE_ARN" \
        --query "services[0].taskDefinition" \
        --output text)

    TASK_DEF=$(aws ecs describe-task-definition \
        --task-definition "$TASK_DEF_ARN")

    TASK_DEF_NAME=$(echo "$TASK_DEF_ARN" | awk -F'/' '{print $NF}')
    echo "Task Definition: $TASK_DEF_ARN"

    # 3.1 networkMode != host + no privileged + no root
    NETWORK_MODE=$(echo "$TASK_DEF" | jq -r '.taskDefinition.networkMode')
    PRIVILEGED=$(echo "$TASK_DEF" | jq '.taskDefinition.containerDefinitions[].privileged')
    USER_ROOT=$(echo "$TASK_DEF" | jq -r '.taskDefinition.containerDefinitions[].user')

    if [ "$NETWORK_MODE" == "host" ]; then
        check_fail "3.1 networkMode=host"
        write_csv "$TASK_DEF_NAME" "3.1" "FAIL" "networkMode is host" "HIGH" "Network mode should not be host"
    elif echo "$PRIVILEGED" | grep -q true; then
        check_fail "3.1 privileged=true"
        write_csv "$TASK_DEF_NAME" "3.1" "FAIL" "Container runs privileged" "HIGH" "Privileged mode is enabled"
    elif echo "$USER_ROOT" | grep -q root; then
        check_fail "3.1 user=root"
        write_csv "$TASK_DEF_NAME" "3.1" "FAIL" "Container runs as root" "HIGH" "User is set to root"
    else
        check_pass "3.1"
        write_csv "$TASK_DEF_NAME" "3.1" "PASS" "Network isolation OK" "INFO" "networkMode=awsvpc and no privileged or root"
    fi

    # 3.3 pidMode != host
    PID_MODE=$(echo "$TASK_DEF" | jq -r '.taskDefinition.pidMode')
    if [ "$PID_MODE" == "host" ]; then
        check_fail "3.3 pidMode=host"
        write_csv "$TASK_DEF_NAME" "3.3" "FAIL" "pidMode is host" "HIGH" "PID namespace shared with host"
    else
        check_pass "3.3"
        write_csv "$TASK_DEF_NAME" "3.3" "PASS" "PID namespace isolated" "INFO" "pidMode is not host"
    fi

    # 3.4 privileged != true
    if echo "$PRIVILEGED" | grep -q true; then
        check_fail "3.4 privileged=true"
        write_csv "$TASK_DEF_NAME" "3.4" "FAIL" "Privileged mode enabled" "CRITICAL" "Container has full host access"
    else
        check_pass "3.4"
        write_csv "$TASK_DEF_NAME" "3.4" "PASS" "Privileged mode disabled" "INFO" "Container does not have elevated privileges"
    fi

    # 3.5 readonlyRootFilesystem must be true
    READONLY=$(echo "$TASK_DEF" | jq '.taskDefinition.containerDefinitions[].readonlyRootFilesystem')
    if echo "$READONLY" | grep -vq true; then
        check_fail "3.5 readonlyRootFilesystem != true"
        write_csv "$TASK_DEF_NAME" "3.5" "FAIL" "readonlyRootFilesystem not enabled" "MEDIUM" "Container filesystem is writable"
    else
        check_pass "3.5"
        write_csv "$TASK_DEF_NAME" "3.5" "PASS" "readonlyRootFilesystem enabled" "INFO" "Container filesystem is read-only"
    fi

    # 3.6 no secrets in env
    ENV_VARS=$(echo "$TASK_DEF" | jq -r '.taskDefinition.containerDefinitions[].environment[]?.name')
    if echo "$ENV_VARS" | grep -E -q "AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY"; then
        check_fail "3.6 secrets in environment"
        write_csv "$TASK_DEF_NAME" "3.6" "FAIL" "Secrets found in environment variables" "CRITICAL" "AWS credentials detected in plain text"
    else
        check_pass "3.6"
        write_csv "$TASK_DEF_NAME" "3.6" "PASS" "No secrets in environment" "INFO" "No AWS credentials in environment variables"
    fi

    # 3.7 logging must exist
    LOG_DRIVER=$(echo "$TASK_DEF" | jq -r '.taskDefinition.containerDefinitions[].logConfiguration.logDriver')
    if echo "$LOG_DRIVER" | grep -q null; then
        check_fail "3.7 logging not configured"
        write_csv "$TASK_DEF_NAME" "3.7" "FAIL" "Logging not configured" "MEDIUM" "No log driver configured for container"
    else
        check_pass "3.7"
        write_csv "$TASK_DEF_NAME" "3.7" "PASS" "Logging configured" "INFO" "Log driver: $LOG_DRIVER"
    fi

    # 3.12 must have tags
    TAG_COUNT=$(echo "$TASK_DEF" | jq '.taskDefinition.tags | length')
    if [ "$TAG_COUNT" -eq 0 ]; then
        check_fail "3.12 no tags"
        write_csv "$TASK_DEF_NAME" "3.12" "FAIL" "No tags on task definition" "LOW" "Resource tagging is required for governance"
    else
        check_pass "3.12"
        write_csv "$TASK_DEF_NAME" "3.12" "PASS" "Tags present" "INFO" "Found $TAG_COUNT tag(s)"
    fi

    # 3.13 trusted registry (ECR)
    IMAGES=$(echo "$TASK_DEF" | jq -r '.taskDefinition.containerDefinitions[].image')

    TRUSTED=true
    for IMG in $IMAGES; do
        if [[ "$IMG" != *.amazonaws.com/* ]]; then
            TRUSTED=false
        fi
    done

    if [ "$TRUSTED" = false ]; then
        check_fail "3.13 untrusted registry"
        write_csv "$TASK_DEF_NAME" "3.13" "FAIL" "Image from untrusted registry" "HIGH" "Container image not from ECR"
    else
        check_pass "3.13"
        write_csv "$TASK_DEF_NAME" "3.13" "PASS" "Trusted registry (ECR)" "INFO" "All images from AWS ECR"
    fi

done

echo ""
echo "[INFO] Report saved: $REPORT_FILE"
echo "Done task"