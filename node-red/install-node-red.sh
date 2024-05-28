#!/bin/bash
set -e

# Version
VERSION="1.0.43"

# Define colors
BLUE='\033[0;36m'  # Lighter blue (cyan)
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}PiHA-Deployer Node-RED Install Script v$VERSION${NC}" >&2
echo -e "${BLUE}Script started${NC}" >&2

# Install necessary packages
echo -e "${BLUE}Installing necessary packages...${NC}" >&2
sudo apt-get update
sudo apt-get install -y smbclient cifs-utils

# GitHub repository details
REPO_OWNER="cdelalama"
REPO_NAME="PiHA-Deployer"
BRANCH="main"

# Function to download a file from GitHub
download_from_github() {
    local file=$1
    local url="https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$BRANCH/node-red/$file"
    echo -e "${BLUE}Downloading $file from GitHub...${NC}" >&2
    curl -sSL -o "$file" "$url"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to download $file. Exiting.${NC}" >&2
        exit 1
    fi
    echo -e "${GREEN}$file downloaded successfully${NC}" >&2
}

# Function to export variables from .env file
export_env_vars() {
    echo -e "${BLUE}Exporting environment variables from .env file...${NC}"
    while IFS='=' read -r key value; do
        if [[ ! -z "$key" && "$key" != \#* ]]; then
            export "$key=$(echo $value | tr -d '"')"
        fi
    done < .env
}

# Ensure .env file has correct permissions
chmod 600 .env

# Export environment variables
export_env_vars

# Debugging output to verify variables are sourced correctly
echo -e "${BLUE}Checking exported variables:${NC}"
echo -e "NAS_IP: '$NAS_IP'"
echo -e "NAS_SHARE_NAME: '$NAS_SHARE_NAME'"
echo -e "NAS_USERNAME: '$NAS_USERNAME'"
echo -e "NAS_PASSWORD: '$NAS_PASSWORD'"
echo -e "NAS_MOUNT_DIR: '$NAS_MOUNT_DIR'"

# Temporary ping check
echo "Pinging NAS directly with IP: 10.0.0.220"
if ping -c 4 10.0.0.220 > /dev/null 2>&1; then
    echo -e "${GREEN}Direct ping to NAS is successful.${NC}"
else
    echo -e "${RED}Direct ping to NAS failed.${NC}"
fi

echo "Pinging NAS with NAS_IP variable: $NAS_IP"
if ping -c 4 "$NAS_IP" > /dev/null 2>&1; then
    echo -e "${GREEN}Ping to NAS_IP is successful.${NC}"
else
    echo -e "${RED}Ping to NAS_IP failed.${NC}"
fi

# Create BASE_DIR
echo -e "${BLUE}Creating BASE_DIR: $BASE_DIR${NC}" >&2
mkdir -p "$BASE_DIR"
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to create BASE_DIR. Exiting.${NC}" >&2
    exit 1
fi
echo -e "${GREEN}BASE_DIR created successfully${NC}" >&2

# Copy .env to BASE_DIR
echo -e "${BLUE}Copying .env to $BASE_DIR${NC}" >&2
cp .env "$BASE_DIR/.env"
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to copy .env to BASE_DIR. Exiting.${NC}" >&2
    exit 1
fi
echo -e "${GREEN}.env copied to BASE_DIR successfully${NC}" >&2

# Change to BASE_DIR
cd "$BASE_DIR" || { echo -e "${RED}Failed to change to BASE_DIR. Exiting.${NC}" >&2; exit 1; }

# Download PiHA-Deployer-NodeRED.sh
download_from_github "PiHA-Deployer-NodeRED.sh"

# Download docker-compose.yml
download_from_github "docker-compose.yml"

# Make PiHA-Deployer-NodeRED.sh executable
chmod +x PiHA-Deployer-NodeRED.sh

# Mount NAS share
echo -e "${BLUE}Checking NAS share mount status...${NC}" >&2
echo -e "NAS_IP: '$NAS_IP'"
echo -e "NAS_SHARE_NAME: '$NAS_SHARE_NAME'"
echo -e "NAS_USERNAME: '$NAS_USERNAME'"
echo -e "NAS_MOUNT_DIR: '$NAS_MOUNT_DIR'"

# Check network connectivity
echo -e "${BLUE}Checking network connectivity to NAS...${NC}" >&2
if ping -c 4 "$NAS_IP" > /dev/null 2>&1; then
    echo -e "${GREEN}Network connectivity to NAS is good.${NC}" >&2
else
    echo -e "${RED}Cannot reach NAS using NAS_IP. Please check your network connection.${NC}" >&2
    exit 1
fi

# Check if already mounted
if mount | grep -q "$NAS_MOUNT_DIR"; then
    echo -e "${GREEN}NAS share is already mounted at $NAS_MOUNT_DIR${NC}" >&2
else
    echo -e "${BLUE}NAS share is not mounted. Attempting to mount...${NC}" >&2
    
    # Create mount point if it doesn't exist
    echo "Executing: sudo mkdir -p $NAS_MOUNT_DIR"
    sudo mkdir -p "$NAS_MOUNT_DIR"

    # Displaying variables to ensure correctness
    echo -e "${BLUE}Mount variables:${NC}"
    echo -e "NAS_IP: '$NAS_IP'"
    echo -e "NAS_SHARE_NAME: '$NAS_SHARE_NAME'"
    echo -e "NAS_USERNAME: '$NAS_USERNAME'"
    echo -e "NAS_PASSWORD: '$NAS_PASSWORD'"

    # Attempt to mount
    echo -e "${BLUE}Attempting to mount //${NAS_IP}/${NAS_SHARE_NAME} at $NAS_MOUNT_DIR...${NC}" >&2
    echo "Executing: sudo mount -t cifs -o username=$NAS_USERNAME,password=$NAS_PASSWORD,vers=3.0 //${NAS_IP}/${NAS_SHARE_NAME} $NAS_MOUNT_DIR"
    if ! sudo mount -t cifs -o username=$NAS_USERNAME,password="$NAS_PASSWORD",vers=3.0 //${NAS_IP}/${NAS_SHARE_NAME} "$NAS_MOUNT_DIR"; then
        echo -e "${RED}Mount command failed. Trying without SMB version...${NC}" >&2
        if ! sudo mount -t cifs -o username=$NAS_USERNAME,password="$NAS_PASSWORD" //${NAS_IP}/${NAS_SHARE_NAME} "$NAS_MOUNT_DIR"; then
            echo -e "${RED}Both mount attempts failed. Checking logs...${NC}" >&2
            dmesg | tail -n 20
            echo -e "${RED}Attempting to list shares...${NC}" >&2
            smbclient -L //$NAS_IP -U $NAS_USERNAME
            exit 1
        fi
    fi
fi

# Verify the mount
echo -e "${BLUE}Verifying NAS share mount...${NC}" >&2
if mount | grep -q "$NAS_MOUNT_DIR"; then
    echo -e "${GREEN}NAS share is successfully mounted at $NAS_MOUNT_DIR${NC}" >&2
    echo -e "${BLUE}Contents of $NAS_MOUNT_DIR:${NC}" >&2
    ls -la "$NAS_MOUNT_DIR"
else
    echo -e "${RED}NAS share is not mounted. Something went wrong.${NC}" >&2
    exit 1
fi

# Execute PiHA-Deployer-NodeRED.sh
echo -e "${BLUE}Executing PiHA-Deployer-NodeRED.sh...${NC}" >&2
./PiHA-Deployer-NodeRED.sh

# Cleanup
echo -e "${BLUE}Cleaning up temporary files...${NC}" >&2
rm -f "$HOME/.env"
rm -f "$BASE_DIR/PiHA-Deployer-NodeRED.sh"
echo -e "${GREEN}Cleanup complete${NC}" >&2

echo -e "${GREEN}Installation complete!${NC}" >&2
