#!/bin/bash
check_3_5() {
    local region="$1"; local service="$2"; local taskdef="$3"

    READONLY=$(aws ecs describe-task-definition \
        --task-definition "$taskdef" \
        --region "$region" \
        --query "taskDefinition.containerDefinitions[].readonlyRootFilesystem" \
        --output text)

    if echo "$READONLY" | grep -vq true; then
        write_finding "$region" "$service" "3.5" "FAIL" "readonlyRootFilesystem=false" "MEDIUM" "-"
    else
        write_finding "$region" "$service" "3.5" "PASS" "-" "LOW" "-"
    fi
}