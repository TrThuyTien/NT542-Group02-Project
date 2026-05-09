#!/bin/bash
check_3_7() {
    local region="$1"; local service="$2"; local taskdef="$3"

    LOG_DRIVER=$(aws ecs describe-task-definition \
        --task-definition "$taskdef" \
        --region "$region" \
        --query "taskDefinition.containerDefinitions[].logConfiguration.logDriver" \
        --output text)

    if echo "$LOG_DRIVER" | grep -q "None"; then
        write_finding "$region" "$service" "3.7" "FAIL" "No logging" "MEDIUM" "-"
    else
        write_finding "$region" "$service" "3.7" "PASS" "-" "LOW" "-"
    fi
}