#!/bin/bash
set -euo pipefail

# --- CONFIG ---
GITHUB_API_USER="https://api.github.com/user"
GITHUB_REPO_URL="https://raw.githubusercontent.com/gocloudwave/BuildStep/main/clone_repo.sh"
# --------------

log() { echo "[$(date '+%F %T')] $*"; }

github_token_validate_pull_user() {
  log "Validating GitHub token and fetching user info..."

  if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    log "ERROR: GITHUB_TOKEN not set. Aborting."
    exit 1
  fi

  local body_file http_code github_user
  body_file="$(mktemp)"

  http_code="$(curl -sS -o "$body_file" -w "%{http_code}" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    "$GITHUB_API_USER")"

  if [[ "$http_code" != "200" ]]; then
    log "ERROR: GitHub token validation failed (HTTP $http_code). Response:"
    cat "$body_file" || true
    rm -f "$body_file"
    exit 1
  fi

  github_user="$(grep -oE '"login": ?"[^"]+' "$body_file" | cut -d'"' -f4 || true)"
  rm -f "$body_file"

  if [[ -z "$github_user" ]]; then
    log "ERROR: Could not extract username from GitHub response."
    exit 1
  fi

  GITHUB_USER="$github_user"
  export GITHUB_USER
  log "Token is valid for user: $GITHUB_USER"
}

require_env() {
  local var_name="$1"
  if [[ -z "${!var_name:-}" ]]; then
    log "ERROR: Required environment variable '$var_name' is not set."
    exit 1
  fi
}

# --- REQUIREMENTS / NONINTERACTIVE APT ---
export DEBIAN_FRONTEND=noninteractive

log "Updating package lists and installing prerequisites (curl, git)..."
apt-get update -y
apt-get install -y curl git

# --- MAIN ---
require_env "GITHUB_TOKEN"

# BUILD_OPTION is optional; if not set, clone_repo.sh may prompt (unless you removed prompting there)
export BUILD_OPTION="${BUILD_OPTION:-}"

github_token_validate_pull_user

log "Downloading clone_repo.sh to /opt/clone_repo.sh ..."
curl -sS -f -o /opt/clone_repo.sh \
  -H "Authorization: token $GITHUB_TOKEN" \
  "$GITHUB_REPO_URL" || { log "ERROR: Failed downloading clone_repo.sh"; exit 1; }

chmod +x /opt/clone_repo.sh

log "Executing /opt/clone_repo.sh (forwarding GITHUB_USER, GITHUB_TOKEN, BUILD_OPTION)..."
env \
  GITHUB_USER="${GITHUB_USER}" \
  GITHUB_TOKEN="${GITHUB_TOKEN}" \
  BUILD_OPTION="${BUILD_OPTION}" \
  bash /opt/clone_repo.sh

log "get_it.sh completed successfully."
