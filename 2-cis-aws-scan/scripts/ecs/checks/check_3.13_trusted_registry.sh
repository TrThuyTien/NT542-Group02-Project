#!/bin/bash
check_3_13() {
    local region="$1"; local service="$2"; local taskdef="$3"

    IMAGES=$(aws ecs describe-task-definition \
        --task-definition "$taskdef" \
        --region "$region" \
        --query "taskDefinition.containerDefinitions[].image" \
        --output text)

    TRUSTED=true
    for IMG in $IMAGES; do
        if [[ "$IMG" != *.amazonaws.com/* ]]; then
            TRUSTED=false
        fi
    done

    if [ "$TRUSTED" = false ]; then
        write_finding "$region" "$service" "3.13" "FAIL" "Untrusted registry" "HIGH" "-"
    else
        write_finding "$region" "$service" "3.13" "PASS" "-" "LOW" "-"
    fi
}