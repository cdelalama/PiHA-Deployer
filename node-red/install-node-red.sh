#!/bin/bash

# Version
VERSION="1.0.14"

# Define colors
BLUE='\033[0;36m'  # Lighter blue (cyan)
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}PiHA-Deployer Node-RED Install Script v$VERSION${NC}" >&2
echo -e "${BLUE}Script started${NC}" >&2

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

# ... [rest of the script remains the same until after changing to BASE_DIR] ...

# Download PiHA-Deployer-NodeRED.sh
download_from_github "PiHA-Deployer-NodeRED.sh"

# Download docker-compose.yml
download_from_github "docker-compose.yml"

# Make PiHA-Deployer-NodeRED.sh executable
chmod +x PiHA-Deployer-NodeRED.sh

# Execute PiHA-Deployer-NodeRED.sh
echo -e "${BLUE}Executing PiHA-Deployer-NodeRED.sh...${NC}" >&2
./PiHA-Deployer-NodeRED.sh

echo -e "${GREEN}Installation complete!${NC}" >&2