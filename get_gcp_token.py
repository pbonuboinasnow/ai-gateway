#!/usr/bin/env python3
"""
GCP OAuth2 Access Token Generator for Service Accounts.
Usage:
    python3 manifests/get_gcp_token.py [path_to_gcp_creds.json]
"""
import sys
import os
import subprocess

def log_info(msg):
    sys.stderr.write(f"\033[0;32m[INFO] {msg}\033[0m\n")

def log_error(msg):
    sys.stderr.write(f"\033[0;31m[ERROR] {msg}\033[0m\n")

def get_token_via_google_auth(creds_path):
    try:
        from google.oauth2 import service_account
        import google.auth.transport.requests

        # Cloud platform scope is required for Vertex AI / Gemini API access
        scopes = ["https://www.googleapis.com/auth/cloud-platform"]
        creds = service_account.Credentials.from_service_account_file(creds_path, scopes=scopes)
        request = google.auth.transport.requests.Request()
        creds.refresh(request)
        return creds.token
    except ImportError:
        log_info("google-auth Python library is not installed.")
        return None
    except Exception as e:
        log_error(f"google-auth library approach failed: {e}")
        return None

def get_token_via_gcloud(creds_path):
    try:
        # 1. Activate the service account
        subprocess.run(
            ["gcloud", "auth", "activate-service-account", f"--key-file={creds_path}"],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE
        )
        # 2. Extract access token
        res = subprocess.run(
            ["gcloud", "auth", "print-access-token"],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        return res.stdout.strip()
    except Exception as e:
        log_error(f"gcloud approach failed: {e}")
        return None

def main():
    creds_path = "/tmp/manifests/gcp_creds.json"
    if len(sys.argv) > 1:
        creds_path = sys.argv[1]

    # Handle standard paths if not found directly
    if not os.path.exists(creds_path):
        possible_paths = [
            creds_path,
            os.path.join("manifests", os.path.basename(creds_path)),
            os.path.join(".", os.path.basename(creds_path))
        ]
        found = False
        for path in possible_paths:
            if os.path.exists(path):
                creds_path = path
                found = True
                break
        if not found:
            log_error(f"Credentials file '{creds_path}' not found.")
            sys.exit(1)

    # 1. Try google-auth library first
    token = get_token_via_google_auth(creds_path)
    if token:
        print(token)
        sys.exit(0)

    # 2. Try gcloud CLI fallback
    token = get_token_via_gcloud(creds_path)
    if token:
        print(token)
        sys.exit(0)

    # 3. If both failed, guide the user on how to install google-auth
    log_error("\nCould not generate token. Please install the required Google Auth library:")
    print("pip install google-auth", file=sys.stderr)
    sys.exit(1)

if __name__ == "__main__":
    main()
