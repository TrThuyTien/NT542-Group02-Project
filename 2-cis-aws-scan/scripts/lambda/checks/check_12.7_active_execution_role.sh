#!/bin/bash

check_active_execution_role() {
    local region="$1"
    local function_name="$2"
    
    log_info "[$region] Checking active execution role for: $function_name"
    
    # Get execution role ARN
    local role_arn=$(aws lambda get-function \
        --region "$region" \
        --function-name "$function_name" \
        --query 'Configuration.Role' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$role_arn" ]; then
        write_finding "$region" "$function_name" "12.7" "FAIL" \
            "No execution role configured" "CRITICAL" \
            "Function cannot execute without a valid execution role"
        return
    fi
    
    # Extract role name from ARN
    local role_name=$(echo "$role_arn" | awk -F'/' '{print $NF}')
    
    # Check if role exists
    if aws iam get-role --role-name "$role_name" &>/dev/null; then
        write_finding "$region" "$function_name" "12.7" "PASS" \
            "Execution role is active" "INFO" \
            "Role: $role_name"
    else
        write_finding "$region" "$function_name" "12.7" "FAIL" \
            "Execution role not found or deleted" "CRITICAL" \
            "Role '$role_name' does not exist - function cannot execute"
    fi
}