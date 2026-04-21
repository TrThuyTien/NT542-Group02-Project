#!/bin/bash

check_admin_privileges() {
    local region="$1"
    local function_name="$2"
    
    log_info "[$region] Checking admin privileges for: $function_name"
    
    # Get execution role ARN
    local role_arn=$(aws lambda get-function \
        --region "$region" \
        --function-name "$function_name" \
        --query 'Configuration.Role' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$role_arn" ]; then
        write_finding "$region" "$function_name" "12.9" "FAIL" \
            "No execution role found" "HIGH" \
            "Cannot verify permissions"
        return
    fi
    
    # Extract role name from ARN
    local role_name=$(echo "$role_arn" | awk -F'/' '{print $NF}')
    
    # Check attached managed policies
    local has_admin=false
    local admin_policies=""
    
    local managed_policies=$(aws iam list-attached-role-policies \
        --role-name "$role_name" \
        --query 'AttachedPolicies[*].[PolicyName,PolicyArn]' \
        --output text 2>/dev/null || echo "")
    
    while read -r policy_name policy_arn; do
        if [ -z "$policy_name" ]; then continue; fi
        
        # Check for AdministratorAccess policy
        if [ "$policy_name" == "AdministratorAccess" ]; then
            has_admin=true
            admin_policies="AdministratorAccess (AWS Managed)"
            break
        fi
        
        # Get policy document for custom policies
        if [[ "$policy_arn" == *":policy/"* ]]; then
            local default_version=$(aws iam get-policy \
                --policy-arn "$policy_arn" \
                --query 'Policy.DefaultVersionId' \
                --output text 2>/dev/null || echo "")
            
            if [ -n "$default_version" ]; then
                local policy_doc=$(aws iam get-policy-version \
                    --policy-arn "$policy_arn" \
                    --version-id "$default_version" \
                    --query 'PolicyVersion.Document' \
                    --output json 2>/dev/null || echo "{}")
                
                # Check for Action: * with Effect: Allow
                if echo "$policy_doc" | grep -q '"Action".*"\*"' && \
                   echo "$policy_doc" | grep -q '"Effect".*"Allow"'; then
                    has_admin=true
                    admin_policies="${admin_policies:+$admin_policies, }$policy_name (Managed)"
                fi
            fi
        fi
    done <<< "$managed_policies"
    
    # Check inline policies if no admin found yet
    if [ "$has_admin" == "false" ]; then
        local inline_policies=$(aws iam list-role-policies \
            --role-name "$role_name" \
            --query 'PolicyNames' \
            --output text 2>/dev/null || echo "")
        
        for policy_name in $inline_policies; do
            local policy_doc=$(aws iam get-role-policy \
                --role-name "$role_name" \
                --policy-name "$policy_name" \
                --query 'PolicyDocument' \
                --output json 2>/dev/null || echo "{}")
            
            # Check for Action: * with Effect: Allow
            if echo "$policy_doc" | grep -q '"Action".*"\*"' && \
               echo "$policy_doc" | grep -q '"Effect".*"Allow"'; then
                has_admin=true
                admin_policies="${admin_policies:+$admin_policies, }$policy_name (Inline)"
            fi
        done
    fi
    
    if [ "$has_admin" == "true" ]; then
        write_finding "$region" "$function_name" "12.9" "FAIL" \
            "Lambda function has administrative privileges" "CRITICAL" \
            "Policies with admin access: $admin_policies - Apply least privilege principle"
    else
        write_finding "$region" "$function_name" "12.9" "PASS" \
            "No administrative privileges detected" "INFO" \
            "Role: $role_name"
    fi
}