#!/bin/bash
check_3_12() {
    local region="$1"; local service="$2"; local taskdef="$3"

    TAG_COUNT=$(aws ecs describe-task-definition \
        --task-definition "$taskdef" \
        --region "$region" \
        --query "length(taskDefinition.tags || \`[]\`)" \
        --output text)

    if [ "$TAG_COUNT" == "0" ]; then
        write_finding "$region" "$service" "3.12" "FAIL" "No tags" "LOW" "-"
    else
        write_finding "$region" "$service" "3.12" "PASS" "-" "LOW" "-"
    fi
}