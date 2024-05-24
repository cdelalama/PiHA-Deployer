#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# NAS details
NAS_IP="10.0.0.220"
NAS_SHARE="piha"
NAS_USER="piha"
NAS_PASS="2BO*MdkYQ%z7x0yjgN\$5"
MOUNT_POINT="/mnt/piha"

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
smbclient -L //$NAS_IP -U $NAS_USER%$NAS_PASS

# Try to connect to the specific share
echo "Attempting to connect to the share..."
smbclient //$NAS_IP/$NAS_SHARE -U $NAS_USER%$NAS_PASS -c "exit"

# Create mount point if it doesn't exist
sudo mkdir -p $MOUNT_POINT

# Attempt to mount
echo "Attempting to mount..."
sudo mount -t cifs //$NAS_IP/$NAS_SHARE $MOUNT_POINT -o username=$NAS_USER,password=$NAS_PASS,vers=3.0

# Check if mount was successful
if mount | grep $MOUNT_POINT > /dev/null; then
    echo -e "${GREEN}Mount successful!${NC}"
else
    echo -e "${RED}Mount failed. Checking error logs...${NC}"
    dmesg | tail -n 20
fi

# Show current mounts
echo "Current mounts:"
mount | grep cifs

echo -e "${GREEN}Diagnosis complete.${NC}"