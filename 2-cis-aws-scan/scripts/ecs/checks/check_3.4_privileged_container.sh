#!/bin/bash
check_3_4() {
    local region="$1"; local service="$2"; local taskdef="$3"

    PRIVILEGED=$(aws ecs describe-task-definition \
        --task-definition "$taskdef" \
        --region "$region" \
        --query "taskDefinition.containerDefinitions[].privileged" \
        --output text)

    if echo "$PRIVILEGED" | grep -q true; then
        write_finding "$region" "$service" "3.4" "FAIL" "privileged=true" "HIGH" "-"
    else
        write_finding "$region" "$service" "3.4" "PASS" "-" "LOW" "-"
    fi
}