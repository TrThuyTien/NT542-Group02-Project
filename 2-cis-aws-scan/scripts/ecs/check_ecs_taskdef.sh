#!/bin/bash

CLUSTER_NAME=$1

if [ -z "$CLUSTER_NAME" ]; then
    echo "Usage: $0 <cluster-name>"
    exit 1
fi

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

    echo "Task Definition: $TASK_DEF_ARN"

    # 3.1 networkMode != host + no privileged + no root
    NETWORK_MODE=$(echo "$TASK_DEF" | jq -r '.taskDefinition.networkMode')
    PRIVILEGED=$(echo "$TASK_DEF" | jq '.taskDefinition.containerDefinitions[].privileged')
    USER_ROOT=$(echo "$TASK_DEF" | jq -r '.taskDefinition.containerDefinitions[].user')

    if [ "$NETWORK_MODE" == "host" ]; then
        check_fail "3.1 networkMode=host"
    elif echo "$PRIVILEGED" | grep -q true; then
        check_fail "3.1 privileged=true"
    elif echo "$USER_ROOT" | grep -q root; then
        check_fail "3.1 user=root"
    else
        check_pass "3.1"
    fi

    # 3.3 pidMode != host
    PID_MODE=$(echo "$TASK_DEF" | jq -r '.taskDefinition.pidMode')
    if [ "$PID_MODE" == "host" ]; then
        check_fail "3.3 pidMode=host"
    else
        check_pass "3.3"
    fi

    # 3.4 privileged != true
    if echo "$PRIVILEGED" | grep -q true; then
        check_fail "3.4 privileged=true"
    else
        check_pass "3.4"
    fi

    # 3.5 readonlyRootFilesystem must be true
    READONLY=$(echo "$TASK_DEF" | jq '.taskDefinition.containerDefinitions[].readonlyRootFilesystem')
    if echo "$READONLY" | grep -vq true; then
        check_fail "3.5 readonlyRootFilesystem != true"
    else
        check_pass "3.5"
    fi

    # 3.6 no secrets in env
    ENV_VARS=$(echo "$TASK_DEF" | jq -r '.taskDefinition.containerDefinitions[].environment[]?.name')
    if echo "$ENV_VARS" | grep -E -q "AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY"; then
        check_fail "3.6 secrets in environment"
    else
        check_pass "3.6"
    fi

    # 3.7 logging must exist
    LOG_DRIVER=$(echo "$TASK_DEF" | jq -r '.taskDefinition.containerDefinitions[].logConfiguration.logDriver')
    if echo "$LOG_DRIVER" | grep -q null; then
        check_fail "3.7 logging not configured"
    else
        check_pass "3.7"
    fi

    # 3.12 must have tags
    TAG_COUNT=$(echo "$TASK_DEF" | jq '.taskDefinition.tags | length')
    if [ "$TAG_COUNT" -eq 0 ]; then
        check_fail "3.12 no tags"
    else
        check_pass "3.12"
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
    else
        check_pass "3.13"
    fi

done

echo "Done task"