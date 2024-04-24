#!/bin/bash

# Version
VERSION="1.0.11"

# Define colors
BLUE='\033[0;36m'  # Lighter blue (cyan)
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}PiHA-Deployer Node-RED Install Script v$VERSION${NC}" >&2
echo -e "${BLUE}Script started${NC}" >&2

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

# Function to prompt for a variable
prompt_variable() {
    local var_name=$1
    local default_value=$2
    local is_password=$3

    if [ "$is_password" = true ]; then
        read -s -p "$var_name: " value </dev/tty
        echo >&2
    else
        read -p "$var_name [$default_value]: " value </dev/tty
        value=${value:-$default_value}
    fi
    echo "$var_name=$value"
}

# Create .env file interactively
echo -e "${BLUE}Creating .env file. Please provide values for each variable:${NC}" >&2
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
} > .env

echo -e "${GREEN}.env file created successfully${NC}" >&2

# Display the contents of the .env file (excluding the password)
echo -e "${BLUE}Contents of .env file:${NC}" >&2
grep -v SAMBA_PASS .env >&2

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

echo -e "${GREEN}Installation setup complete. .env file has been created and copied to $BASE_DIR.${NC}" >&2
echo -e "${BLUE}You can now proceed with the rest of the installation process.${NC}" >&2