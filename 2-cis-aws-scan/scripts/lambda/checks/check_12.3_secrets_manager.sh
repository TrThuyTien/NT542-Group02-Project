#!/bin/bash
# =============================================================================
# check_12.3_secrets_manager.sh
# CIS 12.3: Lambda phải dùng Secrets Manager thay vì hardcode credentials
# NT542 Group02 — Person 4
# =============================================================================

# Danh sách tên biến môi trường nhạy cảm cần kiểm tra
SENSITIVE_KEY_PATTERNS="PASSWORD|SECRET|KEY|TOKEN|CREDENTIAL|API_KEY|DB_PASS|ACCESS_KEY|PRIVATE_KEY|AUTH"

check_12_3_secrets_manager() {
    local region="$1"
    local function_name="$2"
    local output_file="$3"

    log_info "Checking CIS 12.3: Secrets Manager usage (no hardcoded credentials)..."

    local config
    config=$(get_lambda_config "$region" "$function_name")

    # Lấy danh sách tên biến môi trường
    local env_keys
    env_keys=$(echo "$config" | \
        python3 -c "import sys,json; c=json.load(sys.stdin); env=c.get('Environment',{}).get('Variables',{}); print('\n'.join(env.keys()))" \
        2>/dev/null || echo "")

    if [ -z "$env_keys" ]; then
        write_finding "$output_file" "$region" "$function_name" "12.3" "PASS" \
            "No environment variables found — no hardcoded credentials risk" "HIGH" \
            "Ensure credentials are fetched from AWS Secrets Manager at runtime"
        return
    fi

    # Kiểm tra tên biến có chứa từ khóa nhạy cảm không
    local found_sensitive=""
    while IFS= read -r key; do
        if echo "$key" | grep -iqE "$SENSITIVE_KEY_PATTERNS"; then
            found_sensitive="$found_sensitive $key"
        fi
    done <<< "$env_keys"

    found_sensitive=$(echo "$found_sensitive" | xargs)  # trim whitespace

    if [ -n "$found_sensitive" ]; then
        write_finding "$output_file" "$region" "$function_name" "12.3" "FAIL" \
            "Potentially sensitive environment variable names detected" "CRITICAL" \
            "Suspicious keys: [$found_sensitive] — Move to AWS Secrets Manager and use secretsmanager:GetSecretValue at runtime"
    else
        write_finding "$output_file" "$region" "$function_name" "12.3" "PASS" \
            "No sensitive credential names found in environment variables" "CRITICAL" \
            "Env vars present: [$env_keys] — Verified no obvious credential keys"
    fi
}
