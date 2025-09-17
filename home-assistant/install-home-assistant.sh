#!/bin/bash
set -e

# Version
VERSION="1.1.2"

# Colors
BLUE='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

COMPOSE_SOURCE_URL="https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/docker-compose.yml"

echo -e "${BLUE}PiHA-Deployer Home Assistant Installer v${VERSION}${NC}"

# Minimal env loader helpers (no secrets printed)
_load_env_file() {
  local file="$1"
  [ -f "$file" ] || return 0
  while IFS= read -r line; do
    # Normalize: strip BOM, convert NBSP to space, strip CR
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
  # Optional shared configuration (earlier sources provide defaults)
  _load_env_file "../common/Common.env"
  _load_env_file "../common/common.env"
  _load_env_file "common/Common.env"
  _load_env_file "common/common.env"
  _load_env_file "$HOME/.piha/common.env"
  _load_env_file "/etc/piha/common.env"
  # Current directory common (for local testing)
  _load_env_file "./Common.env"
  _load_env_file "./common.env"
  # Component-specific .env (authoritative for this host/component)
  if [ ! -f .env ]; then
    echo -e "${RED}[ERROR] .env file not found in current directory${NC}"
    exit 1
  fi
  chmod 600 .env || true
  _load_env_file ".env"
  echo -e "${GREEN}[OK] Environment loaded${NC}"
}

bool_true() {
  case "${1,,}" in
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
    echo -e "${RED}[ERROR] Missing required variables in .env:${NC} ${missing[*]}"
    exit 1
  fi
}

# Fallback: attempt to salvage PORTAINER_PASS if parser missed it (edge cases)
post_load_fallbacks() {
  if [ -z "$PORTAINER_PASS" ] && [ -f .env ]; then
    local line
    line=$(grep -E '^[[:space:]]*PORTAINER_PASS[[:space:]]*=' .env | tail -n 1 || true)
    if [ -n "$line" ]; then
      line="$(printf '%s' "$line" | sed $'s/\xEF\xBB\xBF//g; s/\xC2\xA0/ /g' | tr -d '\r')"
      local val
      val="${line#*=}"
      val="$(echo "$val" | xargs)"
      export PORTAINER_PASS="$val"
    fi
  fi
}

ensure_packages() {
  echo -e "${BLUE}Ensuring required packages are present...${NC}"
  sudo apt-get update -y
  sudo apt-get install -y ca-certificates curl gnupg lsb-release smbclient cifs-utils netcat-openbsd mariadb-client
}

ensure_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo -e "${BLUE}Installing Docker (get.docker.com)...${NC}"
    curl -fsSL https://get.docker.com | sh
  else
    echo -e "${GREEN}[OK] Docker already installed${NC}"
  fi
  # Compose plugin check
  if ! docker compose version >/dev/null 2>&1; then
    echo -e "${BLUE}Installing Docker Compose plugin...${NC}"
    # Try apt packaged plugin
    if apt-cache policy docker-compose-plugin 2>/dev/null | grep -q Candidate; then
      sudo apt-get install -y docker-compose-plugin
    else
      echo -e "${YELLOW}[WARN] docker-compose-plugin not found in apt; will fallback to 'docker-compose' if available${NC}"
    fi
  else
    echo -e "${GREEN}[OK] Docker Compose plugin available${NC}"
  fi
}

docker_compose_cmd() {
  if docker compose version >/dev/null 2>&1; then
    echo "docker compose"
  elif command -v docker-compose >/dev/null 2>&1; then
    echo "docker-compose"
  else
    echo ""
  fi
}

mount_nas() {
  echo -e "${BLUE}Mounting NAS share...${NC}"
  local target="$NAS_MOUNT_DIR"
  sudo mkdir -p "$target"
  # If mounted, verify it belongs to our NAS; if so, refresh
  local current_mount
  if mount | grep -q " $target "; then
    current_mount=$(mount | grep " $target " | grep "$NAS_IP" || true)
    if [ -n "$current_mount" ]; then
      sudo umount -f "$target" || {
        echo -e "${RED}[ERROR] Unable to unmount existing NAS mount at $target${NC}"; exit 1; }
    else
      echo -e "${RED}[ERROR] Mount point $target in use by another mount${NC}"; exit 1
    fi
  fi
  sudo chmod 755 "$target"
  # Try SMB 3.0 then fallback
  if ! sudo mount -t cifs -o username="$NAS_USERNAME",password="$NAS_PASSWORD",vers=3.0,iocharset=utf8,file_mode=0777,dir_mode=0777 "//${NAS_IP}/${NAS_SHARE_NAME}" "$target"; then
    echo -e "${YELLOW}[WARN] SMB 3.0 failed; retrying without explicit version${NC}"
    sudo mount -t cifs -o username="$NAS_USERNAME",password="$NAS_PASSWORD",iocharset=utf8,file_mode=0777,dir_mode=0777 "//${NAS_IP}/${NAS_SHARE_NAME}" "$target"
  fi
  if ! mountpoint -q "$target"; then
    echo -e "${RED}[ERROR] NAS share not mounted at $target${NC}"; exit 1
  fi
  echo -e "${GREEN}[OK] NAS mounted at $target${NC}"
}

setup_dirs() {
  echo -e "${BLUE}Preparing directories...${NC}"
  sudo mkdir -p "$DOCKER_COMPOSE_DIR" "$HA_DATA_DIR" "$PORTAINER_DATA_DIR"
  sudo chown -R "${DOCKER_USER_ID}:${DOCKER_GROUP_ID}" "$DOCKER_COMPOSE_DIR" "$HA_DATA_DIR" "$PORTAINER_DATA_DIR"
  sudo chmod -R 775 "$DOCKER_COMPOSE_DIR" "$HA_DATA_DIR" "$PORTAINER_DATA_DIR"
}

write_portainer_secret() {
  echo -e "${BLUE}Writing Portainer admin password file...${NC}"
  local pw_file="${DOCKER_COMPOSE_DIR}/portainer_password.txt"
  echo -n "$PORTAINER_PASS" | sudo tee "$pw_file" >/dev/null
  sudo chmod 600 "$pw_file"
  sudo chown "${DOCKER_USER_ID}:${DOCKER_GROUP_ID}" "$pw_file"
}

copy_compose_and_env() {
  echo -e "${BLUE}Preparing compose and .env for BASE_DIR...${NC}"
  if [ ! -f docker-compose.yml ]; then
    echo -e "${YELLOW}[WARN] docker-compose.yml not found locally; downloading from repository...${NC}"
    if ! curl -fsSL "${COMPOSE_SOURCE_URL}" -o docker-compose.yml; then
      echo -e "${RED}[ERROR] Unable to download docker-compose.yml from ${COMPOSE_SOURCE_URL}${NC}"
      exit 1
    fi
  fi
  cp docker-compose.yml "${BASE_DIR}/docker-compose.yml"
  cp .env "${BASE_DIR}/.env"
}

require_mariadb_vars() {
  local required=(MARIADB_HOST MARIADB_PORT MARIADB_DATABASE MARIADB_USER MARIADB_PASSWORD)
  local missing=()
  for v in "${required[@]}"; do
    if [ -z "${!v}" ]; then
      missing+=("$v")
    fi
  done
  if [ ${#missing[@]} -gt 0 ]; then
    echo -e "${YELLOW}[WARN] MariaDB check requested but missing variables:${NC} ${missing[*]}"
    echo -e "${YELLOW}[WARN] Skipping MariaDB validation. Update .env to include these values to enable the check.${NC}"
    MARIADB_STATUS="missing_vars"
    return 1
  fi
  return 0
}

print_mariadb_bootstrap_hint() {
  local bootstrap_url="https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/nas/setup-nas-mariadb.sh"
  local host_hint="${MARIADB_HOST:-${NAS_IP:-<NAS_HOST>}}"
  echo -e "${BLUE}[INFO] To bootstrap MariaDB on the NAS run:${NC}"
  echo -e "${BLUE}  ssh <nas-user>@${host_hint} 'curl -fsSL ${bootstrap_url} | bash'${NC}"
  echo -e "${BLUE}  # Alternatively execute nas/setup-nas-mariadb.sh from this repository with your .env${NC}"
}

check_mariadb() {
  local host="$MARIADB_HOST"
  local port="${MARIADB_PORT:-3306}"
  echo -e "${BLUE}Validating MariaDB availability at ${host}:${port}...${NC}"

  if ! nc -z -w5 "$host" "$port" >/dev/null 2>&1; then
    echo -e "${YELLOW}[WARN] Unable to reach MariaDB at ${host}:${port}. Ensure the NAS container is running and firewall allows access.${NC}"
    MARIADB_STATUS="unreachable"
    return 1
  fi
  echo -e "${GREEN}[OK] MariaDB port reachable${NC}"

  if command -v mysql >/dev/null 2>&1; then
    if MYSQL_PWD="$MARIADB_PASSWORD" mysql --protocol=TCP -h "$host" -P "$port" -u "$MARIADB_USER" "$MARIADB_DATABASE" -e "SELECT 1" >/dev/null 2>&1; then
      echo -e "${GREEN}[OK] MariaDB credentials verified${NC}"
      MARIADB_STATUS="available"
      return 0
    else
      echo -e "${YELLOW}[WARN] MariaDB responded but credentials/database check failed. Review user, password and database name.${NC}"
      MARIADB_STATUS="auth_failed"
      return 1
    fi
  else
    echo -e "${YELLOW}[WARN] mysql client not available; credential check skipped. Port reachability verified.${NC}"
    MARIADB_STATUS="reachable_no_mysql"
    return 0
  fi
}

print_mariadb_followup() {
  case "$MARIADB_STATUS" in
    available)
      echo -e "${GREEN}[OK] MariaDB is ready. Configure Home Assistant recorder using the credentials above (see nas/README.md).${NC}"
      ;;
    reachable_no_mysql)
      echo -e "${YELLOW}[WARN] MariaDB port reachable but credential check skipped (mysql client missing). Install 'mariadb-client' or run manual tests if needed.${NC}"
      ;;
    not_requested)
      echo -e "${BLUE}[INFO] MariaDB validation not requested. Enable it by setting ENABLE_MARIADB_CHECK=true if you plan to use the NAS MariaDB recorder.${NC}"
      echo -e "${BLUE}Refer to nas/README.md when ready.${NC}"
      ;;
    auth_failed)
      echo -e "${YELLOW}[WARN] MariaDB authentication failed. Confirm credentials in .env and in the NAS deployment (nas/docker-compose.yml).${NC}"
      ;;
    unreachable)
      echo -e "${YELLOW}[WARN] MariaDB appears offline. Start it on the NAS using nas/docker-compose.yml or run 'docker compose up -d' on the NAS.${NC}"
      print_mariadb_bootstrap_hint
      ;;
    skipped)
      echo -e "${YELLOW}[WARN] MariaDB validation skipped. Set ENABLE_MARIADB_CHECK=true and provide MARIADB_* variables in .env to enable automated checks.${NC}"
      echo -e "${BLUE}Refer to nas/README.md for setup instructions.${NC}"
      print_mariadb_bootstrap_hint
      ;;
    missing_vars)
      echo -e "${YELLOW}[WARN] MariaDB check requested but configuration is incomplete. Add all MARIADB_* variables to .env and rerun.${NC}"
      echo -e "${BLUE}See nas/README.md for the required values.${NC}"
      print_mariadb_bootstrap_hint
      ;;
  esac
}

start_stack() {
  local dc
  dc=$(docker_compose_cmd)
  if [ -z "$dc" ]; then
    echo -e "${RED}[ERROR] Neither 'docker compose' nor 'docker-compose' is available${NC}"; exit 1
  fi
  echo -e "${BLUE}Starting containers with: $dc${NC}"
  sudo -E $dc -f "${BASE_DIR}/docker-compose.yml" up -d
}

verify_running() {
  echo -e "${BLUE}Verifying containers...${NC}"
  sleep 3
  if ! docker ps | grep -q homeassistant; then
    echo -e "${RED}[ERROR] homeassistant not running${NC}"; exit 1
  fi
  if ! docker ps | grep -q portainer; then
    echo -e "${RED}[ERROR] portainer not running${NC}"; exit 1
  fi
  echo -e "${GREEN}[OK] Containers running${NC}"
}

# Main
load_env
post_load_fallbacks
require_vars \
  BASE_DIR DOCKER_USER_ID DOCKER_GROUP_ID HOST_ID \
  HA_PORT \
  NAS_IP NAS_SHARE_NAME NAS_USERNAME NAS_PASSWORD NAS_MOUNT_DIR \
  PORTAINER_PASS

ensure_packages
ensure_docker

echo -e "${BLUE}Checking NAS connectivity...${NC}"
if ! ping -c 2 "$NAS_IP" >/dev/null 2>&1; then
  echo -e "${RED}[ERROR] Cannot reach NAS at $NAS_IP${NC}"; exit 1
fi

MARIADB_STATUS="not_requested"
if bool_true "${ENABLE_MARIADB_CHECK:-false}"; then
  MARIADB_STATUS="skipped"
  [ -z "$MARIADB_HOST" ] && MARIADB_HOST="$NAS_IP"
  [ -z "$MARIADB_PORT" ] && MARIADB_PORT=3306
  if require_mariadb_vars; then
    check_mariadb || true
  fi
fi

mount_nas
## Derive NAS-based defaults if not provided (group by host)
if [ -z "$DOCKER_COMPOSE_DIR" ]; then
  DOCKER_COMPOSE_DIR="${NAS_MOUNT_DIR}/hosts/${HOST_ID}/compose"
fi
if [ -z "$HA_DATA_DIR" ]; then
  HA_DATA_DIR="${NAS_MOUNT_DIR}/hosts/${HOST_ID}/home-assistant"
fi
if [ -z "$PORTAINER_DATA_DIR" ]; then
  PORTAINER_DATA_DIR="${NAS_MOUNT_DIR}/hosts/${HOST_ID}/portainer"
fi

setup_dirs
write_portainer_secret
copy_compose_and_env

echo -e "${BLUE}Launching stack...${NC}"
start_stack
verify_running

# Determine IP if not provided or set to auto
if [ -z "$IP" ] || [ "$IP" = "auto" ]; then
  IP=$(hostname -I | awk '{print $1}')
fi

echo -e "\n${GREEN}Setup complete${NC}"
echo -e "${BLUE}- Home Assistant: http://$IP:${HA_PORT:-8123}${NC}"
echo -e "${BLUE}- Portainer: http://$IP:${PORTAINER_PORT:-9000}${NC}"
echo -e "${BLUE}- NAS mount: ${NAS_MOUNT_DIR}${NC}"
print_mariadb_followup


