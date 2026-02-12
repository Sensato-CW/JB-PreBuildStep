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
    USER_JSON=$(curl -sS -w "\n%{http_code}" -o $BODY_FILE \
    -H "Authorization: Bearer $GITHUB_TOKEN" $GITHUB_API_USER)

    # Split out HTTP status and response body
    HTTP_CODE=$(tail -n1 <<<"$USER_JSON")
    BODY=$(head -n -1 <<<"$USER_JSON")

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

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
sudo -E apt update -y && sudo -E apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
sudo -E apt install -y curl git

#--- main ---
GITHUB_REPO_URL="https://raw.githubusercontent.com/gocloudwave/BuildStep/refs/heads/main/clone_repo.sh"

# Accept GITHUB_TOKEN from environment (AWX) or prompt interactively
if [[ -z "$GITHUB_TOKEN" ]]; then
    read -p "Enter github classic token: " GITHUB_TOKEN
fi

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
$SUDO chown "$(id -u):$(id -g)" clone_repo.sh
$SUDO chmod +x clone_repo.sh
mv clone_repo.sh /opt/clone_repo.sh
$SUDO env GITHUB_USER="${GITHUB_USER}" GITHUB_TOKEN="${GITHUB_TOKEN}" BUILD_OPTION="${BUILD_OPTION:-}" bash /opt/clone_repo.sh

log "Removing get_it.sh script for security."
sudo rm -f get_it.sh
