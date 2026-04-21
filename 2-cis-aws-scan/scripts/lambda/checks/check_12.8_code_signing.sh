#!/bin/bash

check_code_signing() {
    local region="$1"
    local function_name="$2"
    
    log_info "[$region] Checking code signing for: $function_name"
    
    # Get code signing config
    local code_signing_arn=$(aws lambda get-function-code-signing-config \
        --region "$region" \
        --function-name "$function_name" \
        --query 'CodeSigningConfigArn' \
        --output text 2>/dev/null || echo "None")
    
    if [ "$code_signing_arn" == "None" ] || [ -z "$code_signing_arn" ]; then
        write_finding "$region" "$function_name" "12.8" "FAIL" \
            "Code signing not enabled" "HIGH" \
            "Function can deploy unverified code - enable code signing for security"
    else
        write_finding "$region" "$function_name" "12.8" "PASS" \
            "Code signing enabled" "INFO" \
            "Config ARN: $code_signing_arn"
    fi
}