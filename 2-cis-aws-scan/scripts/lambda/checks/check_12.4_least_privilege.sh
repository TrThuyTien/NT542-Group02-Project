#!/bin/bash

check_least_privilege() {
    local region="$1"
    local function_name="$2"
    
    log_info "[$region] Checking least privilege for: $function_name"
    
    # Get execution role ARN
    local role_arn=$(aws lambda get-function \
        --region "$region" \
        --function-name "$function_name" \
        --query 'Configuration.Role' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$role_arn" ]; then
        write_finding "$region" "$function_name" "12.4" "FAIL" \
            "No execution role found" "HIGH" "Cannot verify permissions"
        return
    fi
    
    # Extract role name from ARN
    local role_name=$(echo "$role_arn" | awk -F'/' '{print $NF}')
    
    # Get attached policies
    local managed_policies=$(aws iam list-attached-role-policies \
        --role-name "$role_name" \
        --query 'AttachedPolicies[*].PolicyArn' \
        --output text 2>/dev/null || echo "")
    
    # Check for overly permissive AWS managed policies
    local excessive_policies=""
    if echo "$managed_policies" | grep -q "AdministratorAccess"; then
        excessive_policies="AdministratorAccess"
    fi
    if echo "$managed_policies" | grep -q "PowerUserAccess"; then
        excessive_policies="${excessive_policies:+$excessive_policies, }PowerUserAccess"
    fi
    
    # Get inline policies
    local inline_policies=$(aws iam list-role-policies \
        --role-name "$role_name" \
        --query 'PolicyNames' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$excessive_policies" ]; then
        write_finding "$region" "$function_name" "12.4" "FAIL" \
            "Overly permissive managed policies attached" "HIGH" \
            "Policies: $excessive_policies - Review and apply least privilege"
    else
        write_finding "$region" "$function_name" "12.4" "MANUAL" \
            "Review required for least privilege" "INFO" \
            "Role: $role_name - Manual review needed for granular permissions"
    fi
}