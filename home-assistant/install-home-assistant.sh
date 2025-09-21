#!/bin/bash
set -e

# Version
VERSION="1.1.10"

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
  local raw="$1"
  raw="$(printf '%s' "$raw" | sed $'s/\xC2\xA0/ /g; s/\r//g')"
  raw="${raw%%#*}"
  raw="$(echo "$raw" | awk '{print $1}' 2>/dev/null)"
  raw="${raw,,}"
  case "$raw" in
    1|y|yes|true|on) return 0 ;;
    *) return 1 ;;
  esac
}
dir_has_content() {
  local dir="$1"
  [ -d "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ]
}

check_existing_data() {
  local reuse_flag=${HA_ALLOW_EXISTING_DATA:-false}
  local reuse=false
  if bool_true "$reuse_flag"; then
    reuse=true
  fi

  if [ "$reuse" != true ] && [ -f .env ]; then
    local raw_line raw_value
    raw_line=$(grep -E '^[[:space:]]*HA_ALLOW_EXISTING_DATA[[:space:]]*=' .env | tail -n 1 || true)
    if [ -n "$raw_line" ]; then
      raw_line=$(printf '%s' "$raw_line" | sed $'s/\xEF\xBB\xBF//g; s/\xC2\xA0/ /g' | tr -d '\r')
      raw_value=${raw_line#*=}
      raw_value=$(echo "$raw_value" | xargs)
      if bool_true "$raw_value"; then
        reuse=true
      fi
    fi
  fi

  local existing_dirs=()
  if dir_has_content "$HA_DATA_DIR"; then existing_dirs+=("$HA_DATA_DIR"); fi
  if dir_has_content "$BASE_DIR"; then existing_dirs+=("$BASE_DIR"); fi
  if dir_has_content "$PORTAINER_DATA_DIR"; then existing_dirs+=("$PORTAINER_DATA_DIR"); fi

  if [ ${#existing_dirs[@]} -eq 0 ]; then
    return
  fi

  if [ "$reuse" = true ]; then
    echo -e "${YELLOW}[WARN] Existing Home Assistant data detected; proceeding because HA_ALLOW_EXISTING_DATA=true.${NC}"
    for dir in "${existing_dirs[@]}"; do
      echo -e "${YELLOW}  - Reusing ${dir}${NC}"
    done
    return
  fi

  echo -e "${RED}[ERROR] Existing Home Assistant data detected in the NAS directories shown below.${NC}"
  for dir in "${existing_dirs[@]}"; do
    echo -e "${YELLOW}  - ${dir}${NC}"
  done

  if [ -t 0 ]; then
    echo -ne "${YELLOW}Continue and reuse these directories? [y/N]: ${NC}" > /dev/tty
    local reply
    if read -r reply < /dev/tty; then
      if bool_true "$reply"; then
        echo -e "${YELLOW}[WARN] Reusing existing Home Assistant data directories.${NC}"
        for dir in "${existing_dirs[@]}"; do
          echo -e "${YELLOW}  - Reusing ${dir}${NC}"
        done
        return
      fi
    fi
    echo -e "${YELLOW}[WARN] Remove the directories above for a clean install, or set HA_ALLOW_EXISTING_DATA=true in .env if you intend to reuse them.${NC}"
    exit 1
  fi

  echo -e "${YELLOW}[WARN] Remove the directories above for a clean install, or set HA_ALLOW_EXISTING_DATA=true in .env if you intend to reuse them.${NC}"
  exit 1
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
    echo -e "${YELLOW}[HINT] Recreate your shared env file (common/common.env or ../common/common.env) alongside .env, or move those values into .env before rerunning.${NC}"
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

MARIADB_CONFIGURE_PENDING=false
MARIADB_HINT_PRINTED=false

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

configure_home_assistant_mariadb() {
  echo -e "${BLUE}Configuring Home Assistant recorder for MariaDB...${NC}"
  local secrets_file="${HA_DATA_DIR}/secrets.yaml"
  local config_file="${HA_DATA_DIR}/configuration.yaml"
  local purge_days="${RECORDER_PURGE_KEEP_DAYS:-14}"
  local dsn="mysql+pymysql://${MARIADB_USER}:${MARIADB_PASSWORD}@${MARIADB_HOST}:${MARIADB_PORT}/${MARIADB_DATABASE}?charset=utf8mb4"

  sudo mkdir -p "${HA_DATA_DIR}"

  # Manage secrets.yaml
  sudo touch "$secrets_file"
  if sudo grep -q '^recorder_db_url:' "$secrets_file"; then
    sudo sed -i "s#^recorder_db_url:.*#recorder_db_url: ${dsn}#" "$secrets_file"
  else
    echo "recorder_db_url: ${dsn}" | sudo tee -a "$secrets_file" >/dev/null
  fi

  # Manage configuration.yaml
  sudo touch "$config_file"
  sudo sed -i '/# --- PiHA-Deployer recorder config (managed) ---/,/# --- PiHA-Deployer recorder config ---/d' "$config_file"
  if sudo grep -q '^[[:space:]]*recorder:' "$config_file"; then
    echo -e "${YELLOW}[WARN] Existing recorder configuration detected in ${config_file}. Update it manually to use !secret recorder_db_url.${NC}"
    MARIADB_STATUS="available"
    return 0
  fi
  echo '' | sudo tee -a "$config_file" >/dev/null
  sudo tee -a "$config_file" >/dev/null <<EOF
# --- PiHA-Deployer recorder config (managed) ---
recorder:
  db_url: !secret recorder_db_url
  purge_keep_days: ${purge_days}
  commit_interval: 30
# --- PiHA-Deployer recorder config ---
EOF

  sudo chown "${DOCKER_USER_ID}:${DOCKER_GROUP_ID}" "$secrets_file" "$config_file" 2>/dev/null || true
  sudo chmod 600 "$secrets_file" 2>/dev/null || true
  sudo chmod 664 "$config_file" 2>/dev/null || true
  MARIADB_STATUS="configured"
  echo -e "${GREEN}[OK] Recorder configured to use MariaDB${NC}"
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
  local host_hint="${MARIADB_HOST:-${NAS_IP:-<NAS_HOST>}}"
  echo -e "${BLUE}[INFO] MariaDB was not detected on the NAS.${NC}"
  echo -e "${BLUE}[INFO] Manual bootstrap (recommended for fresh installs):${NC}"
  echo -e "${BLUE}  1) ssh <nas-user>@${host_hint}${NC}"
  echo -e "${BLUE}  2) mkdir -p /share/Container/compose/mariadb && cd /share/Container/compose/mariadb${NC}"
  echo -e "${BLUE}  3) Place .env in that directory (see home-assistant/mariadb/README.md for required keys).${NC}"
  echo -e "${BLUE}  4) Run: curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/mariadb/setup-nas-mariadb.sh -o setup-nas-mariadb.sh && bash setup-nas-mariadb.sh${NC}"
  echo -e "${BLUE}  5) From the Pi, verify connectivity with: nc -vz ${host_hint} 3306${NC}"
  echo -e "${BLUE}[INFO] Optional automation: if you already have home-assistant/mariadb/.env in your PiHA-Deployer clone, run 'bash home-assistant/mariadb/setup-nas-mariadb.sh' there to perform the same steps over SSH.${NC}"
  echo
}

check_mariadb() {
  local host="$MARIADB_HOST"
  local port="${MARIADB_PORT:-3306}"
  echo -e "${BLUE}Validating MariaDB availability at ${host}:${port}...${NC}"

  if ! nc -z -w5 "$host" "$port" >/dev/null 2>&1; then
    echo -e "${YELLOW}[WARN] Unable to reach MariaDB at ${host}:${port}. Ensure the NAS container is running and firewall allows access.${NC}"
    print_mariadb_bootstrap_hint
    MARIADB_HINT_PRINTED="true"
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
    configured)
      echo -e "${GREEN}[OK] MariaDB recorder configured automatically. Review ${HA_DATA_DIR}/configuration.yaml if you need further tweaks.${NC}"
      ;;
    available)
      echo -e "${GREEN}[OK] MariaDB is ready. Configure Home Assistant recorder using the credentials above (see home-assistant/mariadb/README.md).${NC}"
      ;;
    reachable_no_mysql)
      echo -e "${YELLOW}[WARN] MariaDB port reachable but credential check skipped (mysql client missing). Install 'mariadb-client' or run manual tests if needed.${NC}"
      ;;
    not_requested)
      echo -e "${BLUE}[INFO] MariaDB validation not requested. Enable it by setting ENABLE_MARIADB_CHECK=true if you plan to use the NAS MariaDB recorder.${NC}"
      echo -e "${BLUE}Refer to home-assistant/mariadb/README.md when ready.${NC}"
      ;;
    auth_failed)
      echo -e "${YELLOW}[WARN] MariaDB authentication failed. Confirm credentials in .env and in the NAS deployment (home-assistant/mariadb/docker-compose.yml).${NC}"
      ;;
    unreachable)
      echo -e "${YELLOW}[WARN] MariaDB appears offline. Start it on the NAS using home-assistant/mariadb/docker-compose.yml or run 'docker compose up -d' on the NAS.${NC}"
      print_mariadb_bootstrap_hint
      ;;
    skipped)
      echo -e "${YELLOW}[WARN] MariaDB validation skipped. Set ENABLE_MARIADB_CHECK=true and provide MARIADB_* variables in .env to enable automated checks.${NC}"
      echo -e "${BLUE}Refer to home-assistant/mariadb/README.md for setup instructions.${NC}"
      print_mariadb_bootstrap_hint
      ;;
    missing_vars)
      echo -e "${YELLOW}[WARN] MariaDB check requested but configuration is incomplete. Add all MARIADB_* variables to .env and rerun.${NC}"
      echo -e "${BLUE}See home-assistant/mariadb/README.md for the required values.${NC}"
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
MARIADB_CONFIGURE_PENDING="false"
if bool_true "${ENABLE_MARIADB_CHECK:-false}"; then
  MARIADB_STATUS="skipped"
  [ -z "$MARIADB_HOST" ] && MARIADB_HOST="$NAS_IP"
  [ -z "$MARIADB_PORT" ] && MARIADB_PORT=3306
  if require_mariadb_vars; then
    check_mariadb
    if [ "$MARIADB_STATUS" = "available" ]; then
      MARIADB_CONFIGURE_PENDING="true"
    else
      if [ "$MARIADB_HINT_PRINTED" != "true" ]; then
        print_mariadb_followup
      fi
      echo -e "${RED}[ERROR] MariaDB validation failed; aborting installation.${NC}"
      exit 1
    fi
  else
    print_mariadb_followup
    echo -e "${RED}[ERROR] MariaDB validation failed due to missing variables; aborting installation.${NC}"
    exit 1
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

check_existing_data
setup_dirs
if [ "$MARIADB_CONFIGURE_PENDING" = "true" ]; then
  configure_home_assistant_mariadb
fi
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


