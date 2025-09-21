#!/bin/bash
set -e

VERSION="1.0.7"

WORK_DIR=$(pwd)

BLUE='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
  cat <<EOF
PiHA-Deployer Home Assistant Uninstaller v${VERSION}

Usage: sudo bash uninstall-home-assistant.sh [options]

Options:
  -f, --force        Do not prompt, proceed with removal
  --skip-nas-ssh     Do not connect to NAS via SSH to clean MariaDB deployment
  --purge-local      Remove this working directory after cleanup
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
  local remote_base_path=/share/ZFS530_DATA/.qpkg/container-station/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
  local container_name="${MARIADB_CONTAINER_NAME:-mariadb}"

  if bool_true "${NAS_SSH_USE_SUDO:-false}"; then
    sudo_prefix="sudo "
  fi

  if [[ -z "$host" || "$host" =~ ^(localhost|127\.0\.0\.1|::1)$ ]]; then
    if [ -n "${MARIADB_HOST:-}" ] && [[ ! "${MARIADB_HOST,,}" =~ ^(localhost|127\.0\.0\.1|::1)$ ]]; then
      host="$MARIADB_HOST"
      echo -e "${YELLOW}[WARN] NAS_SSH_HOST=localhost; using MARIADB_HOST=${MARIADB_HOST} for cleanup.${NC}"
    elif [ -n "${NAS_IP:-}" ] && [[ ! "${NAS_IP,,}" =~ ^(localhost|127\.0\.0\.1|::1)$ ]]; then
      host="$NAS_IP"
      echo -e "${YELLOW}[WARN] NAS_SSH_HOST=localhost; using NAS_IP=${NAS_IP} for cleanup.${NC}"
    fi
  fi

  if [[ -z "$host" || "$host" =~ ^(localhost|127\.0\.0\.1|::1)$ ]] || [ -z "$user" ]; then
    echo -e "${BLUE}Cleaning MariaDB deployment locally on this NAS...${NC}"
    PATH="${remote_base_path}:$PATH"
    local docker_path
    docker_path=$(command -v docker 2>/dev/null || true)
    if [ -z "$docker_path" ]; then
      for candidate in /share/ZFS530_DATA/.qpkg/container-station/bin/docker /usr/local/bin/docker /usr/bin/docker /bin/docker /usr/local/sbin/docker /sbin/docker; do
        if [ -x "$candidate" ]; then
          docker_path="$candidate"
          break
        fi
      done
    fi
    if [ -z "$docker_path" ]; then
      echo -e "${RED}[ERROR] docker command not found on NAS; aborting cleanup.${NC}"
      exit 1
    fi
    local compose_cmd=""
    if $docker_path compose version >/dev/null 2>&1; then
      compose_cmd="$docker_path compose"
    elif command -v docker-compose >/dev/null 2>&1; then
      compose_cmd="$(command -v docker-compose)"
    fi
    if [ -n "$deploy_dir" ] && [ -d "$deploy_dir" ]; then
      if [ -n "$compose_cmd" ] && [ -f "$deploy_dir/docker-compose.yml" ]; then
        echo "[remote] running $compose_cmd down"
        ${sudo_prefix}${compose_cmd} -f "$deploy_dir/docker-compose.yml" down --remove-orphans || true
      fi
      echo "[remote] removing $deploy_dir"
      ${sudo_prefix}rm -rf "$deploy_dir"
    fi
    local containers
    containers=$(${sudo_prefix}$docker_path ps -aq --filter name=^${container_name}$ || true)
    if [ -n "$containers" ]; then
      echo "[remote] removing containers: $containers"
      ${sudo_prefix}$docker_path rm -f $containers || true
    fi
    containers=$(${sudo_prefix}$docker_path ps -aq --filter name=^${container_name}$ || true)
    if [ -n "$containers" ]; then
      echo -e "${RED}[ERROR] MariaDB container(s) still present on NAS: $containers. Remove manually (ssh ${user}@${host} \"docker rm -f $containers\") and rerun if needed.${NC}"
      exit 1
    fi
    echo -e "${GREEN}[OK] Local NAS MariaDB deployment removed${NC}"
    return
  fi

  if [ -z "$deploy_dir" ]; then
    echo -e "${YELLOW}[WARN] NAS SSH cleanup skipped (NAS_DEPLOY_DIR not provided).${NC}"
    return
  fi

  local remote_env
  printf -v remote_env "DEPLOY_DIR=%q REMOTE_SUDO=%q MARIADB_NAME=%q" "$deploy_dir" "$sudo_prefix" "$container_name"
  local remote_cmd
  remote_cmd="PATH=${remote_base_path} ${remote_env} bash -s"

  if ! ssh -p "$port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${user}@${host}" "$remote_cmd" <<'EOF'
set -e
if [ -n "$REMOTE_SUDO" ]; then
  DOCKER=$($REMOTE_SUDO command -v docker 2>/dev/null || true)
else
  DOCKER=$(command -v docker 2>/dev/null || true)
fi
if [ -z "$DOCKER" ]; then
  for candidate in /share/ZFS530_DATA/.qpkg/container-station/bin/docker /usr/local/bin/docker /usr/bin/docker /bin/docker /usr/local/sbin/docker /sbin/docker; do
    if [ -x "$candidate" ]; then
      DOCKER="$candidate"
      break
    fi
  done
fi
if [ -z "$DOCKER" ]; then
  echo "[remote][ERROR] docker command not found." >&2
  exit 90
fi
COMPOSE=""
if $DOCKER compose version >/dev/null 2>&1; then
  COMPOSE="$DOCKER compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="$(command -v docker-compose)"
fi
if [ -n "$DEPLOY_DIR" ] && [ -d "$DEPLOY_DIR" ]; then
  if [ -n "$COMPOSE" ] && [ -f "$DEPLOY_DIR/docker-compose.yml" ]; then
    echo "[remote] running $COMPOSE down"
    if [ -n "$REMOTE_SUDO" ]; then
      $REMOTE_SUDO $COMPOSE -f "$DEPLOY_DIR/docker-compose.yml" down --remove-orphans || true
    else
      $COMPOSE -f "$DEPLOY_DIR/docker-compose.yml" down --remove-orphans || true
    fi
  fi
  echo "[remote] removing $DEPLOY_DIR"
  if [ -n "$REMOTE_SUDO" ]; then
    $REMOTE_SUDO rm -rf "$DEPLOY_DIR"
  else
    rm -rf "$DEPLOY_DIR"
  fi
fi
if [ -n "$REMOTE_SUDO" ]; then
  CONTAINERS=$($REMOTE_SUDO $DOCKER ps -aq --filter name=^${MARIADB_NAME:-mariadb}$ || true)
else
  CONTAINERS=$($DOCKER ps -aq --filter name=^${MARIADB_NAME:-mariadb}$ || true)
fi
if [ -n "$CONTAINERS" ]; then
  echo "[remote] removing containers: $CONTAINERS"
  if [ -n "$REMOTE_SUDO" ]; then
    $REMOTE_SUDO $DOCKER rm -f $CONTAINERS || true
  else
    $DOCKER rm -f $CONTAINERS || true
  fi
fi
if [ -n "$REMOTE_SUDO" ]; then
  CONTAINERS=$($REMOTE_SUDO $DOCKER ps -aq --filter name=^${MARIADB_NAME:-mariadb}$ || true)
else
  CONTAINERS=$($DOCKER ps -aq --filter name=^${MARIADB_NAME:-mariadb}$ || true)
fi
if [ -n "$CONTAINERS" ]; then
  echo "[remote][ERROR] MariaDB container(s) still running: $CONTAINERS" >&2
  exit 91
fi
EOF
  then
    local rc=$?
    case $rc in
      90)
        echo -e "${RED}[ERROR] docker command not found on NAS PATH during SSH cleanup.${NC}"
        exit 1
        ;;
      91)
        echo -e "${RED}[ERROR] MariaDB container(s) still running on NAS after cleanup. Run on the NAS: ssh ${user}@${host} \"docker rm -f $(docker ps -aq --filter name=^${container_name}$)\" and rerun if needed.${NC}"
        exit 1
        ;;
      *)
        echo -e "${RED}[ERROR] SSH cleanup failed for NAS (exit $rc).${NC}"
        exit 1
        ;;
    esac
  fi
  echo -e "${GREEN}[OK] NAS MariaDB deployment directory removed${NC}"
}

purge_working_dir() {
  if ! bool_true "$PURGE_LOCAL"; then
    return
  fi
  local dir="$WORK_DIR"
  if [ -z "$dir" ] || [ "$dir" = "/" ]; then
    echo -e "${RED}[ERROR] Refusing to remove working directory: invalid path (${dir:-empty}).${NC}"
    return
  fi
  echo -e "${BLUE}Removing local working directory ${dir}...${NC}"
  cd /
  sudo rm -rf "$dir" || true
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
PURGE_LOCAL=false
if bool_true "${UNINSTALL_PURGE_LOCAL:-false}"; then
  PURGE_LOCAL=true
fi

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
    --purge-local)
      PURGE_LOCAL=true
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

purge_working_dir
echo -e "${BLUE}Cleanup complete. You may now remove the working directory (e.g. rm -rf $(pwd)) if desired.${NC}"