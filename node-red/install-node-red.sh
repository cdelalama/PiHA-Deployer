#!/bin/bash
set -e

# Version
VERSION="1.0.67"

# Define colors
BLUE='\033[0;36m'  # Lighter blue (cyan)
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to announce major steps
announce_step() {
    echo -e "${BLUE}� Executing: $1${NC}"
}
export -f announce_step

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

    echo -e "${BLUE}Checking for updates to $file...${NC}" >&2

    # If file exists locally
    if [ -f "$file" ]; then
        local local_version=$(get_version "$file")

        # Try to get GitHub version
        if ! curl -sSL -o "$temp_file" "https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$BRANCH/node-red/$file"; then
            echo -e "${GREEN}✓ Using local $file${NC}" >&2
            [ ! -z "$local_version" ] && echo -e "${BLUE}Version: $local_version${NC}" >&2
            rm -f "$temp_file"
            return 0
        fi

        local remote_version=$(get_version "$temp_file")

        # Compare versions if both exist
        if [ ! -z "$local_version" ] && [ ! -z "$remote_version" ]; then
            if [[ "$(printf '%s\n' "$remote_version" "$local_version" | sort -V | tail -n1)" == "$local_version" ]]; then
                echo -e "${GREEN}✓ Local version is up to date ($local_version)${NC}" >&2
                rm -f "$temp_file"
                return 0
            else
                echo -e "${BLUE}↑ Updating from $local_version to $remote_version${NC}" >&2
                mv "$temp_file" "$file"
            fi
        else
            echo -e "${BLUE}↑ Updating to latest version${NC}" >&2
            mv "$temp_file" "$file"
        fi
    else
        echo -e "${BLUE}⤓ Downloading $file...${NC}" >&2
        if ! curl -sSL -o "$file" "https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$BRANCH/node-red/$file"; then
            echo -e "${RED}✗ Download failed${NC}" >&2
            exit 1
        fi
        echo -e "${GREEN}✓ Download complete${NC}" >&2
    fi
}

# Function to read and export variables from .env file
export_env_vars() {
    echo -e "${BLUE}Reading and exporting environment variables from .env file...${NC}"

    # Verificar que el archivo existe
    if [ ! -f .env ]; then
        echo -e "${RED}❌ .env file not found${NC}"
        echo -e "${RED}Please create a .env file with the required variables${NC}"
        exit 1
    fi

    # Ensure .env file has correct permissions
    chmod 600 .env

    # Activar el modo de exportación automática
    set -a

    while IFS='=' read -r key value; do
        # Skip empty lines and comments
        if [[ ! -z "$key" && ! "$key" =~ ^[[:space:]]*# ]]; then
            # Remove leading/trailing whitespace and quotes
            key=$(echo "$key" | tr -d '\r' | xargs)
            value=$(echo "$value" | tr -d '\r' | tr -d '"' | xargs)

            # Export variable
            export "${key}=${value}"

            # Debug: Verificar que la variable se exportó correctamente
            if [ -z "${!key}" ]; then
                echo -e "${RED}Warning: Variable $key might not be set correctly${NC}"
            fi
        fi
    done < .env

    # Desactivar el modo de exportación automática
    set +a

    echo -e "${GREEN}✅ Environment variables loaded successfully${NC}"

    # Debug: Mostrar todas las variables requeridas
    echo -e "${BLUE}Debugging environment variables:${NC}"
    for var in "${required_vars[@]}"; do
        echo "$var = ${!var}"
    done
}

# Export environment variables
export_env_vars

# Verify NAS connectivity and parameters
  echo -e "${BLUE}Verifying NAS connection parameters...${NC}"
echo -e "NAS IP: '$NAS_IP'"
echo -e "NAS Share: '$NAS_SHARE_NAME'"
echo -e "NAS Username: '$NAS_USERNAME'"
echo -e "Mount Point: '$NAS_MOUNT_DIR'"

echo -e "${BLUE}Checking NAS connectivity...${NC}"
if ping -c 4 "$NAS_IP" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Network connectivity to NAS is good${NC}"
else
    echo -e "${RED}❌ Cannot reach NAS using NAS_IP. Please check your network connection${NC}"
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

# Handle NAS mount
echo -e "${BLUE}Handling NAS mount...${NC}" >&2

# Check current mount status
if mount | grep -q "$NAS_MOUNT_DIR"; then
    # Check if it's our NAS share
    current_mount=$(mount | grep "$NAS_MOUNT_DIR" | grep "$NAS_IP")
    if [ ! -z "$current_mount" ]; then
        echo -e "${BLUE}Found existing mount from our NAS, refreshing...${NC}" >&2
        sudo umount -f "$NAS_MOUNT_DIR" || {
            echo -e "${RED}Failed to unmount existing NAS share. Please check if it's in use.${NC}" >&2
            exit 1
        }
    else
        echo -e "${RED}Mount point $NAS_MOUNT_DIR is already in use by another mount.${NC}" >&2
        echo -e "${RED}Please choose a different mount point or unmount it manually.${NC}" >&2
        exit 1
    fi
fi

# Prepare mount point (only if it doesn't exist or we just unmounted our NAS)
if [ ! -d "$NAS_MOUNT_DIR" ] || [ ! -z "$current_mount" ]; then
    echo -e "${BLUE}Preparing mount point...${NC}" >&2
    sudo mkdir -p "$NAS_MOUNT_DIR"
    sudo chmod 755 "$NAS_MOUNT_DIR"
fi

# Mount NAS share
echo -e "${BLUE}Mounting NAS share...${NC}" >&2
sudo systemctl daemon-reload

# Try mounting with SMB 3.0 first
if ! sudo mount -t cifs -o username="$NAS_USERNAME",password="$NAS_PASSWORD",vers=3.0,iocharset=utf8,file_mode=0777,dir_mode=0777 "//${NAS_IP}/${NAS_SHARE_NAME}" "$NAS_MOUNT_DIR"; then
    echo -e "${RED}Mount with SMB 3.0 failed. Trying without version specification...${NC}" >&2

    # If SMB 3.0 fails, try without version
    if ! sudo mount -t cifs -o username="$NAS_USERNAME",password="$NAS_PASSWORD",iocharset=utf8,file_mode=0777,dir_mode=0777 "//${NAS_IP}/${NAS_SHARE_NAME}" "$NAS_MOUNT_DIR"; then
        echo -e "${RED}Both mount attempts failed. Checking system logs...${NC}" >&2
        dmesg | tail -n 20
        exit 1
    fi
fi

# Verify mount was successful
if ! mountpoint -q "$NAS_MOUNT_DIR"; then
    echo -e "${RED}Mount verification failed. Share is not mounted.${NC}" >&2
    exit 1
fi

echo -e "${GREEN}✅ NAS share mounted successfully${NC}" >&2

# Starting second phase of installation
echo -e "\n${BLUE}=========================================${NC}"
echo -e "${BLUE} Starting PiHA-Deployer deployment phase${NC}"
echo -e "${BLUE}This will:${NC}"
echo -e "${BLUE}1. Configure Docker containers${NC}"
echo -e "${BLUE}2. Set up Node-RED and Portainer${NC}"
echo -e "${BLUE}3. Configure Syncthing for data sync${NC}"
echo -e "${BLUE}4. Set up Samba sharing${NC}"
echo -e "${BLUE}=========================================${NC}\n"

echo -e "${BLUE}Executing PiHA-Deployer-NodeRED.sh...${NC}" >&2
chmod +x PiHA-Deployer-NodeRED.sh
./PiHA-Deployer-NodeRED.sh

# Clean up silently
rm -f "$HOME/.env" >/dev/null 2>&1

echo -e "${GREEN}Installation complete!${NC}" >&2
