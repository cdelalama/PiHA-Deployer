#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Load variables from .env file
if [ -f .env ]; then
    while IFS='=' read -r key value; do
        # Skip empty lines and comments
        if [[ ! -z "$key" && "$key" != \#* ]]; then
            # Remove carriage returns, spaces, and quotes
            key=$(echo "$key" | tr -d '\r' | tr -d '[:space:]')
            value=$(echo "$value" | tr -d '\r' | tr -d '"')
            # Only export if key is valid
            if [[ $key =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                export "$key=$value"
            fi
        fi
    done < .env
else
    echo -e "${RED}❌ .env file not found${NC}"
    exit 1
fi

# Clean up variables (remove carriage returns)
NAS_IP=$(echo "$NAS_IP" | tr -d '\r')
NAS_SHARE_NAME=$(echo "$NAS_SHARE_NAME" | tr -d '\r')
NAS_USERNAME=$(echo "$NAS_USERNAME" | tr -d '\r')
NAS_PASSWORD=$(echo "$NAS_PASSWORD" | tr -d '\r')
NAS_MOUNT_DIR=$(echo "$NAS_MOUNT_DIR" | tr -d '\r')

echo -e "${GREEN}Starting NAS mount diagnosis...${NC}"

# Check if the NAS is reachable
echo "Pinging NAS..."
if ping -c 4 $NAS_IP > /dev/null 2>&1; then
    echo -e "${GREEN}NAS is reachable.${NC}"
else
    echo -e "${RED}Cannot reach NAS. Please check your network connection.${NC}"
    exit 1
fi

# List available shares
echo "Listing available shares..."
smbclient -L //$NAS_IP -U $NAS_USERNAME%$NAS_PASSWORD

# Try to connect to the specific share
echo "Attempting to connect to the share..."
smbclient //$NAS_IP/$NAS_SHARE_NAME -U $NAS_USERNAME%$NAS_PASSWORD -c "exit"

# Create mount point if it doesn't exist
sudo mkdir -p $NAS_MOUNT_DIR

# Attempt to mount
echo "Attempting to mount..."
sudo mount -t cifs //$NAS_IP/$NAS_SHARE_NAME $NAS_MOUNT_DIR -o username=$NAS_USERNAME,password=$NAS_PASSWORD,vers=3.0

# Check if mount was successful
if mount | grep $NAS_MOUNT_DIR > /dev/null; then
    echo -e "${GREEN}Mount successful!${NC}"
else
    echo -e "${RED}Mount failed. Checking error logs...${NC}"
    dmesg | tail -n 20
fi

# Show current mounts
echo "Current mounts:"
mount | grep cifs

echo -e "${GREEN}Diagnosis complete.${NC}"