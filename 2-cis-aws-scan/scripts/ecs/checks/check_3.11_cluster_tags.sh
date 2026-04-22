#!/bin/bash

check_ecs_cluster_tags() {
    local region="$1"
    local cluster="$2"

    log_info "[$region] Auditing Control 3.11: Resource Tags for Cluster: $cluster"

    # Get Cluster ARN
    local cluster_arn=$(aws ecs describe-clusters \
        --region "$region" \
        --clusters "$cluster" \
        --query 'clusters[0].clusterArn' \
        --output text 2>/dev/null)

    if [ -z "$cluster_arn" ] || [ "$cluster_arn" == "None" ]; then
        write_finding "$region" "$cluster" "3.11" "ERROR" \
            "Could not retrieve Cluster ARN" "LOW" "Verify cluster existence"
        return
    fi

    # List tags and filter out AWS-managed tags (starting with "aws:")
    local custom_tags_count=$(aws ecs list-tags-for-resource \
        --region "$region" \
        --resource-arn "$cluster_arn" \
        --query 'tags[?!starts_with(key, `aws:`)].key' \
        --output json | jq '. | length')

    if [ "$custom_tags_count" -gt 0 ]; then
        write_finding "$region" "$cluster" "3.11" "PASS" \
            "Cluster has custom tags assigned" "INFO" "Custom Tags Found: $custom_tags_count"
    else
        write_finding "$region" "$cluster" "3.11" "WARN" \
            "Cluster has no custom tags" "LOW" "Rationale: Consistent tagging helps identify unauthorized or misconfigured resources"
    fi
}
