#!/bin/bash

check_lambda_insights() {
    local region="$1"
    local function_name="$2"
    
    log_info "[$region] Checking Lambda Insights for: $function_name"
    
    # Get function layers
    local layers=$(aws lambda get-function \
        --region "$region" \
        --function-name "$function_name" \
        --query 'Configuration.Layers[*].Arn' \
        --output text 2>/dev/null || echo "")
    
    # Check if LambdaInsightsExtension layer is present
    if echo "$layers" | grep -q "LambdaInsightsExtension"; then
        write_finding "$region" "$function_name" "12.2" "PASS" \
            "CloudWatch Lambda Insights enabled" "INFO" "Layer: LambdaInsightsExtension"
    else
        write_finding "$region" "$function_name" "12.2" "FAIL" \
            "CloudWatch Lambda Insights not enabled" "MEDIUM" \
            "Enhanced monitoring disabled - cannot collect system-level metrics"
    fi
}
