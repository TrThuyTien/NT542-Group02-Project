#!/bin/bash
# =============================================================================
# check_12.12_env_encryption.sh  (v2 — Sửa theo feedback CIS Benchmark)
# CIS 12.12: Environment variables phải được mã hóa in-transit
# NT542 Group02 — Person 4
# =============================================================================

check_12_12_env_encryption() {
    local region="$1"
    local function_name="$2"
    local output_file="$3"

    log_info "Checking CIS 12.12: Environment variables encrypted in transit (KMS)..."

    # Dùng get-function (không phải get-function-configuration) để lấy được giá trị biến
    local func_data
    func_data=$(aws lambda get-function \
        --region "$region" \
        --function-name "$function_name" \
        --query "Configuration.Environment" \
        --output json 2>/dev/null || echo "{}")

    # Phân tích giá trị biến: plaintext hay ciphertext?
    local analysis
    analysis=$(echo "$func_data" | \
        python3 -c "
import sys, json, re

try:
    data = json.load(sys.stdin)
except:
    print('NO_ENV')
    sys.exit(0)

env = data.get('Variables', {})

if not env:
    print('NO_ENV')
    sys.exit(0)

# Regex nhận diện ciphertext (chuỗi Base64 dài, thường bắt đầu bằng AQICA hoặc AQECA)
ciphertext_pattern = re.compile(r'^AQ[IE]CA[A-Za-z0-9+/=]{20,}$')

plaintext_vars = []
encrypted_vars = []

for key, value in env.items():
    value_stripped = value.strip()

    # Kiểm tra giá trị có phải ciphertext (mã hóa bởi KMS helpers) không
    if ciphertext_pattern.match(value_stripped):
        encrypted_vars.append(key)
    # Kiểm tra giá trị có phải ARN (tham chiếu, không phải secret thật)
    elif value_stripped.startswith('arn:aws:'):
        encrypted_vars.append(key)  # ARN reference — an toàn
    else:
        plaintext_vars.append(key)

if plaintext_vars:
    print('FAIL|' + ','.join(plaintext_vars) + '|' + ','.join(encrypted_vars))
elif encrypted_vars:
    print('PASS_ENCRYPTED|' + ','.join(encrypted_vars))
else:
    print('NO_ENV')
" 2>/dev/null || echo "ERROR")

    case "$analysis" in
        NO_ENV)
            write_finding "$output_file" "$region" "$function_name" "12.12" "PASS" \
                "No environment variables configured — encryption not required" "MEDIUM" \
                "No environment variables to encrypt"
            ;;
        PASS_ENCRYPTED*)
            local enc_keys="${analysis#PASS_ENCRYPTED|}"
            write_finding "$output_file" "$region" "$function_name" "12.12" "PASS" \
                "All environment variable values are encrypted or are safe references" "HIGH" \
                "Encrypted/Safe variables: [$enc_keys]"
            ;;
        FAIL*)
            # Tách phần plaintext và encrypted
            local rest="${analysis#FAIL|}"
            local plain_keys="${rest%%|*}"
            local enc_keys="${rest#*|}"
            write_finding "$output_file" "$region" "$function_name" "12.12" "FAIL" \
                "Environment variables contain plaintext values — not encrypted in transit" "HIGH" \
                "Plaintext variables: [$plain_keys]. Enable 'helpers for encryption in transit' in Lambda console and encrypt with KMS."
            ;;
        *)
            write_finding "$output_file" "$region" "$function_name" "12.12" "WARN" \
                "Could not analyze environment variable encryption status" "HIGH" \
                "Manual review required — check Lambda console for encryption helpers"
            ;;
    esac
}
