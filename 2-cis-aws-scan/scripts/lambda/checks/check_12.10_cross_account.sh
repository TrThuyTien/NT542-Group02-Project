#!/bin/bash
# =============================================================================
# check_12.10_cross_account.sh
# CIS 12.10: Không có unknown cross-account access trong resource policy
# NT542 Group02 — Person 4
# =============================================================================

check_12_10_cross_account() {
    local region="$1"
    local function_name="$2"
    local output_file="$3"

    log_info "Checking CIS 12.10: No unknown cross-account access..."

    # Lấy resource-based policy của Lambda
    local policy_json
    policy_json=$(aws lambda get-policy \
        --region "$region" \
        --function-name "$function_name" \
        --query "Policy" \
        --output text 2>/dev/null || echo "NO_POLICY")

    if [ "$policy_json" = "NO_POLICY" ] || [ -z "$policy_json" ]; then
        write_finding "$output_file" "$region" "$function_name" "12.10" "PASS" \
            "No resource-based policy exists — no cross-account access configured" "HIGH" \
            "Lambda has no public or cross-account resource policy"
        return
    fi

    # Lấy account ID hiện tại
    local current_account
    current_account=$(get_account_id)

    # Parse principals từ policy
    local principals
    principals=$(echo "$policy_json" | \
        python3 -c "
import sys, json
try:
    policy = json.loads(sys.stdin.read())
    principals = []
    for stmt in policy.get('Statement', []):
        p = stmt.get('Principal', {})
        if isinstance(p, str):
            principals.append(p)
        elif isinstance(p, dict):
            for v in p.values():
                if isinstance(v, list):
                    principals.extend(v)
                else:
                    principals.append(v)
    print('\n'.join(principals))
except Exception as e:
    print('')
" 2>/dev/null || echo "")

    if [ -z "$principals" ]; then
        write_finding "$output_file" "$region" "$function_name" "12.10" "PASS" \
            "Resource policy has no external principals" "HIGH" \
            "Policy exists but no cross-account principals found"
        return
    fi

    local unknown_principals=""
    while IFS= read -r principal; do
        [ -z "$principal" ] && continue
        # Bỏ qua AWS services (arn:aws:iam::*:root), current account, và services như events.amazonaws.com
        if echo "$principal" | grep -q "amazonaws.com"; then
            continue  # AWS service principal — OK
        fi
        if echo "$principal" | grep -q "$current_account"; then
            continue  # Same account — OK
        fi
        if [ "$principal" = "*" ]; then
            unknown_principals="$unknown_principals [PUBLIC:*]"
            continue
        fi
        # Còn lại là unknown cross-account
        unknown_principals="$unknown_principals [$principal]"
    done <<< "$principals"

    unknown_principals=$(echo "$unknown_principals" | xargs)

    if [ -n "$unknown_principals" ]; then
        write_finding "$output_file" "$region" "$function_name" "12.10" "FAIL" \
            "Unknown cross-account or public principals found in resource policy" "HIGH" \
            "Unknown principals: $unknown_principals — Review and remove unauthorized access"
    else
        write_finding "$output_file" "$region" "$function_name" "12.10" "PASS" \
            "All principals in resource policy are from the same account or known AWS services" "HIGH" \
            "All principals verified: $(echo "$principals" | tr '\n' ' ')"
    fi
}
