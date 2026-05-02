#!/bin/bash
# =============================================================================
# check_12.11_runtime_eol.sh
# CIS 12.11: Lambda runtime không nằm trong danh sách end-of-support
# NT542 Group02 — Person 4
# =============================================================================

# Danh sách runtime đã hết hỗ trợ (end-of-life)
# Nguồn: https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html
EOL_RUNTIMES=(
    "python2.7"
    "python3.6"
    "python3.7"
    "nodejs4.3"
    "nodejs4.3-edge"
    "nodejs6.10"
    "nodejs8.10"
    "nodejs10.x"
    "nodejs12.x"
    "nodejs14.x"
    "dotnetcore1.0"
    "dotnetcore2.0"
    "dotnetcore2.1"
    "dotnetcore3.1"
    "ruby2.5"
    "ruby2.7"
    "java8"
    "java8.al2"
    "go1.x"
)

# Runtime đang được hỗ trợ (supported as of 2025)
SUPPORTED_RUNTIMES=(
    "python3.8" "python3.9" "python3.10" "python3.11" "python3.12" "python3.13"
    "nodejs16.x" "nodejs18.x" "nodejs20.x" "nodejs22.x"
    "dotnet6" "dotnet8"
    "ruby3.2" "ruby3.3"
    "java11" "java17" "java21"
    "provided" "provided.al2" "provided.al2023"
)

check_12_11_runtime_eol() {
    local region="$1"
    local function_name="$2"
    local output_file="$3"

    log_info "Checking CIS 12.11: Lambda runtime not end-of-support..."

    local config
    config=$(get_lambda_config "$region" "$function_name")

    local runtime
    runtime=$(echo "$config" | python3 -c "import sys,json; print(json.load(sys.stdin).get('Runtime','UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")

    if [ "$runtime" = "UNKNOWN" ] || [ -z "$runtime" ]; then
        write_finding "$output_file" "$region" "$function_name" "12.11" "WARN" \
            "Could not determine Lambda runtime" "HIGH" \
            "Manually verify the runtime is not end-of-support"
        return
    fi

    # Kiểm tra có trong danh sách EOL không
    local is_eol=false
    for eol in "${EOL_RUNTIMES[@]}"; do
        if [ "$runtime" = "$eol" ]; then
            is_eol=true
            break
        fi
    done

    if [ "$is_eol" = true ]; then
        # Gợi ý runtime mới nhất cùng ngôn ngữ
        local suggestion=""
        case "$runtime" in
            python*) suggestion="python3.12 or python3.13" ;;
            nodejs*) suggestion="nodejs20.x or nodejs22.x" ;;
            dotnet*) suggestion="dotnet8" ;;
            ruby*)   suggestion="ruby3.3" ;;
            java*)   suggestion="java21" ;;
            go*)     suggestion="provided.al2023 with custom runtime" ;;
        esac

        write_finding "$output_file" "$region" "$function_name" "12.11" "FAIL" \
            "Lambda is using an end-of-support runtime: $runtime" "HIGH" \
            "Upgrade to a supported runtime. Suggested: $suggestion"
    else
        write_finding "$output_file" "$region" "$function_name" "12.11" "PASS" \
            "Lambda runtime is currently supported: $runtime" "HIGH" \
            "Runtime $runtime is in active support"
    fi
}
