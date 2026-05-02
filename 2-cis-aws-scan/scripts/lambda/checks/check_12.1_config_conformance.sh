#!/bin/bash
# =============================================================================
# check_12.1_config_conformance.sh
# CIS 12.1: AWS Config phải có conformance pack cho serverless/Lambda
# NT542 Group02 — Person 4
# =============================================================================

check_12_1_config_conformance() {
    local region="$1"
    local function_name="$2"
    local output_file="$3"

    log_info "Checking CIS 12.1: AWS Config conformance pack for serverless..."

    local packs
    packs=$(aws configservice describe-conformance-packs \
        --region "$region" \
        --query "ConformancePackDetails[*].ConformancePackName" \
        --output text 2>/dev/null || echo "")

    if [ -z "$packs" ] || [ "$packs" = "None" ]; then
        write_finding "$output_file" "$region" "$function_name" "12.1" "FAIL" \
            "No conformance packs found in AWS Config" "HIGH" \
            "Create a conformance pack targeting Lambda/Serverless security (e.g., Operational-Best-Practices-for-AWS-Lambda)"
        return
    fi

    # Kiểm tra có pack nào liên quan đến serverless/lambda không
    local serverless_pack=""
    while IFS= read -r pack; do
        if echo "$pack" | grep -iqE "serverless|lambda|compute"; then
            serverless_pack="$pack"
            break
        fi
    done <<< "$packs"

    if [ -n "$serverless_pack" ]; then
        write_finding "$output_file" "$region" "$function_name" "12.1" "PASS" \
            "AWS Config conformance pack for serverless/Lambda exists" "HIGH" \
            "Pack found: $serverless_pack"
    else
        write_finding "$output_file" "$region" "$function_name" "12.1" "WARN" \
            "AWS Config enabled but no serverless-specific conformance pack found" "HIGH" \
            "Existing packs: $packs — Consider adding Operational-Best-Practices-for-AWS-Lambda"
    fi
}
