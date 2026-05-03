#!/bin/bash
check_3_3() {
    local region="$1"; local service="$2"; local taskdef="$3"

    PID_MODE=$(aws ecs describe-task-definition \
        --task-definition "$taskdef" \
        --region "$region" \
        --query "taskDefinition.pidMode" \
        --output text)

    if [ "$PID_MODE" == "host" ]; then
        write_finding "$region" "$service" "3.3" "FAIL" "pidMode=host" "HIGH" "-"
    else
        write_finding "$region" "$service" "3.3" "PASS" "-" "LOW" "-"
    fi
}