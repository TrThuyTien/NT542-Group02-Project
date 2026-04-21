#!/bin/bash

check_public_access() {
    local region="$1"
    local function_name="$2"
    
    log_info "[$region] Checking public access for: $function_name"
    
    # Get function policy
    local policy=$(aws lambda get-policy \
        --region "$region" \
        --function-name "$function_name" \
        --query 'Policy' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$policy" ] || [ "$policy" == "None" ]; then
        write_finding "$region" "$function_name" "12.6" "PASS" \
            "No resource-based policy found" "INFO" \
            "Function not publicly accessible"
        return
    fi
    
    # Check for anonymous access patterns
    if echo "$policy" | grep -q '"Principal":"*"' || \
       echo "$policy" | grep -q '"Principal":{"AWS":"*"}'; then
        
        # Check if there's a condition clause
        if echo "$policy" | grep -q '"Condition"'; then
            write_finding "$region" "$function_name" "12.6" "WARN" \
                "Wildcard principal found with conditions" "MEDIUM" \
                "Review policy conditions to ensure proper access control"
        else
            write_finding "$region" "$function_name" "12.6" "FAIL" \
                "Function allows anonymous access" "CRITICAL" \
                "Principal set to '*' without conditions - publicly accessible"
        fi
    else
        write_finding "$region" "$function_name" "12.6" "PASS" \
            "Function not publicly accessible" "INFO" \
            "Resource-based policy restricts access"
    fi
}