#!/bin/bash

# Version
VERSION="1.0.19"

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

# Default values
DEFAULT_BASE_DIR="/home/cdelalama/docker_temp_setup"
DEFAULT_USERNAME="cdelalama"
DEFAULT_SAMBA_USER="cdelalama"
DEFAULT_DOCKER_COMPOSE_DIR="/srv/docker"
DEFAULT_PORTAINER_DATA_DIR="/srv/docker/portainer"
DEFAULT_NODE_RED_DATA_DIR="/srv/docker/node-red"
DEFAULT_PORTAINER_PORT="9000"
DEFAULT_NODE_RED_PORT="1880"
DEFAULT_IP="auto"
DEFAULT_NAS_IP=""
DEFAULT_NAS_SHARE_NAME=""
DEFAULT_NAS_USERNAME=""
DEFAULT_NAS_MOUNT_DIR="/mnt/nas_share"
DEFAULT_SYNC_INTERVAL="hourly"

# Function to prompt for a variable
prompt_variable() {
    local var_name=$1
    local default_value=$2
    local is_password=$3

    if [ "$is_password" = true ]; then
        while true; do
            read -s -p "$var_name: " value </dev/tty
            echo >&2
            if [ -z "$value" ]; then
                echo -e "${RED}Error: Password cannot be empty. Please try again.${NC}" >&2
            else
                break
            fi
        done
    else
        read -p "$var_name [$default_value]: " value </dev/tty
        value=${value:-$default_value}
    fi
    echo "$var_name=$value"
}

# Check if .env file already exists
if [ -f ".env" ]; then
    echo -e "${GREEN}Existing .env file found. Using the existing file.${NC}" >&2
else
    echo -e "${BLUE}No existing .env file found. Creating a new one.${NC}" >&2
    echo -e "${BLUE}Please provide values for each variable:${NC}" >&2
    {
        prompt_variable "BASE_DIR" "$DEFAULT_BASE_DIR"
        prompt_variable "USERNAME" "$DEFAULT_USERNAME"
        prompt_variable "SAMBA_USER" "$DEFAULT_SAMBA_USER"
        prompt_variable "SAMBA_PASS" "" true
        prompt_variable "DOCKER_COMPOSE_DIR" "$DEFAULT_DOCKER_COMPOSE_DIR"
        prompt_variable "PORTAINER_DATA_DIR" "$DEFAULT_PORTAINER_DATA_DIR"
        prompt_variable "NODE_RED_DATA_DIR" "$DEFAULT_NODE_RED_DATA_DIR"
        prompt_variable "PORTAINER_PORT" "$DEFAULT_PORTAINER_PORT"
        prompt_variable "NODE_RED_PORT" "$DEFAULT_NODE_RED_PORT"
        prompt_variable "IP" "$DEFAULT_IP"
        prompt_variable "NAS_IP" "$DEFAULT_NAS_IP"
        prompt_variable "NAS_SHARE_NAME" "$DEFAULT_NAS_SHARE_NAME"
        prompt_variable "NAS_USERNAME" "$DEFAULT_NAS_USERNAME"
        prompt_variable "NAS_PASSWORD" "" true
        prompt_variable "NAS_MOUNT_DIR" "$DEFAULT_NAS_MOUNT_DIR"
        prompt_variable "SYNC_INTERVAL" "$DEFAULT_SYNC_INTERVAL"
    } > .env
    echo -e "${GREEN}.env file created successfully${NC}" >&2
fi

# Display the contents of the .env file (excluding the passwords)
echo -e "${BLUE}Contents of .env file:${NC}" >&2
grep -vE 'SAMBA_PASS|NAS_PASSWORD' .env >&2

# Source the .env file to use its variables
source .env

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

# Execute PiHA-Deployer-NodeRED.sh
echo -e "${BLUE}Executing PiHA-Deployer-NodeRED.sh...${NC}" >&2
./PiHA-Deployer-NodeRED.sh

# Cleanup
echo -e "${BLUE}Cleaning up temporary files...${NC}" >&2
rm -f "$HOME/.env"
rm -f "$BASE_DIR/PiHA-Deployer-NodeRED.sh"
echo -e "${GREEN}Cleanup complete${NC}" >&2

echo -e "${GREEN}Installation complete!${NC}" >&2