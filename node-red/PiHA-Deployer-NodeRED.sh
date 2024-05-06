#!/bin/bash

# Version
VERSION="1.0.1"

# Define colors
BLUE='\033[0;36m'  # Lighter blue (cyan)
RED='\033[1;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${BLUE}PiHA-Deployer Node-RED Installation Script v$VERSION${NC}"
echo -e "${BLUE}===============================================${NC}"

# Ask user if they want to be prompted for each step
echo -e "${BLUE}🤔 Do you want to be prompted for each step? (y/n)${NC}"
read -r prompt_choice

# Function for confirmation prompts
confirm_step() {
    if [ "$prompt_choice" = "y" ] || [ "$prompt_choice" = "Y" ]; then
        echo -e "${BLUE}📌 Next step: $1${NC}"
        echo -n "Press ENTER to continue or wait 10 seconds for automatic continuation..."
        read -t 10
        echo
    else
        echo -e "${BLUE}🚀 Executing: $1${NC}"
    fi
}

# Load variables from .env file
confirm_step "Load environment variables from .env file"
if [ -f .env ]; then
    export $(cat .env | xargs)
else
    echo -e "${RED}❌ .env file not found. Please create it with all required variables.${NC}"
    exit 1
fi

# Clean up variables (remove carriage returns)
USERNAME=$(echo "$USERNAME" | tr -d '\r')
SAMBA_USER=$(echo "$SAMBA_USER" | tr -d '\r')
SAMBA_PASS=$(echo "$SAMBA_PASS" | tr -d '\r')
BASE_DIR=$(echo "$BASE_DIR" | tr -d '\r')
DOCKER_COMPOSE_DIR=$(echo "$DOCKER_COMPOSE_DIR" | tr -d '\r')
PORTAINER_DATA_DIR=$(echo "$PORTAINER_DATA_DIR" | tr -d '\r')
NODE_RED_DATA_DIR=$(echo "$NODE_RED_DATA_DIR" | tr -d '\r')
PORTAINER_PORT=$(echo "$PORTAINER_PORT" | tr -d '\r')
NODE_RED_PORT=$(echo "$NODE_RED_PORT" | tr -d '\r')
IP=$(echo "$IP" | tr -d '\r')
NAS_IP=$(echo "$NAS_IP" | tr -d '\r')
NAS_SHARE_NAME=$(echo "$NAS_SHARE_NAME" | tr -d '\r')
NAS_USERNAME=$(echo "$NAS_USERNAME" | tr -d '\r')
NAS_PASSWORD=$(echo "$NAS_PASSWORD" | tr -d '\r')
NAS_MOUNT_DIR=$(echo "$NAS_MOUNT_DIR" | tr -d '\r')
SYNC_INTERVAL=$(echo "$SYNC_INTERVAL" | tr -d '\r')

# Check if required variables are set
confirm_step "Check if all required variables are set in the .env file"
required_vars=(BASE_DIR USERNAME SAMBA_USER SAMBA_PASS DOCKER_COMPOSE_DIR PORTAINER_DATA_DIR NODE_RED_DATA_DIR PORTAINER_PORT NODE_RED_PORT IP NAS_IP NAS_SHARE_NAME NAS_USERNAME NAS_PASSWORD NAS_MOUNT_DIR SYNC_INTERVAL)
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo -e "${RED}❌ $var is not set in .env file${NC}"
        exit 1
    fi
done

# ... (rest of the script remains the same until the Node-RED permissions section)

# Set correct permissions for Node-RED data directory
confirm_step "Set permissions for Node-RED data directory"
sudo mkdir -p "$NODE_RED_DATA_DIR"
sudo chown -R 1000:1000 "$NODE_RED_DATA_DIR"
sudo chmod -R 775 "$NODE_RED_DATA_DIR"

# Ensure settings.js exists and has correct permissions
confirm_step "Ensure Node-RED settings.js exists with correct permissions"
SETTINGS_JS="$NODE_RED_DATA_DIR/settings.js"
if [ ! -f "$SETTINGS_JS" ]; then
    sudo touch "$SETTINGS_JS"
fi
sudo chown 1000:1000 "$SETTINGS_JS"
sudo chmod 664 "$SETTINGS_JS"

# Modify docker-compose.yml to ensure Node-RED has correct permissions
confirm_step "Modify docker-compose.yml for Node-RED permissions"
sed -i '/node-red:/,/ports:/c\
  node-red:\
    image: nodered/node-red:latest\
    container_name: node-red\
    restart: unless-stopped\
    user: "1000:1000"\
    volumes:\
      - ${NODE_RED_DATA_DIR}:/data\
      - ${NAS_MOUNT_DIR}/node-red:/nas_data\
    ports:' "$DOCKER_COMPOSE_DIR/docker-compose.yml"

# Start Docker containers
confirm_step "Start Docker containers (Portainer and Node-RED)"
sudo docker-compose -f "$DOCKER_COMPOSE_DIR/docker-compose.yml" up -d

# ... (rest of the script remains the same)

echo -e "${BLUE}✅ Installation complete!${NC}"
echo -e "${BLUE}🌐 Portainer is accessible at http://$IP:$PORTAINER_PORT${NC}"
echo -e "${BLUE}🔴 Node-RED is accessible at http://$IP:$NODE_RED_PORT${NC}"
echo -e "${BLUE}📁 Docker folders are shared via Samba at \\\\$IP\\docker${NC}"
echo -e "${BLUE}👤 Please use your Samba username ($SAMBA_USER) and the password you set in the .env file to access the share.${NC}"
echo -e "${BLUE}🔄 You may need to log out and log back in for Docker permissions to take effect.${NC}"
echo -e "${BLUE}🔄 Data is being synced to NAS at ${SYNC_INTERVAL} intervals.${NC}"

# Clean up sensitive files
confirm_step "Clean up temporary files for security"
cd ~
sudo rm -rf $BASE_DIR

echo -e "${GREEN}🎉 Setup complete. Temporary files have been removed for security.${NC}"
echo -e "${GREEN}🔍 If you encounter any issues, please check the Docker logs using 'docker logs portainer' or 'docker logs node-red'${NC}"