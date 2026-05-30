#!/bin/bash
# =============================================================================
# check_12.3_secrets_manager.sh  (v2 — Sửa theo feedback CIS Benchmark)
# CIS 12.3: Lambda phải dùng Secrets Manager thay vì hardcode credentials
# NT542 Group02 — Person 4
# =============================================================================

check_12_3_secrets_manager() {
    local region="$1"
    local function_name="$2"
    local output_file="$3"

    log_info "Checking CIS 12.3: Secrets Manager usage (no hardcoded credentials)..."

    local config
    config=$(get_lambda_config "$region" "$function_name")

    # Phân tích environment variables: lấy cả KEY và VALUE
    local analysis
    analysis=$(echo "$config" | \
        python3 -c "
import sys, json

c = json.load(sys.stdin)
env = c.get('Environment', {}).get('Variables', {})

if not env:
    print('NO_ENV')
    sys.exit(0)

# Phân loại từng biến môi trường
secrets_ref = []     # Biến trỏ tới Secrets Manager (ARN) → TỐT
plaintext_creds = [] # Biến chứa credentials plaintext → XẤU

sensitive_patterns = ['PASSWORD', 'SECRET', 'KEY', 'TOKEN',
                      'CREDENTIAL', 'API_KEY', 'DB_PASS',
                      'ACCESS_KEY', 'PRIVATE_KEY', 'AUTH']

for key, value in env.items():
    # Kiểm tra VALUE có phải là ARN trỏ tới Secrets Manager không
    if value.startswith('arn:aws:secretsmanager:'):
        secrets_ref.append(key)
        continue

    # Kiểm tra VALUE có phải là ARN trỏ tới SSM Parameter Store không
    if value.startswith('arn:aws:ssm:'):
        secrets_ref.append(key)
        continue

    # Kiểm tra KEY có chứa từ khóa nhạy cảm không
    key_upper = key.upper()
    is_sensitive_name = any(p in key_upper for p in sensitive_patterns)

    if is_sensitive_name:
        # Kiểm tra VALUE có phải là plaintext (không phải ARN) không
        if not value.startswith('arn:aws:'):
            plaintext_creds.append(key)

if plaintext_creds:
    print('FAIL|' + ','.join(plaintext_creds))
elif secrets_ref:
    print('PASS_WITH_SM|' + ','.join(secrets_ref))
else:
    print('PASS_CLEAN')
" 2>/dev/null || echo "ERROR")

    case "$analysis" in
        NO_ENV)
            write_finding "$output_file" "$region" "$function_name" "12.3" "PASS" \
                "No environment variables found — no hardcoded credentials risk" "HIGH" \
                "Ensure credentials are fetched from AWS Secrets Manager at runtime"
            ;;
        PASS_WITH_SM*)
            local sm_keys="${analysis#PASS_WITH_SM|}"
            write_finding "$output_file" "$region" "$function_name" "12.3" "PASS" \
                "Lambda correctly references Secrets Manager via environment variables" "HIGH" \
                "Variables referencing Secrets Manager: [$sm_keys]"
            ;;
        PASS_CLEAN)
            write_finding "$output_file" "$region" "$function_name" "12.3" "PASS" \
                "No sensitive credential names found in environment variables" "HIGH" \
                "Environment variables present but no obvious credential patterns detected"
            ;;
        FAIL*)
            local bad_keys="${analysis#FAIL|}"
            write_finding "$output_file" "$region" "$function_name" "12.3" "FAIL" \
                "Hardcoded credentials detected in environment variables" "CRITICAL" \
                "Plaintext credential keys: [$bad_keys] — Move to AWS Secrets Manager and use secretsmanager:GetSecretValue at runtime"
            ;;
        *)
            write_finding "$output_file" "$region" "$function_name" "12.3" "WARN" \
                "Could not analyze environment variables" "HIGH" \
                "Manual review required"
            ;;
    esac
}
