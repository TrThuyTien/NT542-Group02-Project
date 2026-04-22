#!/bin/bash

check_ecs_public_ip_service() {
    local region="$1"
    local cluster="$2"
    local service="$3"

    log_info "[$region] Auditing Control 3.2: Public IP for Service: $service"

    # Query Service network configuration
    local service_config=$(aws ecs describe-services \
        --region "$region" \
        --cluster "$cluster" \
        --services "$service" \
        --query 'services[0].networkConfiguration.awsvpcConfiguration' \
        --output json 2>/dev/null)

    if [ -z "$service_config" ] || [ "$service_config" == "null" ]; then
        write_finding "$region" "$service" "3.2" "ERROR" \
            "Could not retrieve Service network configuration" "MEDIUM" "Verify if service exists and uses awsvpc mode"
    else
        # Default to ENABLED if value is missing as per CIS rationale
        local public_ip=$(echo "$service_config" | jq -r '.assignPublicIp // "ENABLED"')
        
        if [ "$public_ip" == "DISABLED" ]; then
            write_finding "$region" "$service" "3.2" "PASS" \
                "assignPublicIp is DISABLED for ECS Service" "LOW" "Level 1 - Service is properly isolated in private subnet"
        else
            write_finding "$region" "$service" "3.2" "FAIL" \
                "assignPublicIp is ENABLED for ECS Service" "HIGH" "Rationale: Public IP increases the attack surface from the internet"
        fi
    fi
}
