#!/bin/bash
set -e

VERSION="1.0.1"

BLUE='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
  cat <<'EOF'
PiHA-Deployer Home Assistant Uninstaller v1.0.0

Usage: sudo bash uninstall-home-assistant.sh [options]

Options:
  -f, --force        Do not prompt, proceed with removal
  --skip-nas-ssh     Do not connect to NAS via SSH to clean MariaDB deployment
  -h, --help         Print this message

The script stops the Home Assistant stack on this Pi, removes NAS-backed
directories for Home Assistant/Portainer, and (unless skipped) removes the
MariaDB deployment directory on the NAS via SSH.
EOF
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
  _load_env_file "../common/Common.env"
  _load_env_file "../common/common.env"
  _load_env_file "common/Common.env"
  _load_env_file "common/common.env"
  _load_env_file "$HOME/.piha/common.env"
  _load_env_file "/etc/piha/common.env"
  _load_env_file "./Common.env"
  _load_env_file "./common.env"
  if [ ! -f .env ]; then
    echo -e "${RED}[ERROR] .env file not found in current directory${NC}"
    exit 1
  fi
  chmod 600 .env || true
  _load_env_file .env
  echo -e "${GREEN}[OK] Environment loaded${NC}"
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
  if mountpoint -q "$NAS_MOUNT_DIR"; then
    return
  fi
  echo -e "${BLUE}Mounting NAS share at ${NAS_MOUNT_DIR}...${NC}"
  sudo mkdir -p "$NAS_MOUNT_DIR"
  local uid_opt gid_opt
  uid_opt="uid=${DOCKER_USER_ID:-$(id -u)}"
  gid_opt="gid=${DOCKER_GROUP_ID:-$(id -g)}"
  local options="username=${NAS_USERNAME},password=${NAS_PASSWORD},${uid_opt},${gid_opt},file_mode=0775,dir_mode=0775,nounix"
  if [ -n "${CIFS_VERSION:-}" ]; then
    options="${options},vers=${CIFS_VERSION}"
  fi
  sudo mount -t cifs "//${NAS_IP}/${NAS_SHARE_NAME}" "$NAS_MOUNT_DIR" -o "$options"
}

delete_path() {
  local target="$1"
  local label="$2"
  if [ -z "$target" ]; then
    return
  fi
  if [ ! -e "$target" ]; then
    echo -e "${YELLOW}[WARN] ${label} not found (${target})${NC}"
    return
  fi
  sudo rm -rf "$target"
  echo -e "${GREEN}[OK] Removed ${label}${NC}"
}

run_remote_cleanup() {
  local host="${NAS_SSH_HOST:-}"
  local user="${NAS_SSH_USER:-}"
  local port="${NAS_SSH_PORT:-22}"
  local deploy_dir="${NAS_DEPLOY_DIR:-}"
  local sudo_prefix=""

  if bool_true "${NAS_SSH_USE_SUDO:-false}"; then
    sudo_prefix="sudo "
  fi

  if [[ -z "$host" || "$host" =~ ^(localhost|127\.0\.0\.1|::1)$ ]]; then
    if [ -n "${NAS_IP:-}" ]; then
      host="$NAS_IP"
      echo -e "${YELLOW}[WARN] NAS_SSH_HOST points to localhost; using NAS_IP=${NAS_IP}.${NC}"
    fi
  fi

  if [ -z "$host" ] || [ -z "$user" ] || [ -z "$deploy_dir" ]; then
    echo -e "${YELLOW}[WARN] NAS SSH cleanup skipped (missing NAS_SSH_* or NAS_IP vars).${NC}"
    return
  fi

  echo -e "${BLUE}Cleaning MariaDB deployment on NAS via SSH (${user}@${host})...${NC}"
  ssh -p "$port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${user}@${host}" <<EOF
set -e
if [ -d "$deploy_dir" ]; then
  if [ -f "$deploy_dir/docker-compose.yml" ]; then
    ${sudo_prefix}docker compose -f "$deploy_dir/docker-compose.yml" down --remove-orphans || true
  fi
  ${sudo_prefix}rm -rf "$deploy_dir"
fi
EOF
  echo -e "${GREEN}[OK] NAS MariaDB deployment directory removed${NC}"
}

confirm_or_exit() {
  local force_flag="$1"
  if bool_true "$force_flag"; then
    return
  fi
  if [ ! -t 0 ]; then
    echo -e "${RED}[ERROR] No TTY available for confirmation. Re-run with --force to proceed.${NC}"
    exit 1
  fi
  echo -ne "${YELLOW}This will stop Home Assistant/Portainer on this Pi and delete NAS data directories. Continue? [y/N]: ${NC}" > /dev/tty
  local reply
  if read -r reply < /dev/tty && bool_true "$reply"; then
    return
  fi
  echo -e "${YELLOW}[WARN] Aborted by user.${NC}"
  exit 1
}

FORCE=false
SKIP_NAS_SSH=false

while [ $# -gt 0 ]; do
  case "$1" in
    -f|--force)
      FORCE=true
      shift
      ;;
    --skip-nas-ssh)
      SKIP_NAS_SSH=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo -e "${RED}[ERROR] Unknown option: $1${NC}"
      usage
      exit 1
      ;;
  esac
done

echo -e "${BLUE}PiHA-Deployer Home Assistant Uninstaller v${VERSION}${NC}"

load_env
require_vars \
  NAS_IP NAS_SHARE_NAME NAS_USERNAME NAS_PASSWORD NAS_MOUNT_DIR \
  HOST_ID DOCKER_USER_ID DOCKER_GROUP_ID

if [ -z "$BASE_DIR" ]; then
  BASE_DIR="${NAS_MOUNT_DIR}/hosts/${HOST_ID}/compose"
fi
if [ -z "$DOCKER_COMPOSE_DIR" ]; then
  DOCKER_COMPOSE_DIR="${NAS_MOUNT_DIR}/hosts/${HOST_ID}/compose"
fi
if [ -z "$HA_DATA_DIR" ]; then
  HA_DATA_DIR="${NAS_MOUNT_DIR}/hosts/${HOST_ID}/home-assistant"
fi
if [ -z "$PORTAINER_DATA_DIR" ]; then
  PORTAINER_DATA_DIR="${NAS_MOUNT_DIR}/hosts/${HOST_ID}/portainer"
fi

confirm_or_exit "$FORCE"

mount_nas

compose_cmd=$(docker_compose_cmd)
if [ -n "$compose_cmd" ] && [ -f "${DOCKER_COMPOSE_DIR}/docker-compose.yml" ]; then
  echo -e "${BLUE}Stopping Home Assistant stack...${NC}"
  sudo -E $compose_cmd -f "${DOCKER_COMPOSE_DIR}/docker-compose.yml" down --remove-orphans || true
else
  echo -e "${YELLOW}[WARN] docker-compose.yml not found in ${DOCKER_COMPOSE_DIR}; skipping stack shutdown.${NC}"
fi

if docker ps -a | grep -q homeassistant; then
  echo -e "${BLUE}Removing residual containers...${NC}"
  sudo docker rm -f homeassistant || true
fi
if docker ps -a | grep -q portainer; then
  sudo docker rm -f portainer || true
fi

TARGETS=()
TARGETS+=("${HA_DATA_DIR}:::Home Assistant data directory")
TARGETS+=("${PORTAINER_DATA_DIR}:::Portainer data directory")
TARGETS+=("${DOCKER_COMPOSE_DIR}:::Compose directory")

for entry in "${TARGETS[@]}"; do
  path="${entry%%:::*}"
  label="${entry##*:::}"
  delete_path "$path" "$label"
done

if [ -d "$NAS_MOUNT_DIR" ]; then
  echo -e "${BLUE}Ensuring NAS mount point ownership...${NC}"
  sudo chown "${DOCKER_USER_ID}:${DOCKER_GROUP_ID}" "$NAS_MOUNT_DIR" || true
fi

if ! bool_true "$SKIP_NAS_SSH"; then
  run_remote_cleanup
else
  echo -e "${YELLOW}[WARN] Skipping NAS SSH cleanup as requested.${NC}"
fi

echo -e "${BLUE}Cleanup complete. You may now remove the working directory (e.g. rm -rf $(pwd)) if desired.${NC}"