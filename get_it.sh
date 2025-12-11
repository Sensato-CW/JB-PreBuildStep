#!/bin/bash

# --- CONFIG ---
GITHUB_API_USER="https://api.github.com/user"
# --------------

log() { echo "[$(date '+%F %T')] $*"; }

github_token_validate_pull_user() {
    log "Validating GitHub token and fetching user info..."

    if [ -z "${GITHUB_TOKEN:-}" ]; then
        log "ERROR: GITHUB_TOKEN not set. Aborting."
        exit 1
    fi

    # Hit the /user endpoint
    BODY_FILE="$(mktemp)"
    STDERR_FILE="$(mktemp)"
    wget -q -O "$BODY_FILE" --header="Authorization: Bearer $GITHUB_TOKEN" --server-response "$GITHUB_API_USER" 2> "$STDERR_FILE"
    HTTP_CODE=$(awk '/^  HTTP/{print $2}' "$STDERR_FILE" | tail -1)
    rm -f "$STDERR_FILE"

    if [ -z "$HTTP_CODE" ]; then
        HTTP_CODE="unknown"
    fi

    # Extract username directly from BODY_FILE
    if [ "$HTTP_CODE" != "200" ]; then
        log "ERROR: GitHub token validation failed (HTTP $HTTP_CODE)."
        cat $BODY_FILE
        exit 1
    fi

    # Extract username from JSON safely (using grep + cut for portability)
    GITHUB_USER=$(grep -oE '"login": ?"[^"]+' $BODY_FILE | cut -d'"' -f4)
    if [ -z "$GITHUB_USER" ]; then
        log "ERROR: Could not extract username from GitHub response."
        exit 1
    fi
    rm -f "$BODY_FILE"

    log "Token is valid for user: $GITHUB_USER"
}

GITHUB_REPO_URL="https://raw.githubusercontent.com/gocloudwave/BuildStep/refs/heads/main/clone_repo.sh"
read -s -p "Enter github classic token: " GITHUB_TOKEN
log ""

if [[ -z "$GITHUB_TOKEN" ]]; then
    log "No github token entered."
    exit 1
fi

github_token_validate_pull_user

# --- helper ---
if [ "$(id -u)" -ne 0 ]; then
    SUDO="sudo"
else
    SUDO=""
fi


$SUDO curl -sS -f -o clone_repo.sh \
    -H "Authorization: token $GITHUB_TOKEN" \
    "$GITHUB_REPO_URL" || { log "Error curl-ing clone_repo.sh."; exit 1; }

$SUDO chmod +x clone_repo.sh
GITHUB_USER="${GITHUB_USER}" GITHUB_TOKEN="${GITHUB_TOKEN}" $SUDO bash clone_repo.sh