#!/bin/bash
check_3_6() {
    local region="$1"; local service="$2"; local taskdef="$3"

    ENV_VARS=$(aws ecs describe-task-definition \
        --task-definition "$taskdef" \
        --region "$region" \
        --query "taskDefinition.containerDefinitions[].environment[].name" \
        --output text)

    if echo "$ENV_VARS" | grep -E -q "AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY"; then
        write_finding "$region" "$service" "3.6" "FAIL" "Hardcoded secrets" "CRITICAL" "-"
    else
        write_finding "$region" "$service" "3.6" "PASS" "-" "LOW" "-"
    fi
}