#!/bin/bash
set -e

# Version
VERSION="1.0.47"

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

# Function to read and export variables from .env file
export_env_vars() {
    echo -e "${BLUE}Reading and exporting environment variables from .env file...${NC}"
    while IFS='=' read -r key value; do
        if [[ ! -z "$key" && "$key" != \#* ]]; then
            key=$(echo "$key" | tr -d '[:space:]')
            value=$(echo "$value" | tr -d '[:space:]' | tr -d '"')
            export "$key=$value"
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
#!/bin/bash
set -e
I apologize for the persistent issue. It seems that the mount point is still not being properly created or accessed. Let's try a different approach and add more debugging information. Here's an updated version of the script:
bashCopy#!/bin/bash
set -e

# Version
VERSION="1.0.47"

# ... (previous code remains the same)

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

# Unmount if already mounted
if mount | grep -q "$NAS_MOUNT_DIR"; then
    echo -e "${YELLOW}NAS share appears to be already mounted at $NAS_MOUNT_DIR. Unmounting...${NC}" >&2
    sudo umount -f "$NAS_MOUNT_DIR" || echo "Failed to unmount, continuing anyway..."
fi

# Remove and recreate mount point
echo -e "${BLUE}Removing and recreating mount point directory...${NC}" >&2
sudo rm -rf "$NAS_MOUNT_DIR"
sudo mkdir -p "$NAS_MOUNT_DIR"
sudo chmod 755 "$NAS_MOUNT_DIR"

echo -e "${BLUE}Attempting to mount NAS share...${NC}" >&2

# Attempt to mount
echo -e "${BLUE}Mounting //${NAS_IP}/${NAS_SHARE_NAME} at $NAS_MOUNT_DIR...${NC}" >&2
MOUNT_CMD="sudo mount -t cifs -o username=\"$NAS_USERNAME\",password=\"$NAS_PASSWORD\",vers=3.0 \"//${NAS_IP}/${NAS_SHARE_NAME}\" \"$NAS_MOUNT_DIR\""
echo "Executing: $MOUNT_CMD"
eval $MOUNT_CMD

# Verify the mount
echo -e "${BLUE}Verifying NAS share mount...${NC}" >&2
if mount | grep -q "$NAS_MOUNT_DIR"; then
    echo -e "${GREEN}NAS share is listed in mount table${NC}" >&2
    if [ -d "$NAS_MOUNT_DIR" ]; then
        echo -e "${GREEN}Mount point directory exists${NC}" >&2
        echo -e "${BLUE}Contents of $NAS_MOUNT_DIR:${NC}" >&2
        sudo ls -la "$NAS_MOUNT_DIR" || echo "Failed to list directory contents"
    else
        echo -e "${RED}Mount point directory does not exist${NC}" >&2
    fi
else
    echo -e "${RED}NAS share is not mounted. Something went wrong.${NC}" >&2
fi

echo -e "${BLUE}Current mounts:${NC}" >&2
mount | grep cifs

echo -e "${BLUE}Permissions of mount point:${NC}" >&2
ls -ld "$NAS_MOUNT_DIR" || echo "Failed to get mount point permissions"

echo -e "${BLUE}Attempting to access a file in the mount:${NC}" >&2
sudo touch "$NAS_MOUNT_DIR/test_file" && echo "Successfully created test file" || echo "Failed to create test file"

# Execute PiHA-Deployer-NodeRED.sh
echo -e "${BLUE}Executing PiHA-Deployer-NodeRED.sh...${NC}" >&2
./PiHA-Deployer-NodeRED.sh

# Cleanup
echo -e "${BLUE}Cleaning up temporary files...${NC}" >&2
rm -f "$HOME/.env"
rm -f "$BASE_DIR/PiHA-Deployer-NodeRED.sh"
echo -e "${GREEN}Cleanup complete${NC}" >&2

echo -e "${GREEN}Installation complete!${NC}" >&2
