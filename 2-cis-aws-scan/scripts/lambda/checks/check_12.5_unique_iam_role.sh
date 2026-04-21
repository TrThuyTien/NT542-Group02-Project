#!/bin/bash

check_unique_iam_role() {
    local region="$1"
    
    log_info "[$region] Checking for unique IAM role for Lambda function: $TARGET_FUNCTION"
    
    # Get function and its role
    local role_arn=$(aws lambda get-function \
        --region "$region" \
        --function-name "$TARGET_FUNCTION" \
        --query 'Configuration.Role' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$role_arn" ]; then
        write_finding "$region" "$TARGET_FUNCTION" "12.5" "FAIL" \
            "No execution role found" "CRITICAL" "Function has no IAM role assigned"
        return
    fi
    
    # Extract role name
    local role_name=$(echo "$role_arn" | awk -F'/' '{print $NF}')
    
    # Get all functions that use this role
    local functions_sharing=$(aws lambda list-functions \
        --region "$region" \
        --query "Functions[?Role=='$role_arn'].FunctionName" \
        --output text 2>/dev/null || echo "")
    
    local count=$(echo "$functions_sharing" | wc -w)
    
    if [ "$count" -gt 1 ]; then
        write_finding "$region" "$TARGET_FUNCTION" "12.5" "FAIL" \
            "IAM role shared with other Lambda functions" "HIGH" \
            "Role '$role_name' is used by $count functions: $functions_sharing"
    else
        write_finding "$region" "$TARGET_FUNCTION" "12.5" "PASS" \
            "Lambda function has unique IAM role" "INFO" \
            "Role: $role_name"
    fi
}