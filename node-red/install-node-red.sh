#!/bin/bash
set -e

# Version
VERSION="1.0.66"

# Define colors
BLUE='\033[0;36m'  # Lighter blue (cyan)
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to clean up existing installations
cleanup_existing() {
    echo -e "${BLUE}Cleaning up existing installations...${NC}"
    
    # Check if Docker is installed and running
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        echo "Stopping and removing existing containers..."
        docker-compose down 2>/dev/null || true
        docker rm -f portainer node-red syncthing 2>/dev/null || true
        
        echo "Pruning Docker system..."
        docker system prune -f 2>/dev/null || true
    fi
    
    # Clean up directories if they exist
    if [ -d "/srv/docker" ]; then
        echo "Cleaning up /srv/docker directory..."
        sudo rm -rf /srv/docker/* 2>/dev/null || true
    fi
    
    # Recreate directories with proper permissions
    echo "Creating fresh directories..."
    sudo mkdir -p /srv/docker/portainer /srv/docker/node-red /srv/docker/syncthing
    sudo chown -R 1000:1000 /srv/docker/node-red
    sudo chown -R 1000:1000 /srv/docker/portainer
    sudo chown -R 1000:1000 /srv/docker/syncthing
    
    echo -e "${GREEN}Cleanup completed successfully${NC}"
}

# Add this after version and before starting the main script
echo -e "${BLUE}PiHA-Deployer Node-RED Install Script v$VERSION${NC}"
echo "Script started"

# Ask for cleanup with countdown and default to "Y"
echo -e "${BLUE}🤔 Do you want to clean up any existing installations? (Y/n)${NC}"
echo -n "Automatically continuing with 'Y' in "

# Initialize cleanup_choice
cleanup_choice=""

# Start countdown with input check
for i in {5..1}; do
    echo -n "$i... "
    if read -t 1 -n 1 input; then
        # Accept Enter (empty input) or Y/y/N/n
        if [[ -z "$input" || "$input" =~ ^[YyNn]$ ]]; then
            cleanup_choice="${input:-y}"  # Use 'y' if input is empty (Enter key)
            echo # New line after input
            break
        fi
    fi
done

# If no valid input received, default to "y"
if [[ ! "$cleanup_choice" =~ ^[YyNn]$ ]]; then
    cleanup_choice="y"
    echo # New line after countdown
    echo "No valid input received, using default: Yes"
fi

# Perform cleanup if choice is "y"
if [[ "$cleanup_choice" =~ ^[Yy]$ ]]; then
    cleanup_existing
fi

# Install necessary packages
echo -e "${BLUE}Installing necessary packages...${NC}" >&2
sudo apt-get update
sudo apt-get install -y smbclient cifs-utils

# GitHub repository details
REPO_OWNER="cdelalama"
REPO_NAME="PiHA-Deployer"
BRANCH="main"

# Function to get version from file
get_version() {
    local file=$1
    local version=$(grep "^VERSION=" "$file" | cut -d'"' -f2)
    echo "$version"
}

# Function to download a file from GitHub
download_from_github() {
    local file=$1
    local temp_file="/tmp/${file}"
    
    # If file exists locally
    if [ -f "$file" ]; then
        # Get local version
        local local_version=$(get_version "$file")
        
        # Download to temp file to compare
        curl -sSL -o "$temp_file" "https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$BRANCH/node-red/$file" || {
            echo -e "${GREEN}Using existing local file (version $local_version): $file${NC}" >&2
            rm -f "$temp_file"
            return 0
        }
        
        # Get remote version
        local remote_version=$(get_version "$temp_file")
        
        # Compare versions
        if [[ "$(printf '%s\n' "$remote_version" "$local_version" | sort -V | tail -n1)" == "$local_version" ]]; then
            echo -e "${GREEN}Local version ($local_version) is newer than or equal to remote ($remote_version), using local${NC}" >&2
            rm -f "$temp_file"
            return 0
        else
            mv "$temp_file" "$file"
            echo -e "${BLUE}Downloaded newer version ($remote_version) of $file${NC}" >&2
        fi
    else
        # File doesn't exist locally, download it
        local url="https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$BRANCH/node-red/$file"
        echo -e "${BLUE}Downloading $file from GitHub...${NC}" >&2
        curl -sSL -o "$file" "$url"
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to download $file. Exiting.${NC}" >&2
            exit 1
        fi
        local version=$(get_version "$file")
        echo -e "${GREEN}$file downloaded successfully (version $version)${NC}" >&2
    fi
}

# Function to read and export variables from .env file
export_env_vars() {
    echo -e "${BLUE}Reading and exporting environment variables from .env file...${NC}"
    while IFS='=' read -r key value; do
        # Skip empty lines and comments
        if [[ ! -z "$key" && ! "$key" =~ ^[[:space:]]*# ]]; then
            # Remove leading/trailing whitespace and quotes
            key=$(echo "$key" | tr -d '\r' | xargs)
            value=$(echo "$value" | tr -d '\r' | tr -d '"' | xargs)
            # Export and verify
            export "$key=$value"
            # Special handling for SAMBA_PASS
            if [ "$key" = "SAMBA_PASS" ]; then
                echo "Exported SAMBA_PASS with length: ${#value} characters"
            else
                echo "Exported: $key=$value"
            fi
        fi
    done < .env

    # Debug: show all exported variables
    echo -e "${BLUE}All environment variables:${NC}"
    env | grep -v "SAMBA_PASS" | sort
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

# Check NAS connectivity
echo -e "${BLUE}Checking NAS connectivity...${NC}"
echo "Pinging NAS with IP: $NAS_IP"
if ping -c 4 "$NAS_IP" > /dev/null 2>&1; then
    echo -e "${GREEN}Ping to NAS is successful.${NC}"
else
    echo -e "${RED}Ping to NAS failed. Please check your network connection and NAS_IP in .env${NC}"
    exit 1
fi

# Create BASE_DIR
echo -e "${BLUE}Creating BASE_DIR: $BASE_DIR${NC}" >&2
mkdir -p "$BASE_DIR"
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to create BASE_DIR. Exiting.${NC}" >&2
    exit 1
fi
echo -e "${GREEN}BASE_DIR created successfully${NC}" >&2

# Copy .env to BASE_DIR (only if not already in BASE_DIR)
if [ "$(pwd)" != "$BASE_DIR" ]; then
    echo -e "${BLUE}Copying .env to $BASE_DIR${NC}" >&2
    cp .env "$BASE_DIR/.env"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to copy .env to BASE_DIR. Exiting.${NC}" >&2
        exit 1
    fi
    echo -e "${GREEN}.env copied to BASE_DIR successfully${NC}" >&2
else
    echo -e "${GREEN}.env already in correct directory${NC}" >&2
fi

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
if ! sudo mount -t cifs -o username="$NAS_USERNAME",password="$NAS_PASSWORD",vers=3.0,iocharset=utf8,file_mode=0777,dir_mode=0777 "//${NAS_IP}/${NAS_SHARE_NAME}" "$NAS_MOUNT_DIR"; then
    echo -e "${RED}Mount failed. Trying without SMB version...${NC}" >&2
    if ! sudo mount -t cifs -o username="$NAS_USERNAME",password="$NAS_PASSWORD",iocharset=utf8,file_mode=0777,dir_mode=0777 "//${NAS_IP}/${NAS_SHARE_NAME}" "$NAS_MOUNT_DIR"; then
        echo -e "${RED}Both mount attempts failed. Checking logs...${NC}" >&2
        dmesg | tail -n 20
        exit 1
    fi
fi

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
chmod +x PiHA-Deployer-NodeRED.sh
./PiHA-Deployer-NodeRED.sh

# Only clean up if the deployment was successful
if [ $? -eq 0 ]; then
    echo -e "${BLUE}Cleaning up temporary files...${NC}" >&2
    rm -f "$HOME/.env"
    rm -f "$BASE_DIR/PiHA-Deployer-NodeRED.sh"
    echo -e "${GREEN}Cleanup complete${NC}" >&2
else
    echo -e "${RED}Deployment failed, keeping files for troubleshooting${NC}" >&2
    exit 1
fi

echo -e "${GREEN}Installation complete!${NC}" >&2
