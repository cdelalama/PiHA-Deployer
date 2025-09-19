#!/bin/bash
set -e

# Version
VERSION="1.0.2"

BLUE='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

echo -e "${BLUE}PiHA-Deployer NAS MariaDB bootstrap v${VERSION}${NC}"

_load_env_file() {
  local file="$1"
  [ -f "$file" ] || return 0
  while IFS= read -r line; do
    line="$(printf '%s' "$line" | sed $'s/\xEF\xBB\xBF//g; s/\xC2\xA0/ /g' | tr -d '\r')"
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    if [[ $line =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=(.*)$ ]]; then
      local key="${BASH_REMATCH[1]}"
      local value="${BASH_REMATCH[2]}"
      key="$(echo "$key" | xargs)"
      value="$(echo "$value" | xargs)"
      if [[ $value =~ ^\"(.*)\"$ ]]; then value="${BASH_REMATCH[1]}"; fi
      if [[ $value =~ ^\'(.*)\'$ ]]; then value="${BASH_REMATCH[1]}"; fi
      printf -v "$key" '%s' "$value"
      export "$key"
    fi
  done < "$file"
}

load_env() {
  _load_env_file "${SCRIPT_DIR}/../../common/Common.env"
  _load_env_file "${SCRIPT_DIR}/../../common/common.env"
  _load_env_file "${SCRIPT_DIR}/../common/Common.env"
  _load_env_file "${SCRIPT_DIR}/../common/common.env"
  _load_env_file "${SCRIPT_DIR}/common/Common.env"
  _load_env_file "${SCRIPT_DIR}/common/common.env"
  _load_env_file "$HOME/.piha/common.env"
  _load_env_file "/etc/piha/common.env"
  if [ ! -f "${SCRIPT_DIR}/.env" ]; then
    echo -e "${RED}[ERROR] ${SCRIPT_DIR}/.env not found. Create it based on home-assistant/mariadb/README.md.${NC}"
    exit 1
  fi
  chmod 600 "${SCRIPT_DIR}/.env" || true
  _load_env_file "${SCRIPT_DIR}/.env"
  echo -e "${GREEN}[OK] Environment loaded${NC}"
}

bool_true() {
  local val
  val="$(printf "%s" "$1" | tr "[:upper:]" "[:lower:]")"
  case "$val" in
    1|y|yes|true|on) return 0 ;;
    *) return 1 ;;
  esac
}

require_vars() {
  local missing=()
  for v in "$@"; do
    if [ -z "${!v}" ]; then
      missing+=("$v")
    fi
  done
  if [ ${#missing[@]} -gt 0 ]; then
    echo -e "${RED}[ERROR] Missing required variables:${NC} ${missing[*]}"
    exit 1
  fi
}

ensure_tools() {
  for tool in ssh scp; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      echo -e "${RED}[ERROR] Required tool '$tool' not found.${NC}"
      exit 1
    fi
  done
}

shell_quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\''/g")"
}

remote_exec_cmd() {
  local command="$1"
  ssh -p "$NAS_SSH_PORT" "$NAS_SSH_USER@$NAS_SSH_HOST" "bash -lc $(shell_quote "set -e; ${command}")"
}

main() {
  load_env
  ensure_tools

  NAS_SSH_PORT="${NAS_SSH_PORT:-22}"
  NAS_SSH_USE_SUDO="${NAS_SSH_USE_SUDO:-false}"
  NAS_DEPLOY_DIR="${NAS_DEPLOY_DIR:-/share/Container/compose/mariadb}"
  MARIADB_DATA_DIR="${MARIADB_DATA_DIR:-${NAS_DEPLOY_DIR}/data}"

  require_vars NAS_SSH_HOST NAS_SSH_USER MARIADB_ROOT_PASSWORD MARIADB_DATABASE MARIADB_USER MARIADB_PASSWORD MARIADB_DATA_DIR PUBLISHED_PORT

  local SUDO=""
  if bool_true "$NAS_SSH_USE_SUDO"; then
    SUDO="sudo "
  fi

  echo -e "${BLUE}Testing SSH connectivity...${NC}"
  if ! ssh -p "$NAS_SSH_PORT" "$NAS_SSH_USER@$NAS_SSH_HOST" "echo ok" >/dev/null 2>&1; then
    echo -e "${RED}[ERROR] SSH connection failed. Verify host, user, and keys/passwords.${NC}"
    exit 1
  fi
  echo -e "${GREEN}[OK] SSH reachable${NC}"

  echo -e "${BLUE}Creating deployment directories on NAS...${NC}"
  remote_exec_cmd "${SUDO}mkdir -p $(shell_quote "$NAS_DEPLOY_DIR")"
  remote_exec_cmd "${SUDO}mkdir -p $(shell_quote "$MARIADB_DATA_DIR")"

  echo -e "${BLUE}Checking Docker availability on NAS...${NC}"
  if ! remote_exec_cmd "${SUDO}docker --version >/dev/null 2>&1"; then
    echo -e "${RED}[ERROR] Docker is not available on the NAS. Install Docker before running this script.${NC}"
    exit 1
  fi

  echo -e "${BLUE}Copying docker-compose.yml...${NC}"
  scp -P "$NAS_SSH_PORT" "${SCRIPT_DIR}/docker-compose.yml" "$NAS_SSH_USER@$NAS_SSH_HOST:${NAS_DEPLOY_DIR}/docker-compose.yml" >/dev/null

  echo -e "${BLUE}Rendering .env for MariaDB...${NC}"
  local tmp_env
  tmp_env=$(mktemp)
  trap 'rm -f "$tmp_env"' EXIT
  cat > "$tmp_env" <<EOF
MARIADB_ROOT_PASSWORD=${MARIADB_ROOT_PASSWORD}
MARIADB_DATABASE=${MARIADB_DATABASE}
MARIADB_USER=${MARIADB_USER}
MARIADB_PASSWORD=${MARIADB_PASSWORD}
MARIADB_DATA_DIR=${MARIADB_DATA_DIR}
PUBLISHED_PORT=${PUBLISHED_PORT}
EOF

  scp -P "$NAS_SSH_PORT" "$tmp_env" "$NAS_SSH_USER@$NAS_SSH_HOST:${NAS_DEPLOY_DIR}/.env" >/dev/null
  remote_exec_cmd "${SUDO}chmod 600 $(shell_quote "${NAS_DEPLOY_DIR}/.env")"

  echo -e "${BLUE}Starting MariaDB container on NAS...${NC}"
  if remote_exec_cmd "${SUDO}docker compose version >/dev/null 2>&1"; then
    remote_exec_cmd "cd $(shell_quote "$NAS_DEPLOY_DIR") && ${SUDO}docker compose up -d"
  else
    remote_exec_cmd "cd $(shell_quote "$NAS_DEPLOY_DIR") && ${SUDO}docker-compose up -d"
  fi

  echo -e "${GREEN}[OK] MariaDB deployment finished${NC}"
  echo -e "${BLUE}Service details:${NC}"
  echo -e "${BLUE}- Host: ${NAS_SSH_HOST}:${PUBLISHED_PORT}${NC}"
  echo -e "${BLUE}- Database: ${MARIADB_DATABASE} (user: ${MARIADB_USER})${NC}"
  echo -e "${BLUE}- Data path: ${MARIADB_DATA_DIR}${NC}"
}

main "$@"