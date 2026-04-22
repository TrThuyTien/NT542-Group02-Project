#!/bin/bash

check_fargate_platform_version() {
    local region="$1"
    local cluster="$2"
    local service="$3"

    log_info "[$region] Auditing Control 3.8: Fargate Platform Version for: $service"

    # Query both Platform Family and Version using the recommended CIS audit command
    local service_info=$(aws ecs describe-services \
        --region "$region" \
        --cluster "$cluster" \
        --services "$service" \
        --query 'services[0].{Family: platformFamily, Version: platformVersion}' \
        --output json 2>/dev/null)

    if [ -z "$service_info" ] || [ "$service_info" == "null" ]; then
        write_finding "$region" "$service" "3.8" "ERROR" \
            "Could not retrieve service platform info" "MEDIUM" "Verify service existence and Fargate launch type"
    else
        local platform_family=$(echo "$service_info" | jq -r '.Family // "Linux"')
        local platform_version=$(echo "$service_info" | jq -r '.Version // "UNKNOWN"')

        log_info "Detected Platform Family: $platform_family, Version: $platform_version"

        local is_compliant=false

        # Logic based on CIS 3.8 Audit requirements
        if [[ "$platform_version" == "LATEST" ]]; then
            is_compliant=true
        elif [[ "$platform_family" == "Linux" && "$platform_version" == "1.4.0" ]]; then
            is_compliant=true
        elif [[ "$platform_family" == "Windows" && "$platform_version" == "1.0.0" ]]; then
            is_compliant=true
        fi

        if [ "$is_compliant" = true ]; then
            write_finding "$region" "$service" "3.8" "PASS" \
                "Fargate is using a supported/latest version" "LOW" "Family: $platform_family, Version: $platform_version"
        else
            write_finding "$region" "$service" "3.8" "FAIL" \
                "Outdated Fargate platform version" "MEDIUM" \
                "Rationale: Ensure security patches and performance updates. Found: $platform_version"
        fi
    fi
}
