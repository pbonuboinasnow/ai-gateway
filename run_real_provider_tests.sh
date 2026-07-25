#!/usr/bin/env bash

# Sources AWS role assumption + generates GCP Vertex AI and Azure OpenAI tokens,
# then runs the real-provider data-plane tests.
#
# usage: ./run_real_provider_tests.sh [aws_creds.json] [gcp_creds.json] [azure_creds.json]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

AWS_CREDS_FILE="${1:-/tmp/manifests/aws_creds.json}"
GCP_CREDS_FILE="${2:-/tmp/manifests/gcp_creds.json}"
AZURE_CREDS_FILE="${3:-/tmp/manifests/azure_creds.json}"

log_info() {
    echo -e "\033[0;32m[INFO] $1\033[0m" >&2
}

log_info "Git branch: $(git -C "$SCRIPT_DIR" rev-parse --abbrev-ref HEAD)"
log_info "Git commit: $(git -C "$SCRIPT_DIR" rev-parse HEAD)"

# 1. AWS: assume role, exports TEST_AWS_ACCESS_KEY_ID / TEST_AWS_SECRET_ACCESS_KEY / TEST_AWS_SESSION_TOKEN.
log_info "Assuming AWS role..."
source "$SCRIPT_DIR/assume_role.sh" "$AWS_CREDS_FILE"

# 2. GCP Vertex AI: exports an OAuth2 access token + project/region.
log_info "Fetching GCP Vertex AI access token..."
export TEST_GCP_VERTEXAI_ACCESS_TOKEN="$(python3 "$SCRIPT_DIR/get_gcp_token.py" "$GCP_CREDS_FILE")"
export TEST_GCP_VERTEXAI_PROJECT="${TEST_GCP_VERTEXAI_PROJECT:-now-gemini-subprod}"
export TEST_GCP_VERTEXAI_REGION="${TEST_GCP_VERTEXAI_REGION:-us-central1}"

# 3. Azure OpenAI: exports an Entra ID (Azure AD) OAuth2 access token.
log_info "Fetching Azure OpenAI access token..."
export TEST_AZURE_ACCESS_TOKEN="$(python3 "$SCRIPT_DIR/get_azure_token.py" "$AZURE_CREDS_FILE")"

log_info "All credentials exported. Running tests..."
# go test -v ./tests/data-plane/... -run="TestWithRealProviders"
go test -v ./tests/data-plane/... -run="TestWithRealProviders" -skip="embeddings" -skip="messages"
