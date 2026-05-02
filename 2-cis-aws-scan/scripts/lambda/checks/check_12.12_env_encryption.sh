#!/bin/bash
# =============================================================================
# check_12.12_env_encryption.sh
# CIS 12.12: Environment variables phải được mã hóa (KMS CMK)
# NT542 Group02 — Person 4
# =============================================================================

check_12_12_env_encryption() {
    local region="$1"
    local function_name="$2"
    local output_file="$3"

    log_info "Checking CIS 12.12: Environment variables encrypted in transit (KMS)..."

    local config
    config=$(get_lambda_config "$region" "$function_name")

    # Kiểm tra có environment variables không
    local has_env_vars
    has_env_vars=$(echo "$config" | \
        python3 -c "
import sys, json
c = json.load(sys.stdin)
env = c.get('Environment', {}).get('Variables', {})
print('yes' if env else 'no')
" 2>/dev/null || echo "no")

    if [ "$has_env_vars" = "no" ]; then
        write_finding "$output_file" "$region" "$function_name" "12.12" "PASS" \
            "No environment variables configured — encryption not required" "MEDIUM" \
            "No environment variables to encrypt"
        return
    fi

    # Lấy KMS Key ARN
    local kms_key
    kms_key=$(echo "$config" | \
        python3 -c "
import sys, json
c = json.load(sys.stdin)
print(c.get('KMSKeyArn', 'NONE'))
" 2>/dev/null || echo "NONE")

    if [ "$kms_key" = "NONE" ] || [ -z "$kms_key" ] || [ "$kms_key" = "None" ]; then
        write_finding "$output_file" "$region" "$function_name" "12.12" "FAIL" \
            "Environment variables exist but are NOT encrypted with a Customer-Managed KMS Key" "HIGH" \
            "Lambda has environment variables but KMSKeyArn is not set. Configure a CMK to encrypt environment variables at rest."
    else
        # Kiểm tra key có phải CMK (Customer-Managed) không
        local key_manager
        key_manager=$(aws kms describe-key \
            --region "$region" \
            --key-id "$kms_key" \
            --query "KeyMetadata.KeyManager" \
            --output text 2>/dev/null || echo "UNKNOWN")

        if [ "$key_manager" = "AWS" ]; then
            write_finding "$output_file" "$region" "$function_name" "12.12" "WARN" \
                "Environment variables encrypted with AWS-managed key (not CMK)" "MEDIUM" \
                "KMS Key: $kms_key (AWS-managed). For CIS compliance, use a Customer-Managed Key (CMK) for better key control."
        else
            write_finding "$output_file" "$region" "$function_name" "12.12" "PASS" \
                "Environment variables encrypted with Customer-Managed KMS Key" "HIGH" \
                "KMS Key ARN: $kms_key (Manager: $key_manager)"
        fi
    fi
}
