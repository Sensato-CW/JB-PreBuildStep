#!/bin/bash
set -euo pipefail

# --- CONFIG ---
GITHUB_API_USER="https://api.github.com/user"
GITHUB_REPO_URL="https://raw.githubusercontent.com/gocloudwave/BuildStep/refs/heads/main/clone_repo.sh"
# --------------

log() { echo "[$(date '+%F %T')] $*"; }

github_token_validate_pull_user() {
    log "Validating GitHub token and fetching user info..."

    if [ -z "${GITHUB_TOKEN:-}" ]; then
        log "ERROR: GITHUB_TOKEN environment variable not set."
        exit 1
    fi

    BODY_FILE="$(mktemp)"
    USER_JSON=$(curl -sS -w "\n%{http_code}" -o "$BODY_FILE" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        "$GITHUB_API_USER")

    HTTP_CODE=$(tail -n1 <<<"$USER_JSON")

    if [ "$HTTP_CODE" != "200" ]; then
        log "ERROR: GitHub token validation failed (HTTP $HTTP_CODE)."
        cat "$BODY_FILE"
        exit 1
    fi

    GITHUB_USER=$(grep -oE '"login": ?"[^"]+' "$BODY_FILE" | cut -d'"' -f4)
    rm -f "$BODY_FILE"

    if [ -z "$GITHUB_USER" ]; then
        log "ERROR: Could not extract username from GitHub response."
        exit 1
    fi

    log "Token is valid for user: $GITHUB_USER"
}

# 🔥 DO NOT auto-upgrade during automation
sudo apt update -y
sudo apt install -y curl git

# --- main ---
if [ -z "${GITHUB_TOKEN:-}" ]; then
    log "ERROR: GITHUB_TOKEN not provided."
    exit 1
fi

github_token_validate_pull_user

curl -sS -f -o clone_repo.sh \
    -H "Authorization: token $GITHUB_TOKEN" \
    "$GITHUB_REPO_URL" || { log "Error downloading clone_repo.sh."; exit 1; }

chmod +x clone_repo.sh
sudo mv clone_repo.sh /opt/clone_repo.sh

sudo env GITHUB_USER="${GITHUB_USER}" GITHUB_TOKEN="${GITHUB_TOKEN}" \
    bash /opt/clone_repo.sh

log "Prebuild completed successfully."
