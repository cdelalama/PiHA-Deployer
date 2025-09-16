#!/bin/bash

# Version
VERSION="1.0.34"

# Define colors
BLUE='\033[0;36m'  # Lighter blue (cyan)
RED='\033[1;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${BLUE}PiHA-Deployer Node-RED Installation Script v$VERSION${NC}"
echo -e "${BLUE}===============================================${NC}"

# Function to announce major steps
announce_step() {
    echo -e "${BLUE} Executing: $1${NC}"
}

# Load variables from .env file
announce_step "Load environment variables from .env file"
if [ -f .env ]; then
    # Load all variables from .env
    set -a  # Automatically export all variables
    source .env
    set +a

    # Only show confirmation without values
    echo -e "${GREEN}[OK] Environment variables loaded successfully${NC}"
else
    echo -e "${RED}[ERROR] .env file not found${NC}"
    exit 1
fi

# Check if required variables are set
announce_step "Check if all required variables are set in the .env file"
required_vars=(
    BASE_DIR
    DOCKER_USER_ID
    DOCKER_GROUP_ID
    SAMBA_USER
    SAMBA_PASS
    DOCKER_COMPOSE_DIR
    PORTAINER_DATA_DIR
    NODE_RED_DATA_DIR
    SYNCTHING_CONFIG_DIR
    PORTAINER_PORT
    NODE_RED_PORT
    IP
    NAS_IP
    NAS_SHARE_NAME
    NAS_USERNAME
    NAS_PASSWORD
    NAS_MOUNT_DIR
    SYNC_INTERVAL
    SYNCTHING_USER
    SYNCTHING_PASS
    PORTAINER_PASS
)

# Verify all required variables are set
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo -e "${RED}[ERROR] Required variable $var is not set in .env${NC}"
        exit 1
    fi
done
echo -e "${GREEN}[OK] All required variables are set${NC}"

# Validate SYNC_INTERVAL
if ! [[ "$SYNC_INTERVAL" =~ ^[0-9]+$ ]] || [ "$SYNC_INTERVAL" -lt 60 ]; then
    echo -e "${RED}[ERROR] SYNC_INTERVAL must be a number greater than 60 seconds${NC}"
    exit 1
fi

# Verify and obtain IP address
echo -e "${BLUE}Verifying IP address...${NC}"
if [ "$IP" = "auto" ]; then
    IP=$(hostname -I | awk '{print $1}')
    echo -e "${BLUE}Auto-detected IP: $IP${NC}"
fi

if [[ ! $IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}[ERROR] Could not determine valid IP address. Got: $IP${NC}"
    exit 1
fi
echo -e "${GREEN}[OK] IP address verified: $IP${NC}"

# Create Portainer password file
echo -e "${BLUE}Creating Portainer password file...${NC}"
PORTAINER_PASS_FILE="${DOCKER_COMPOSE_DIR}/portainer_password.txt"
sudo mkdir -p "${DOCKER_COMPOSE_DIR}"
echo "${PORTAINER_PASS}" | sudo tee "${PORTAINER_PASS_FILE}" > /dev/null
sudo chmod 600 "${PORTAINER_PASS_FILE}"
sudo chown "${DOCKER_USER_ID}:${DOCKER_GROUP_ID}" "${PORTAINER_PASS_FILE}"

# Create directories and set permissions
announce_step "Create necessary directories and set permissions"
echo -e "${BLUE}Creating directories and setting permissions...${NC}"

# Create all required directories
sudo mkdir -p "$DOCKER_COMPOSE_DIR" \
             "$PORTAINER_DATA_DIR" \
             "$NODE_RED_DATA_DIR" \
             "$SYNCTHING_CONFIG_DIR/config" \
             "$SYNCTHING_CONFIG_DIR/data/node-red" \
             "$SYNCTHING_CONFIG_DIR/data/portainer" \
             "$SYNCTHING_CONFIG_DIR/data/nas_data" \
             "$NAS_MOUNT_DIR"

# Create .stfolder directories with correct permissions (only once)
for dir in "node-red" "portainer" "nas_data"; do
    sudo mkdir -p "$SYNCTHING_CONFIG_DIR/data/$dir/.stfolder"
done

# Set permissions once
sudo chown -R "${DOCKER_USER_ID}:${DOCKER_GROUP_ID}" "$PORTAINER_DATA_DIR" "$NODE_RED_DATA_DIR" "$SYNCTHING_CONFIG_DIR" "$NAS_MOUNT_DIR"
sudo chmod -R 775 "$PORTAINER_DATA_DIR" "$NODE_RED_DATA_DIR" "$SYNCTHING_CONFIG_DIR" "$NAS_MOUNT_DIR"

echo -e "${GREEN}Directories created and permissions set successfully${NC}"

# Copy .env to DOCKER_COMPOSE_DIR
announce_step "Copy .env file to Docker Compose directory"
sudo cp .env "$DOCKER_COMPOSE_DIR/.env"

# Set proper permissions
sudo chown -R "${DOCKER_USER_ID}:${DOCKER_GROUP_ID}" "$SYNCTHING_CONFIG_DIR"

# Start Docker containers
announce_step "Start Docker containers (Portainer and Node-RED)"
echo -e "${BLUE}Starting Docker containers...${NC}"

# Check if docker-compose exists
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}[ERROR] docker-compose not found. Please install Docker Compose first.${NC}"
    exit 1
fi

# Check if docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}[ERROR] Docker daemon is not running. Please start Docker first.${NC}"
    exit 1
fi

# Attempt to start containers
if ! sudo -E docker-compose -f "${BASE_DIR}/docker-compose.yml" up -d; then
    echo -e "${RED}[ERROR] Failed to start Docker containers. Checking logs...${NC}"
    sudo docker-compose -f "${BASE_DIR}/docker-compose.yml" logs
    echo -e "${RED}[ERROR] Please check the logs above for errors.${NC}"
    exit 1
fi

# Verify containers are running
echo -e "${BLUE}Verifying containers status...${NC}"
if ! docker ps | grep -q "portainer" || ! docker ps | grep -q "node-red"; then
    echo -e "${RED}[ERROR] One or more containers failed to start. Container status:${NC}"
    docker ps -a
    exit 1
fi

# Syncthing configuration
announce_step "Configure Syncthing with authentication"

# Start Syncthing
echo "Starting Syncthing container..."
sudo docker-compose -f "${BASE_DIR}/docker-compose.yml" up -d syncthing

# Wait for Syncthing to be ready and obtain its ID
echo -e "${BLUE}Waiting for Syncthing to start and extracting ID...${NC}"
sleep 10

# Run Syncthing configuration script
echo -e "${BLUE}Configuring Syncthing...${NC}"
if [ -f "${BASE_DIR}/configure-syncthing.sh" ]; then
    sudo chmod +x "${BASE_DIR}/configure-syncthing.sh"
    if ! sudo -E "${BASE_DIR}/configure-syncthing.sh"; then
        echo -e "${RED}[ERROR] Failed to configure Syncthing${NC}"
        exit 1
    fi
else
    echo -e "${RED}[ERROR] configure-syncthing.sh not found${NC}"
    exit 1
fi

# Extract and save Syncthing ID
SYNCTHING_INFO=$(docker logs syncthing 2>&1 | grep -oP "My ID: \K[A-Z0-9-]+" | head -n 1)
if [ ! -z "$SYNCTHING_INFO" ]; then
    # Write a single line in each file
    printf "%s" "$SYNCTHING_INFO" | sudo tee "${SYNCTHING_CONFIG_DIR}/syncthing_id.txt" > /dev/null
    printf "%s" "$SYNCTHING_INFO" | sudo tee "${DOCKER_COMPOSE_DIR}/syncthing_id.txt" > /dev/null
    echo -e "${GREEN}[OK] Syncthing ID saved to configuration files${NC}"
else
    SYNCTHING_INFO="Check logs for ID"
    echo -e "${RED}[ERROR] Could not extract Syncthing ID${NC}"
    echo -e "${RED}[ERROR] Please check: docker logs syncthing | grep 'My ID:'${NC}"
fi

# Final summary
echo -e "\n${GREEN}Setup complete!${NC}"
echo -e "\n${BLUE}Summary of services:${NC}"
echo -e "${BLUE}- Portainer: http://$IP:$PORTAINER_PORT${NC}"
echo -e "${BLUE}- Node-RED: http://$IP:$NODE_RED_PORT${NC}"
echo -e "${BLUE}- Syncthing: http://$IP:8384${NC}"
echo -e "${BLUE}- Samba share: \\$IP\\docker${NC}"
echo -e "${BLUE}- Samba username: $SAMBA_USER${NC}"
echo -e "${BLUE}- Syncthing username: ${SYNCTHING_USER}${NC}"
echo -e "${BLUE}- Syncthing ID: ${SYNCTHING_INFO}${NC}"

# Convert SYNC_INTERVAL to a more readable format
SYNC_INTERVAL_MINUTES=$((SYNC_INTERVAL / 60))
SYNC_INTERVAL_HOURS=$(printf "%.1f" $(echo "$SYNC_INTERVAL_MINUTES / 60" | bc -l))

echo -e "\n${BLUE}Additional Information:${NC}"
echo -e "${BLUE}- Data sync interval: ${SYNC_INTERVAL} seconds (${SYNC_INTERVAL_HOURS} hours)${NC}"
echo -e "${BLUE}- Docker logs: 'docker logs portainer' or 'docker logs node-red'${NC}"
echo -e "${BLUE}- Log out and log back in if you experience permission issues${NC}"

