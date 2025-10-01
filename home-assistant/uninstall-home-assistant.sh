#!/bin/bash
set -e

VERSION="1.2.0"

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
  --purge-images     Remove Home Assistant/Portainer Docker images from this Pi
  --keep-env        Retain .env in working directory after cleanup
  -h, --help         Print this message

The script stops the Home Assistant stack on this Pi, removes NAS-backed
directories for Home Assistant/Portainer, and (unless skipped) removes the
MariaDB deployment directory on the NAS via SSH.
Interactive runs ask whether to purge the working directory and project images when no flags are provided; automation can set CLI flags or env vars to skip the prompts.
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

purge_sqlite_recorder() {
  local dir="${SQLITE_DATA_DIR:-/var/lib/piha/home-assistant/sqlite}"
  local base="${SQLITE_DB_FILENAME:-home-assistant_v2.db}"
  local removed=false

  for suffix in "" "-shm" "-wal"; do
    local file="${dir}/${base}${suffix}"
    if [ -f "$file" ]; then
      sudo rm -f "$file" || true
      removed=true
    fi
  done

  if [ "$removed" = true ]; then
    echo -e "${BLUE}SQLite recorder reset under ${dir}.${NC}"
  else
    echo -e "${YELLOW}[WARN] No SQLite recorder files found under ${dir}.${NC}"
  fi
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

purge_project_images() {
  if ! bool_true "$PURGE_IMAGES"; then
    return
  fi
  echo -e "${BLUE}Removing Home Assistant project images...${NC}"
  local images=("ghcr.io/home-assistant/home-assistant" "portainer/portainer-ce")
  local repo
  local removed=0
  for repo in "${images[@]}"; do
    local tags
    tags=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep "^${repo}:" || true)
    if [ -z "$tags" ]; then
      echo -e "${YELLOW}[WARN] No local image found for ${repo}${NC}"
      continue
    fi
    for tag in $tags; do
      echo -e "${BLUE}  - Removing image ${tag}${NC}"
      docker image rm -f "$tag" || true
    done
    removed=1
  done
  if [ "$removed" -eq 1 ]; then
    docker image prune -f >/dev/null 2>&1 || true
  else
    echo -e "${BLUE}No project images to remove.${NC}"
  fi
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
  PURGED_LOCAL_DONE=true
}

cleanup_env_artifacts() {
  if bool_true "$PURGED_LOCAL_DONE"; then
    return
  fi
  if bool_true "$KEEP_ENV"; then
    echo -e "${YELLOW}[WARN] Retaining .env in working directory (--keep-env).${NC}"
    return
  fi
  if [ ! -d "$WORK_DIR" ]; then
    return
  fi
  local removed_any=false
  for file in ".env" ".env.bootstrap"; do
    local target="${WORK_DIR}/${file}"
    if [ -f "$target" ]; then
      echo -e "${BLUE}Removing ${file} from working directory...${NC}"
      rm -f "$target" || true
      removed_any=true
    fi
  done
  if [ "$removed_any" = false ]; then
    echo -e "${YELLOW}[WARN] No .env artifacts found in working directory.${NC}"
  fi
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

ask_yes_no() {
  local prompt="$1"
  local default_answer="${2:-N}"
  local reply
  while true; do
    if ! printf "%b" "$prompt" > /dev/tty; then
      return 1
    fi
    if ! read -r reply < /dev/tty; then
      return 1
    fi
    if [ -z "$reply" ]; then
      reply="$default_answer"
    fi
    reply="${reply,,}"
    case "$reply" in
      y|yes)
        return 0
        ;;
      n|no)
        return 1
        ;;
      *)
        echo "Please answer y or n." > /dev/tty
        ;;
    esac
  done
}

prompt_optional_actions() {
  if bool_true "$FORCE" || [ ! -t 0 ]; then
    KEEP_CONFIG=false
    KEEP_DB=false
    return
  fi

  if [ "$PURGE_LOCAL" != "true" ] && [ "$PURGE_LOCAL_ENV_SET" != "true" ] && [ "$PURGE_LOCAL_CLI_SET" != "true" ]; then
    if ask_yes_no "${YELLOW}Delete this working directory (${WORK_DIR}) after cleanup? [y/N]: ${NC}"; then
      PURGE_LOCAL=true
    fi
  fi

  if [ "$PURGE_IMAGES" != "true" ] && [ "$PURGE_IMAGES_ENV_SET" != "true" ] && [ "$PURGE_IMAGES_CLI_SET" != "true" ]; then
    if ask_yes_no "${YELLOW}Remove Home Assistant/Portainer Docker images from this Pi? [y/N]: ${NC}"; then
      PURGE_IMAGES=true
    fi
  fi

  if ask_yes_no "${YELLOW}Keep Home Assistant configuration on the NAS (${HA_DATA_DIR}) (automations, dashboards, secrets)? [y/N]: ${NC}"; then
    KEEP_CONFIG=true
  else
    KEEP_CONFIG=false
  fi

  KEEP_DB=false
  if bool_true "$KEEP_CONFIG"; then
    local recorder="${RECORDER_BACKEND,,}"
    if [ "$recorder" = "sqlite" ]; then
      if ask_yes_no "${YELLOW}Keep SQLite recorder data at ${SQLITE_DATA_DIR:-/var/lib/piha/home-assistant/sqlite}? [y/N]: ${NC}"; then
        KEEP_DB=true
      fi
    elif [ "$recorder" = "mariadb" ]; then
      if ask_yes_no "${YELLOW}Keep NAS MariaDB deployment (${NAS_DEPLOY_DIR})? [y/N]: ${NC}"; then
        KEEP_DB=true
      fi
    fi
  fi
}



FORCE=false
SKIP_NAS_SSH=false
PURGE_LOCAL=false
PURGE_IMAGES=false
KEEP_ENV=false
PURGED_LOCAL_DONE=false
PURGE_LOCAL_ENV_SET=false
PURGE_IMAGES_ENV_SET=false
KEEP_ENV_ENV_SET=false
PURGE_LOCAL_CLI_SET=false
PURGE_IMAGES_CLI_SET=false
KEEP_ENV_CLI_SET=false
KEEP_CONFIG=false
KEEP_DB=false

if [ "${UNINSTALL_PURGE_LOCAL+x}" ]; then
  PURGE_LOCAL_ENV_SET=true
  if bool_true "${UNINSTALL_PURGE_LOCAL}"; then
    PURGE_LOCAL=true
  fi
fi
if [ "${UNINSTALL_PURGE_IMAGES+x}" ]; then
  PURGE_IMAGES_ENV_SET=true
  if bool_true "${UNINSTALL_PURGE_IMAGES}"; then
    PURGE_IMAGES=true
  fi
fi
if [ "${UNINSTALL_KEEP_ENV+x}" ]; then
  KEEP_ENV_ENV_SET=true
  if bool_true "${UNINSTALL_KEEP_ENV}"; then
    KEEP_ENV=true
  fi
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
      PURGE_LOCAL_CLI_SET=true
      shift
      ;;
    --purge-images)
      PURGE_IMAGES=true
      PURGE_IMAGES_CLI_SET=true
      shift
      ;;
    --keep-env)
      KEEP_ENV=true
      KEEP_ENV_CLI_SET=true
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

prompt_optional_actions

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
if bool_true "$KEEP_CONFIG"; then
  echo -e "${BLUE}Preserving Home Assistant data directory ${HA_DATA_DIR} (keep config).${NC}"
else
  TARGETS+=("${HA_DATA_DIR}:::Home Assistant data directory")
fi
TARGETS+=("${PORTAINER_DATA_DIR}:::Portainer data directory")
TARGETS+=("${DOCKER_COMPOSE_DIR}:::Compose directory")
if [ "${RECORDER_BACKEND,,}" = "sqlite" ] && ! bool_true "$KEEP_CONFIG"; then
  TARGETS+=("${SQLITE_DATA_DIR:-/var/lib/piha/home-assistant/sqlite}:::SQLite recorder directory")
fi
for entry in "${TARGETS[@]}"; do
  path="${entry%%:::*}"
  label="${entry##*:::}"
  delete_path "$path" "$label"
done

if bool_true "$KEEP_CONFIG" && [ "${RECORDER_BACKEND,,}" = "sqlite" ]; then
  if bool_true "$KEEP_DB"; then
    echo -e "${BLUE}SQLite recorder retained at ${SQLITE_DATA_DIR:-/var/lib/piha/home-assistant/sqlite}.${NC}"
  else
    purge_sqlite_recorder
  fi
fi

if [ -d "$NAS_MOUNT_DIR" ]; then
  echo -e "${BLUE}Ensuring NAS mount point ownership...${NC}"
  sudo chown "${DOCKER_USER_ID}:${DOCKER_GROUP_ID}" "$NAS_MOUNT_DIR" || true
fi

cleanup_mariadb=true
if [ "${RECORDER_BACKEND,,}" = "mariadb" ]; then
  if bool_true "$KEEP_CONFIG" && bool_true "$KEEP_DB"; then
    echo -e "${BLUE}MariaDB deployment preserved at ${NAS_DEPLOY_DIR}.${NC}"
    cleanup_mariadb=false
  fi
else
  if bool_true "$KEEP_CONFIG"; then
    cleanup_mariadb=false
  fi
fi

if [ "$cleanup_mariadb" = true ]; then
  if bool_true "$SKIP_NAS_SSH"; then
    echo -e "${YELLOW}[WARN] Skipping NAS SSH cleanup as requested.${NC}"
  else
    run_remote_cleanup
  fi
fi

if bool_true "$KEEP_CONFIG"; then
  echo -e "${BLUE}Home Assistant configuration preserved at ${HA_DATA_DIR}.${NC}"
  if [ "${RECORDER_BACKEND,,}" = "sqlite" ]; then
    if bool_true "$KEEP_DB"; then
      echo -e "${BLUE}SQLite recorder retained at ${SQLITE_DATA_DIR:-/var/lib/piha/home-assistant/sqlite}.${NC}"
    else
      echo -e "${BLUE}SQLite recorder reset; a fresh database will be created on next install.${NC}"
    fi
  elif [ "${RECORDER_BACKEND,,}" = "mariadb" ]; then
    if bool_true "$KEEP_DB"; then
      echo -e "${BLUE}MariaDB deployment preserved at ${NAS_DEPLOY_DIR}.${NC}"
    else
      echo -e "${BLUE}MariaDB deployment removed from ${NAS_DEPLOY_DIR}; rerun the installer to bootstrap a new database.${NC}"
    fi
  fi
fi

purge_project_images
purge_working_dir
cleanup_env_artifacts

if bool_true "$PURGED_LOCAL_DONE"; then
  echo -e "${BLUE}Cleanup complete. Working directory ${WORK_DIR} removed (--purge-local).${NC}"
elif bool_true "$KEEP_ENV"; then
  echo -e "${BLUE}Cleanup complete. Working directory retained at ${WORK_DIR}; .env kept (--keep-env).${NC}"
else
  echo -e "${BLUE}Cleanup complete. Working directory retained at ${WORK_DIR}; .env removed.${NC}"
fi
