#!/bin/bash
check_3_1() {
    local region="$1"
    local cluster="$2"
    local service="$3"
    local taskdef="$4"

    NETWORK_MODE=$(aws ecs describe-task-definition \
        --task-definition "$taskdef" \
        --region "$region" \
        --query "taskDefinition.networkMode" \
        --output text)

    PRIVILEGED=$(aws ecs describe-task-definition \
        --task-definition "$taskdef" \
        --region "$region" \
        --query "taskDefinition.containerDefinitions[].privileged" \
        --output text)

    USER_ROOT=$(aws ecs describe-task-definition \
        --task-definition "$taskdef" \
        --region "$region" \
        --query "taskDefinition.containerDefinitions[].user" \
        --output text)

    if [ "$NETWORK_MODE" == "host" ]; then
        write_finding "$region" "$service" "3.1" "FAIL" "networkMode=host" "HIGH" "-"
    elif echo "$PRIVILEGED" | grep -q true; then
        write_finding "$region" "$service" "3.1" "FAIL" "privileged=true" "HIGH" "-"
    elif echo "$USER_ROOT" | grep -q root; then
        write_finding "$region" "$service" "3.1" "FAIL" "user=root" "MEDIUM" "-"
    else
        write_finding "$region" "$service" "3.1" "PASS" "-" "LOW" "-"
    fi
}