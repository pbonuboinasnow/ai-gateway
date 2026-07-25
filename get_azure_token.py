#!/usr/bin/env python3
"""
Azure SP OAuth2 Access Token Generator for Service Principals.
Usage:
    python3 manifests/get_azure_token.py [path_to_azure_creds.json]
"""
import sys
import os
import json
import urllib.request
import urllib.parse

def log_info(msg):
    sys.stderr.write(f"\033[0;32m[INFO] {msg}\033[0m\n")

def log_error(msg):
    sys.stderr.write(f"\033[0;31m[ERROR] {msg}\033[0m\n")

def get_azure_token(creds_path, scope="https://cognitiveservices.azure.com/.default"):
    try:
        with open(creds_path, 'r') as f:
            creds = json.load(f)
    except Exception as e:
        log_error(f"Failed to read/parse credentials file {creds_path}: {e}")
        return None

    client_id = creds.get("client_id")
    tenant_id = creds.get("tenant_id")
    client_secret = creds.get("client_secret")

    if not all([client_id, tenant_id, client_secret]):
        log_error(f"Credentials file {creds_path} is missing required fields (client_id, tenant_id, or client_secret).")
        return None

    log_info(f"Requesting Azure SP token for tenant: {tenant_id} with scope: {scope}...")

    # MS Entra ID token endpoint
    token_url = f"https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token"
    
    data = {
        "grant_type": "client_credentials",
        "client_id": client_id,
        "client_secret": client_secret,
        "scope": scope
    }
    
    # URL encode the payload
    encoded_data = urllib.parse.urlencode(data).encode("utf-8")
    
    req = urllib.request.Request(
        token_url,
        data=encoded_data,
        headers={"Content-Type": "application/x-www-form-urlencoded"}
    )
    
    try:
        with urllib.request.urlopen(req) as response:
            res_body = response.read().decode("utf-8")
            res_json = json.loads(res_body)
            return res_json.get("access_token"), res_json.get("expires_in")
    except urllib.error.HTTPError as e:
        err_response = e.read().decode("utf-8") if e.fp else ""
        log_error(f"Azure token request failed with HTTP {e.code}: {e.reason}\nResponse: {err_response}")
        return None, None
    except Exception as e:
        log_error(f"Failed to make request or parse response: {e}")
        return None, None

def main():
    creds_path = "/tmp/manifests/azure_creds.json"
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

    token, expires_in = get_azure_token(creds_path)
    if token:
        log_info(f"Token acquired successfully! (Expires in {expires_in} seconds)")
        print(token)
        sys.exit(0)
    else:
        log_error("Could not generate Azure Service Principal token.")
        sys.exit(1)

if __name__ == "__main__":
    main()
