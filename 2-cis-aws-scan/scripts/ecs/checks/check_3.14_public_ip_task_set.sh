#!/bin/bash

check_ecs_public_ip_task_set() {
    local region="$1"
    local cluster="$2"
    local service="$3"

    log_info "[$region] Auditing Control 3.14: Public IP for Task Sets in: $service"

    # Query all task sets for the service
    local task_sets=$(aws ecs describe-task-sets \
        --region "$region" \
        --cluster "$cluster" \
        --service "$service" \
        --query 'taskSets[*].{Id: id, PublicIp: networkConfiguration.awsvpcConfiguration.assignPublicIp}' \
        --output json 2>/dev/null)

    if [ -z "$task_sets" ] || [ "$task_sets" == "[]" ]; then
        log_warn "No Task Sets found for service: $service"
        write_finding "$region" "$service" "3.14" "MANUAL" \
            "No Task Sets found" "LOW" "Manual review required if custom deployment controllers are used"
    else
        # Iterate through each task set found
        echo "$task_sets" | jq -c '.[]' | while read -r ts; do
            local ts_id=$(echo "$ts" | jq -r '.Id')
            local ts_public_ip=$(echo "$ts" | jq -r '.PublicIp // "ENABLED"')

            if [ "$ts_public_ip" == "DISABLED" ]; then
                write_finding "$region" "TaskSet-$ts_id" "3.14" "PASS" \
                    "assignPublicIp is DISABLED for Task Set" "LOW" "Task set is correctly isolated"
            else
                write_finding "$region" "TaskSet-$ts_id" "3.14" "FAIL" \
                    "assignPublicIp is ENABLED for Task Set" "HIGH" "Violation of CIS Level 1 security benchmark for task sets"
            fi
        done
    fi
}
