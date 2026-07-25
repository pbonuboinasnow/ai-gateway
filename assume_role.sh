#!/usr/bin/env bash

# This script must be sourced to export the AWS credentials to your current shell:
# usage: source assume_role.sh [path_to_creds.json]

log_error() {
    echo -e "\033[0;31m[ERROR] $1\033[0m" >&2
}

log_info() {
    echo -e "\033[0;32m[INFO] $1\033[0m" >&2
}

CREDS_FILE=""
if [ -n "$1" ]; then
    CREDS_FILE="$1"
elif [ -f "/tmp/manifests/aws_creds.json" ]; then
    CREDS_FILE="/tmp/manifests/aws_creds.json"
elif [ -f "./aws_creds.json" ]; then
    CREDS_FILE="./aws_creds.json"
fi

if [ -n "$CREDS_FILE" ] && [ -f "$CREDS_FILE" ]; then
    log_info "Reading credentials from $CREDS_FILE"
    
    READ_KEY_ID=$(python3 -c "import json; print(json.load(open('$CREDS_FILE')).get('aws_access_key_id', ''))" 2>/dev/null)
    READ_SECRET=$(python3 -c "import json; print(json.load(open('$CREDS_FILE')).get('aws_secret_access_key', ''))" 2>/dev/null)
    READ_ROLE_ARN=$(python3 -c "import json; print(json.load(open('$CREDS_FILE')).get('role_arn', ''))" 2>/dev/null)

    if [ -n "$READ_KEY_ID" ]; then export AWS_ACCESS_KEY_ID="$READ_KEY_ID"; fi
    if [ -n "$READ_SECRET" ]; then export AWS_SECRET_ACCESS_KEY="$READ_SECRET"; fi
    if [ -n "$READ_ROLE_ARN" ]; then ROLE_ARN="$READ_ROLE_ARN"; fi
fi

if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    log_error "AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY must be set or provided via JSON."
    return 1 2>/dev/null || exit 1
fi

if [ -z "$ROLE_ARN" ]; then
    log_error "ROLE_ARN must be set or provided via JSON."
    return 1 2>/dev/null || exit 1
fi

unset AWS_SESSION_TOKEN

log_info "Assuming role: $ROLE_ARN"

ASSUME_ROLE_OUT=$(aws sts assume-role \
  --role-arn "$ROLE_ARN" \
  --role-session-name "cli-session-$(date +%s)" \
  --output json 2>&1)

if [ $? -ne 0 ]; then
    log_error "Failed to assume role:\n$ASSUME_ROLE_OUT"
    return 1 2>/dev/null || exit 1
fi

TEMP_KEY_ID=$(echo "$ASSUME_ROLE_OUT" | python3 -c "import json, sys; print(json.load(sys.stdin)['Credentials']['AccessKeyId'])" 2>/dev/null)
TEMP_SECRET=$(echo "$ASSUME_ROLE_OUT" | python3 -c "import json, sys; print(json.load(sys.stdin)['Credentials']['SecretAccessKey'])" 2>/dev/null)
TEMP_TOKEN=$(echo "$ASSUME_ROLE_OUT" | python3 -c "import json, sys; print(json.load(sys.stdin)['Credentials']['SessionToken'])" 2>/dev/null)
TEMP_EXPIRATION=$(echo "$ASSUME_ROLE_OUT" | python3 -c "import json, sys; print(json.load(sys.stdin)['Credentials']['Expiration'])" 2>/dev/null)

if [ -z "$TEMP_KEY_ID" ] || [ -z "$TEMP_SECRET" ] || [ -z "$TEMP_TOKEN" ]; then
    log_error "Failed to parse assumed role credentials from STS response."
    return 1 2>/dev/null || exit 1
fi

export TEST_AWS_ACCESS_KEY_ID="$TEMP_KEY_ID"
export TEST_AWS_SECRET_ACCESS_KEY="$TEMP_SECRET"
export TEST_AWS_SESSION_TOKEN="$TEMP_TOKEN"

export AWS_ACCESS_KEY_ID="$TEMP_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$TEMP_SECRET"
export AWS_SESSION_TOKEN="$TEMP_TOKEN"

#go test -v ./tests/data-plane/... -run="TestWithRealProviders"
#go test -v ./tests/data-plane/... -run="TestWithRealProviders/(chat/completions/aws-bedrock|messages/anthropic-aws-bedrock|streaming/aws-bedrock|uses_tool_in_response/.*)"
# go test -v ./tests/data-plane/... -run="TestWithRealProviders" -skip="embeddings" -skip="messages"

log_info "Successfully assumed role! Credentials exported to environment."
log_info "Credentials expire at: $TEMP_EXPIRATION"
