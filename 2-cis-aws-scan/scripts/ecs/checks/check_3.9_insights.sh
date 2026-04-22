#!/bin/bash

check_container_insights() {
    local region="$1"
    local cluster="$2"

    log_info "[$region] Auditing Container Insights for Cluster: $cluster"

    # Check containerInsights value in cluster settings
    local insights_status=$(aws ecs describe-clusters \
        --region "$region" \
        --cluster "$cluster" \
        --query 'clusters[0].settings[?name==`containerInsights`].value' \
        --output text 2>/dev/null || echo "disabled")

    if [ "$insights_status" == "enabled" ]; then
        write_finding "$region" "$cluster" "3.9" "PASS" \
            "Container Insights is ENABLED" "INFO" "Monitoring is properly configured"
    else
        write_finding "$region" "$cluster" "3.9" "FAIL" \
            "Container Insights is DISABLED" "MEDIUM" "Lack of visibility into system-level metrics"
    fi
}
