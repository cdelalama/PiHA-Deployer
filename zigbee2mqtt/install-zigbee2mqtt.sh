#!/bin/bash
set -e

# Version
VERSION="1.1.3"

# Colors
BLUE='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}PiHA-Deployer Zigbee2MQTT Installer v${VERSION}${NC}"

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

upsert_env_value() {
  local key="$1"
  local value="$2"
  local file="$3"
  if [ -z "$file" ] || [ ! -f "$file" ]; then
    return
  fi
  if grep -Eq "^[[:space:]]*${key}[[:space:]]*=" "$file"; then
    sed -i "s|^[[:space:]]*${key}[[:space:]]*=.*|${key}=${value}|" "$file"
  else
    echo "${key}=${value}" >> "$file"
  fi
}

ensure_packages() {
  echo -e "${BLUE}Ensuring required packages are present...${NC}"
  sudo apt-get update -y
  sudo apt-get install -y ca-certificates curl gnupg lsb-release smbclient cifs-utils usbutils
}

ensure_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo -e "${BLUE}Installing Docker (get.docker.com)...${NC}"
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    echo -e "${YELLOW}[WARN] User added to docker group. You may need to log out and back in.${NC}"
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

detect_usb_dongle() {
  echo -e "${BLUE}Detecting SONOFF Zigbee USB dongle...${NC}"

  # Known SONOFF Zigbee dongle IDs
  local sonoff_ids=("1a86:55d4" "10c4:ea60" "1a86:7523")
  local found_device=""
  local vendor_id=""
  local product_id=""

  for id in "${sonoff_ids[@]}"; do
    vendor_id="${id%:*}"
    product_id="${id#*:}"
    if lsusb | grep -qi "$id"; then
      echo -e "${GREEN}[OK] Found SONOFF Zigbee dongle: $id${NC}"
      found_device="$id"
      break
    fi
  done

  if [ -z "$found_device" ]; then
    echo -e "${RED}[ERROR] SONOFF Zigbee dongle not detected. Please connect it and try again.${NC}"
    echo -e "${BLUE}[INFO] Looking for devices matching: ${sonoff_ids[*]}${NC}"
    echo -e "${BLUE}[INFO] Connected USB devices:${NC}"
    lsusb
    exit 1
  fi

  # Store for later use
  export DETECTED_VENDOR_ID="$vendor_id"
  export DETECTED_PRODUCT_ID="$product_id"
}

setup_udev_rules() {
  echo -e "${BLUE}Setting up udev rules for Zigbee dongle...${NC}"

  local udev_rule="SUBSYSTEM==\"tty\", ATTRS{idVendor}==\"${DETECTED_VENDOR_ID}\", ATTRS{idProduct}==\"${DETECTED_PRODUCT_ID}\", SYMLINK+=\"zigbee\""
  local udev_file="/etc/udev/rules.d/99-zigbee-dongle.rules"

  echo "$udev_rule" | sudo tee "$udev_file" >/dev/null
  sudo udevadm control --reload-rules
  sudo udevadm trigger

  echo -e "${GREEN}[OK] Udev rules configured${NC}"
  echo -e "${BLUE}[INFO] Device will be available as /dev/zigbee${NC}"

  # Set USB_DEVICE_PATH if not already set
  if [ -z "$USB_DEVICE_PATH" ]; then
    export USB_DEVICE_PATH="/dev/zigbee"
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
  sudo mkdir -p "$BASE_DIR" "$DOCKER_COMPOSE_DIR" "$Z2M_DATA_DIR" "$MQTT_CONFIG_DIR" "$MQTT_DATA_DIR" "$MQTT_LOG_DIR" "$PORTAINER_DATA_DIR"
  sudo chown -R "${DOCKER_USER_ID}:${DOCKER_GROUP_ID}" "$BASE_DIR" "$DOCKER_COMPOSE_DIR" "$Z2M_DATA_DIR" "$MQTT_CONFIG_DIR" "$MQTT_DATA_DIR" "$MQTT_LOG_DIR" "$PORTAINER_DATA_DIR" 2>/dev/null || true
  sudo chmod -R 775 "$BASE_DIR" "$DOCKER_COMPOSE_DIR" "$Z2M_DATA_DIR" "$MQTT_CONFIG_DIR" "$MQTT_DATA_DIR" "$MQTT_LOG_DIR" "$PORTAINER_DATA_DIR" 2>/dev/null || true
}

write_portainer_secret() {
  echo -e "${BLUE}Writing Portainer admin password file...${NC}"
  local pw_file="${PORTAINER_DATA_DIR}/portainer_password.txt"
  sudo mkdir -p "${PORTAINER_DATA_DIR}"
  echo -n "$PORTAINER_PASS" | sudo tee "$pw_file" >/dev/null
  sudo chmod 600 "$pw_file" 2>/dev/null || true
  sudo chown "${DOCKER_USER_ID}:${DOCKER_GROUP_ID}" "$pw_file" 2>/dev/null || true
}

setup_mosquitto_config() {
  echo -e "${BLUE}Setting up Mosquitto configuration...${NC}"
  sudo mkdir -p "${MQTT_CONFIG_DIR}" "${MQTT_DATA_DIR}" "${MQTT_LOG_DIR}"
  local config_file="${MQTT_CONFIG_DIR}/mosquitto.conf"
  local passwd_file="${MQTT_CONFIG_DIR}/passwd"

  if [ -n "$MQTT_USER" ] && [ -n "$MQTT_PASSWORD" ]; then
    cat <<EOF | sudo tee "$config_file" >/dev/null
# Mosquitto configuration for Zigbee2MQTT
listener 1883
allow_anonymous false
password_file /mosquitto/config/passwd

# Persistence
persistence true
persistence_location /mosquitto/data/

# Logging
log_dest file /mosquitto/log/mosquitto.log
log_type error
log_type warning
log_type notice
log_type information
log_timestamp true
EOF

    echo -e "${BLUE}Setting up MQTT authentication...${NC}"
    sudo docker run --rm \
      -e MQTT_USER="$MQTT_USER" \
      -e MQTT_PASSWORD="$MQTT_PASSWORD" \
      -v "${MQTT_CONFIG_DIR}:/mosquitto/config" \
      eclipse-mosquitto:2.0 \
      sh -c 'touch /mosquitto/config/passwd && mosquitto_passwd -b /mosquitto/config/passwd "$MQTT_USER" "$MQTT_PASSWORD"'
    sudo chown "${DOCKER_USER_ID}:${DOCKER_GROUP_ID}" "$passwd_file" 2>/dev/null || true
    sudo chmod 600 "$passwd_file" 2>/dev/null || true
  else
    cat <<EOF | sudo tee "$config_file" >/dev/null
# Mosquitto configuration for Zigbee2MQTT (anonymous access)
listener 1883
allow_anonymous true

# Persistence
persistence true
persistence_location /mosquitto/data/

# Logging
log_dest file /mosquitto/log/mosquitto.log
log_type error
log_type warning
log_type notice
log_type information
log_timestamp true
EOF
    sudo rm -f "$passwd_file"
    echo -e "${YELLOW}[WARN] No MQTT credentials provided. Using anonymous access.${NC}"
  fi

  if [ ! -s "$config_file" ]; then
    echo -e "${RED}[ERROR] Failed to create Mosquitto configuration at $config_file${NC}"
    exit 1
  fi

  sudo chown "${DOCKER_USER_ID}:${DOCKER_GROUP_ID}" "$config_file" 2>/dev/null || true
}

setup_zigbee2mqtt_config() {
  echo -e "${BLUE}Setting up Zigbee2MQTT configuration...${NC}"
  local config_file="${Z2M_DATA_DIR}/configuration.yaml"

  # MQTT server URL
  local mqtt_server="mqtt://mosquitto:1883"
  if [ -n "$MQTT_USER" ] && [ -n "$MQTT_PASSWORD" ]; then
    mqtt_server="mqtt://${MQTT_USER}:${MQTT_PASSWORD}@mosquitto:1883"
  fi

  local mqtt_auth_block=""
  if [ -n "$MQTT_USER" ] && [ -n "$MQTT_PASSWORD" ]; then
    mqtt_auth_block=$'  user: '${MQTT_USER}$'\n  password: '${MQTT_PASSWORD}$'\n'
  fi

  cat <<EOF | sudo tee "$config_file" >/dev/null
# Core settings
homeassistant: true
permit_join: true

# MQTT settings
mqtt:
  base_topic: zigbee2mqtt
  server: '${mqtt_server}'
${mqtt_auth_block}  keepalive: 60
  version: 5

# Serial settings
serial:
  port: /dev/ttyACM0
  adapter: auto

# Frontend / UI
frontend:
  port: 8080
  host: 0.0.0.0

# Advanced behaviour
advanced:
  log_level: info
  pan_id: GENERATE
  ext_pan_id: GENERATE
  network_key: GENERATE
  legacy_api: false

# Device defaults
device_options: {}

# Placeholder structures
devices: {}
groups: {}

# Experimental features
experimental:
  new_api: true

# Mark onboarding wizard as completed
onboarding: false
EOF

  sudo chown "${DOCKER_USER_ID}:${DOCKER_GROUP_ID}" "$config_file" 2>/dev/null || true
}

copy_compose_and_env() {
  echo -e "${BLUE}Copying compose and .env to BASE_DIR...${NC}"
  if [ ! -f docker-compose.yml ]; then
    echo -e "${RED}[ERROR] docker-compose.yml not found next to this installer${NC}"; exit 1
  fi
  cp docker-compose.yml "${BASE_DIR}/docker-compose.yml"

  local env_source=".env"
  local tmp_env
  tmp_env=$(mktemp)
  cp "$env_source" "$tmp_env"
  if [ -n "$USB_DEVICE_PATH" ]; then
    if grep -Eq '^[[:space:]]*USB_DEVICE_PATH[[:space:]]*=' "$tmp_env"; then
      sed -i "s|^[[:space:]]*USB_DEVICE_PATH[[:space:]]*=.*|USB_DEVICE_PATH=$USB_DEVICE_PATH|" "$tmp_env"
    else
      echo "USB_DEVICE_PATH=$USB_DEVICE_PATH" >> "$tmp_env"
    fi
  fi
  cp "$tmp_env" "${BASE_DIR}/.env"
  chmod 600 "${BASE_DIR}/.env" || true
  rm -f "$tmp_env"
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
  sleep 5
  if ! docker ps | grep -q zigbee2mqtt; then
    echo -e "${RED}[ERROR] zigbee2mqtt not running${NC}"; exit 1
  fi
  if ! docker ps | grep -q mosquitto; then
    echo -e "${RED}[ERROR] mosquitto not running${NC}"; exit 1
  fi
  if ! docker ps | grep -q portainer; then
    echo -e "${RED}[ERROR] portainer not running${NC}"; exit 1
  fi
  echo -e "${GREEN}[OK] All containers running${NC}"
}

# Main
load_env
post_load_fallbacks
require_vars \
  BASE_DIR DOCKER_USER_ID DOCKER_GROUP_ID HOST_ID \
  Z2M_PORT MQTT_PORT \
  NAS_IP NAS_SHARE_NAME NAS_USERNAME NAS_PASSWORD NAS_MOUNT_DIR \
  PORTAINER_PASS

ensure_packages
ensure_docker

echo -e "${BLUE}Checking NAS connectivity...${NC}"
if ! ping -c 2 "$NAS_IP" >/dev/null 2>&1; then
  echo -e "${RED}[ERROR] Cannot reach NAS at $NAS_IP${NC}"; exit 1
fi

detect_usb_dongle
setup_udev_rules
if [ -n "$USB_DEVICE_PATH" ]; then
  upsert_env_value "USB_DEVICE_PATH" "$USB_DEVICE_PATH" .env
fi

mount_nas
# Derive NAS-based defaults if not provided (group by host)
if [ -z "$DOCKER_COMPOSE_DIR" ]; then
  DOCKER_COMPOSE_DIR="${NAS_MOUNT_DIR}/hosts/${HOST_ID}/compose"
fi
if [ -z "$Z2M_DATA_DIR" ]; then
  Z2M_DATA_DIR="${NAS_MOUNT_DIR}/hosts/${HOST_ID}/zigbee2mqtt"
fi
if [ -z "$MQTT_CONFIG_DIR" ]; then
  MQTT_CONFIG_DIR="${NAS_MOUNT_DIR}/hosts/${HOST_ID}/mosquitto/config"
fi
if [ -z "$MQTT_DATA_DIR" ]; then
  MQTT_DATA_DIR="${NAS_MOUNT_DIR}/hosts/${HOST_ID}/mosquitto/data"
fi
if [ -z "$MQTT_LOG_DIR" ]; then
  MQTT_LOG_DIR="${NAS_MOUNT_DIR}/hosts/${HOST_ID}/mosquitto/log"
fi
if [ -z "$PORTAINER_DATA_DIR" ]; then
  PORTAINER_DATA_DIR="${NAS_MOUNT_DIR}/hosts/${HOST_ID}/portainer"
fi

setup_dirs
write_portainer_secret
setup_mosquitto_config
setup_zigbee2mqtt_config
copy_compose_and_env

echo -e "${BLUE}Launching stack...${NC}"
start_stack
verify_running

# Determine IP if not provided or set to auto
if [ -z "$IP" ] || [ "$IP" = "auto" ]; then
  IP=$(hostname -I | awk '{print $1}')
fi

echo -e "\n${GREEN}Setup complete${NC}"
echo -e "${BLUE}- Zigbee2MQTT: http://$IP:${Z2M_PORT:-8080}${NC}"
echo -e "${BLUE}- MQTT Broker: $IP:${MQTT_PORT:-1883}${NC}"
echo -e "${BLUE}- Portainer: http://$IP:${PORTAINER_PORT:-9000}${NC}"
echo -e "${BLUE}- NAS mount: ${NAS_MOUNT_DIR}${NC}"
echo -e "${BLUE}- USB Device: ${USB_DEVICE_PATH}${NC}"
echo -e "\n${YELLOW}[NEXT] Configure Home Assistant MQTT integration pointing to $IP:${MQTT_PORT:-1883}${NC}"
