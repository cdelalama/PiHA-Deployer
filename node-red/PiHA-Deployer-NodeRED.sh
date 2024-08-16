#!/bin/bash

# Version
VERSION="1.0.12"

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
    # First, show all current environment variables (except SAMBA_PASS)
    echo "Current environment variables:"
    env | grep -Ev "SAMBA_PASS" | grep -E "SAMBA_|DOCKER_|NAS_|PORT|IP|USERNAME|BASE_DIR|SYNC"

    # Load all variables from .env
    set -a  # Automatically export all variables
    source .env
    set +a

    # Debug output (without showing the actual password)
    if [ -n "$SAMBA_PASS" ]; then
        echo "SAMBA_PASS is set with length: ${#SAMBA_PASS} characters"
    else
        echo "SAMBA_PASS is not set"
    fi
else
    echo -e "${RED}❌ .env file not found${NC}"
    exit 1
fi

# Check if required variables are set
confirm_step "Check if all required variables are set in the .env file"
required_vars=(
    BASE_DIR 
    USERNAME 
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
)

# Verify all required variables are set
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo -e "${RED}❌ Required variable $var is not set in .env${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✅ All required variables are set${NC}"

# Create directories and set permissions
confirm_step "Create necessary directories and set permissions"
echo -e "${BLUE}Creating directories and setting permissions...${NC}"

# Create all required directories
sudo mkdir -p "$DOCKER_COMPOSE_DIR" \
             "$PORTAINER_DATA_DIR" \
             "$NODE_RED_DATA_DIR" \
             "$SYNCTHING_CONFIG_DIR" \
             "$NAS_MOUNT_DIR"

# Set correct permissions using variables from .env
sudo chown -R "${DOCKER_USER_ID}:${DOCKER_GROUP_ID}" "$PORTAINER_DATA_DIR"
sudo chown -R "${DOCKER_USER_ID}:${DOCKER_GROUP_ID}" "$NODE_RED_DATA_DIR"
sudo chown -R "${DOCKER_USER_ID}:${DOCKER_GROUP_ID}" "$SYNCTHING_CONFIG_DIR"

# Set directory permissions
sudo chmod -R 775 "$PORTAINER_DATA_DIR"
sudo chmod -R 775 "$NODE_RED_DATA_DIR"
sudo chmod -R 775 "$SYNCTHING_CONFIG_DIR"

echo -e "${GREEN}Directories created and permissions set successfully${NC}"

# Copy .env to DOCKER_COMPOSE_DIR
confirm_step "Copy .env file to Docker Compose directory"
sudo cp .env "$DOCKER_COMPOSE_DIR/.env"

# Start Docker containers
confirm_step "Start Docker containers (Portainer and Node-RED)"
echo -e "${BLUE}Starting Docker containers...${NC}"

# Check if docker-compose exists
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ docker-compose not found. Please install Docker Compose first.${NC}"
    exit 1
fi

# Check if docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}❌ Docker daemon is not running. Please start Docker first.${NC}"
    exit 1
fi

# Attempt to start containers
if ! sudo -E docker-compose -f "/home/cdelalama/docker_temp_setup/docker-compose.yml" up -d; then
    echo -e "${RED}❌ Failed to start Docker containers. Checking logs...${NC}"
    sudo docker-compose -f "/home/cdelalama/docker_temp_setup/docker-compose.yml" logs
    echo -e "${RED}❌ Please check the logs above for errors.${NC}"
    exit 1
fi

# Verify containers are running
echo -e "${BLUE}Verifying containers status...${NC}"
if ! docker ps | grep -q "portainer" || ! docker ps | grep -q "node-red"; then
    echo -e "${RED}❌ One or more containers failed to start. Container status:${NC}"
    docker ps -a
    exit 1
fi

echo -e "${GREEN}✅ Docker containers started successfully${NC}"

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