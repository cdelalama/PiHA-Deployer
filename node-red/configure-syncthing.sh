#!/bin/bash

# Version 1.1.5

# Define colors
BLUE='\033[0;36m'
RED='\033[1;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Load environment variables
source .env

# Function to get Syncthing version and config version
get_syncthing_version() {
    echo -e "${BLUE}Detecting Syncthing version...${NC}"
    local version_info
    version_info=$(docker logs syncthing 2>&1 | grep "syncthing v" | head -n 1)
    if [[ $version_info =~ v([0-9]+\.[0-9]+\.[0-9]+) ]]; then
        echo -e "${GREEN}[OK] Detected Syncthing version: ${BASH_REMATCH[1]}${NC}"
        # Default to config version 37 for current versions
        CONFIG_VERSION="37"

        # Bump CONFIG_VERSION if required for newer versions
        if [[ "${BASH_REMATCH[1]}" > "1.28.0" ]]; then
            CONFIG_VERSION="38"
        fi
        echo -e "${BLUE}Using config version: ${CONFIG_VERSION}${NC}"
        return 0
    else
        echo -e "${RED}[ERROR] Could not detect Syncthing version${NC}"
        return 1
    fi
}

# Wait for Syncthing to generate its ID
echo -e "${BLUE}Waiting for Syncthing to generate device ID...${NC}"
MAX_ATTEMPTS=30
ATTEMPT=0
DEVICE_ID=""

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    DEVICE_ID=$(docker logs syncthing 2>&1 | grep -oP "My ID: \K[A-Z0-9-]+" | head -n 1)
    if [ ! -z "$DEVICE_ID" ]; then
        echo -e "${GREEN}[OK] Device ID obtained: $DEVICE_ID${NC}"
        break
    fi
    sleep 2
    ATTEMPT=$((ATTEMPT + 1))
    echo -n "."
done

if [ -z "$DEVICE_ID" ]; then
    echo -e "${RED}[ERROR] Failed to obtain device ID${NC}"
    exit 1
fi

# Get Syncthing version and set config version
if ! get_syncthing_version; then
    echo -e "${RED}[ERROR] Failed to determine Syncthing version. Using default config version 37${NC}"
    CONFIG_VERSION="37"
fi

# Install apache2-utils if not installed
if ! command -v htpasswd &> /dev/null; then
    echo "Installing apache2-utils for password hashing..."
    sudo apt-get update && sudo apt-get install -y apache2-utils
fi

# Generate bcrypt hash of the password
HASHED_PASSWORD=$(htpasswd -bnBC 10 "" "$SYNCTHING_PASS" | tr -d ':\n')

# Variables required for device configuration
NAS_SYNCTHING_ID=${NAS_SYNCTHING_ID:-""}  # Must be present in .env
NAS_NAME=${NAS_NAME:-"NAS"}               # Must be present in .env

# Replace the configuration block in config.xml
sed -i "/<configuration/,/<\/configuration>/c\\
<?xml version=\"1.0\" encoding=\"utf-8\"?>\\
<configuration version=\"$CONFIG_VERSION\">\\
    <folder id=\"node-red\" label=\"Node-RED Data\" path=\"/data/node-red\" type=\"sendreceive\" rescanIntervalS=\"30\" fsWatcherEnabled=\"true\" fsWatcherDelayS=\"5\" ignorePerms=\"true\" autoNormalize=\"true\">\\
        <filesystemType>basic</filesystemType>\\
        <device id=\"$DEVICE_ID\" introducedBy=\"\"></device>\\
        <device id=\"$NAS_SYNCTHING_ID\" introducedBy=\"\"></device>\\
        <minDiskFree unit=\"%\">1</minDiskFree>\\
        <versioning type=\"simple\">\\
            <param key=\"keep\" value=\"5\"/>\\
        </versioning>\\
        <copyOwnershipFromParent>true</copyOwnershipFromParent>\\
        <ignoreDelete>false</ignoreDelete>\\
        <order>random</order>\\
        <scanProgressIntervalS>0</scanProgressIntervalS>\\
        <pullerPauseS>0</pullerPauseS>\\
        <maxConflicts>10</maxConflicts>\\
        <disableSparseFiles>false</disableSparseFiles>\\
        <disableTempIndexes>false</disableTempIndexes>\\
        <paused>false</paused>\\
        <weakHashThresholdPct>25</weakHashThresholdPct>\\
        <markerName>.stfolder</markerName>\\
        <modTimeWindowS>0</modTimeWindowS>\\
    </folder>\\
    <folder id=\"portainer\" label=\"Portainer Data\" path=\"/data/portainer\" type=\"sendreceive\" rescanIntervalS=\"3600\" fsWatcherEnabled=\"true\" fsWatcherDelayS=\"10\" fsWatcherTimeoutS=\"0\" ignorePerms=\"true\" autoNormalize=\"true\">\\
        <filesystemType>basic</filesystemType>\\
        <device id=\"$DEVICE_ID\" introducedBy=\"\"></device>\\
        <device id=\"$NAS_SYNCTHING_ID\" introducedBy=\"\"></device>\\
        <minDiskFree unit=\"%\">1</minDiskFree>\\
        <copyOwnershipFromParent>false</copyOwnershipFromParent>\\
        <ignoreDelete>false</ignoreDelete>\\
    </folder>\\
    <folder id=\"nas\" label=\"NAS Data\" path=\"/data/nas_data\" type=\"sendreceive\" rescanIntervalS=\"3600\" fsWatcherEnabled=\"true\" fsWatcherDelayS=\"10\" fsWatcherTimeoutS=\"0\" ignorePerms=\"true\" autoNormalize=\"true\">\\
        <filesystemType>basic</filesystemType>\\
        <device id=\"$DEVICE_ID\" introducedBy=\"\"></device>\\
        <device id=\"$NAS_SYNCTHING_ID\" introducedBy=\"\"></device>\\
        <minDiskFree unit=\"%\">1</minDiskFree>\\
        <copyOwnershipFromParent>false</copyOwnershipFromParent>\\
        <ignoreDelete>false</ignoreDelete>\\
    </folder>\\
    <device id=\"$DEVICE_ID\" name=\"syncthing\" compression=\"metadata\" introducer=\"false\" skipIntroductionRemovals=\"false\" introducedBy=\"\">\\
        <address>dynamic</address>\\
        <paused>false</paused>\\
        <autoAcceptFolders>false</autoAcceptFolders>\\
        <maxSendKbps>0</maxSendKbps>\\
        <maxRecvKbps>0</maxRecvKbps>\\
    </device>\\
    <device id=\"$NAS_SYNCTHING_ID\" name=\"$NAS_NAME\" compression=\"metadata\" introducer=\"false\" skipIntroductionRemovals=\"false\" introducedBy=\"\">\\
        <address>tcp://${NAS_IP}:22000</address>\\
        <paused>false</paused>\\
        <autoAcceptFolders>false</autoAcceptFolders>\\
        <maxSendKbps>0</maxSendKbps>\\
        <maxRecvKbps>0</maxRecvKbps>\\
    </device>\\
    <gui enabled=\"true\" tls=\"false\" debugging=\"false\">\\
        <address>0.0.0.0:8384</address>\\
        <apikey>$API_KEY</apikey>\\
        <theme>default</theme>\\
        <user>$SYNCTHING_USER</user>\\
        <password>$HASHED_PASSWORD</password>\\
    </gui>\\
    <options>\\
        <listenAddress>default</listenAddress>\\
        <globalAnnounceEnabled>false</globalAnnounceEnabled>\\
        <localAnnounceEnabled>true</localAnnounceEnabled>\\
        <maxSendKbps>0</maxSendKbps>\\
        <maxRecvKbps>0</maxRecvKbps>\\
        <reconnectionIntervalS>60</reconnectionIntervalS>\\
        <relaysEnabled>false</relaysEnabled>\\
        <startBrowser>false</startBrowser>\\
        <natEnabled>true</natEnabled>\\
        <urAccepted>-1</urAccepted>\\
    </options>\\
</configuration>" "${SYNCTHING_CONFIG_DIR}/config.xml"

# Ensure correct permissions on NAS mount directories
echo "Setting correct permissions on NAS directories..."
sudo chown -R ${DOCKER_USER_ID}:${DOCKER_GROUP_ID} "${NODE_RED_DATA_DIR}"
sudo chown -R ${DOCKER_USER_ID}:${DOCKER_GROUP_ID} "${PORTAINER_DATA_DIR}"
sudo chown -R ${DOCKER_USER_ID}:${DOCKER_GROUP_ID} "${NAS_MOUNT_DIR}/nas_data"

sudo chmod -R 755 "${NODE_RED_DATA_DIR}"
sudo chmod -R 755 "${PORTAINER_DATA_DIR}"
sudo chmod -R 755 "${NAS_MOUNT_DIR}/nas_data"

# Create .stfolder in each directory (required by Syncthing)
sudo -u "#${DOCKER_USER_ID}" mkdir -p "${NODE_RED_DATA_DIR}/.stfolder"
sudo -u "#${DOCKER_USER_ID}" mkdir -p "${PORTAINER_DATA_DIR}/.stfolder"
sudo -u "#${DOCKER_USER_ID}" mkdir -p "${NAS_MOUNT_DIR}/nas_data/.stfolder"

# Ensure Syncthing can access all directories
sudo chown -R ${DOCKER_USER_ID}:${DOCKER_GROUP_ID} "${NODE_RED_DATA_DIR}"
sudo chown -R ${DOCKER_USER_ID}:${DOCKER_GROUP_ID} "${PORTAINER_DATA_DIR}"
sudo chown -R ${DOCKER_USER_ID}:${DOCKER_GROUP_ID} "${SYNCTHING_CONFIG_DIR}"

# Set proper permissions for config file
sudo chmod 600 "${SYNCTHING_CONFIG_DIR}/config.xml"

# Restart Syncthing to apply changes
echo -e "${BLUE}Restarting Syncthing to apply changes...${NC}"
docker restart syncthing

echo -e "${GREEN}[OK] Syncthing configuration completed${NC}"
