#!/bin/bash

check_ecs_service_tags() {
    local region="$1"
    local cluster="$2"
    local service="$3"

    log_info "[$region] Auditing Control 3.10: Resource Tags for Service: $service"

    # Get Service ARN
    local service_arn=$(aws ecs describe-services \
        --region "$region" \
        --cluster "$cluster" \
        --services "$service" \
        --query 'services[0].serviceArn' \
        --output text 2>/dev/null)

    if [ -z "$service_arn" ] || [ "$service_arn" == "None" ]; then
        write_finding "$region" "$service" "3.10" "ERROR" \
            "Could not retrieve Service ARN" "LOW" "Verify service existence"
        return
    fi

    # List tags and filter out AWS-managed tags (starting with "aws:")
    local custom_tags_count=$(aws ecs list-tags-for-resource \
        --region "$region" \
        --resource-arn "$service_arn" \
        --query 'tags[?!starts_with(key, `aws:`)].key' \
        --output json | jq '. | length')

    if [ "$custom_tags_count" -gt 0 ]; then
        write_finding "$region" "$service" "3.10" "PASS" \
            "Service has custom tags assigned" "INFO" "Custom Tags Found: $custom_tags_count"
    else
        write_finding "$region" "$service" "3.10" "WARN" \
            "Service has no custom tags" "LOW" "Rationale: Consistently tagging resources aids in management and security audit"
    fi
}
