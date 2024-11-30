#!/bin/bash

# Version 1.0.5

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
        echo -e "${GREEN}✅ Detected Syncthing version: ${BASH_REMATCH[1]}${NC}"
        # Por defecto usamos versión 37 para versiones actuales
        CONFIG_VERSION="37"

        # Comparar versión y ajustar CONFIG_VERSION según sea necesario
        if [[ "${BASH_REMATCH[1]}" > "1.28.0" ]]; then
            CONFIG_VERSION="38"
        fi
        echo -e "${BLUE}Using config version: ${CONFIG_VERSION}${NC}"
        return 0
    else
        echo -e "${RED}❌ Could not detect Syncthing version${NC}"
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
        echo -e "${GREEN}✅ Device ID obtained: $DEVICE_ID${NC}"
        break
    fi
    sleep 2
    ATTEMPT=$((ATTEMPT + 1))
    echo -n "."
done

if [ -z "$DEVICE_ID" ]; then
    echo -e "${RED}❌ Failed to obtain device ID${NC}"
    exit 1
fi

# Get Syncthing version and set config version
if ! get_syncthing_version; then
    echo -e "${RED}❌ Failed to determine Syncthing version. Using default config version 37${NC}"
    CONFIG_VERSION="37"
fi

# Instalar apache2-utils si no está instalado
if ! command -v htpasswd &> /dev/null; then
    echo "Installing apache2-utils for password hashing..."
    sudo apt-get update && sudo apt-get install -y apache2-utils
fi

# Generar hash bcrypt de la contraseña
HASHED_PASSWORD=$(htpasswd -bnBC 10 "" "$SYNCTHING_PASS" | tr -d ':\n')

# Modificar el archivo config.xml
sed -i '/<configuration/,/<\/configuration>/ c\
<configuration version="'"$CONFIG_VERSION"'">\
<folder id="default" label="Default Folder" path="/data/node-red" type="sendreceive" rescanIntervalS="3600" fsWatcherEnabled="true" fsWatcherDelayS="10" fsWatcherTimeoutS="0" ignorePerms="false" autoNormalize="true">\
    <filesystemType>basic</filesystemType>\
    <device id="'"$DEVICE_ID"'" introducedBy=""></device>\
    <minDiskFree unit="%">1</minDiskFree>\
    <versioning>\
        <cleanupIntervalS>3600</cleanupIntervalS>\
        <fsPath/>\
        <fsType>basic</fsType>\
    </versioning>\
</folder>\
<folder id="portainer" label="Portainer Data" path="/data/portainer" type="sendreceive" rescanIntervalS="3600" fsWatcherEnabled="true" fsWatcherDelayS="10" fsWatcherTimeoutS="0" ignorePerms="false" autoNormalize="true">\
    <filesystemType>basic</filesystemType>\
    <device id="'"$DEVICE_ID"'" introducedBy=""></device>\
    <minDiskFree unit="%">1</minDiskFree>\
</folder>\
<folder id="nas" label="NAS Data" path="/data/nas_data" type="sendreceive" rescanIntervalS="3600" fsWatcherEnabled="true" fsWatcherDelayS="10" fsWatcherTimeoutS="0" ignorePerms="false" autoNormalize="true">\
    <filesystemType>basic</filesystemType>\
    <device id="'"$DEVICE_ID"'" introducedBy=""></device>\
    <minDiskFree unit="%">1</minDiskFree>\
</folder>\
<gui enabled="true" tls="false" debugging="false" sendBasicAuthPrompt="true" insecureAdminAccess="true">\
    <address>0.0.0.0:8384</address>\
    <user>'"$SYNCTHING_USER"'</user>\
    <password>'"$HASHED_PASSWORD"'</password>\
    <theme>default</theme>\
    <insecureSkipHostcheck>true</insecureSkipHostcheck>\
    <insecureAllowFrameLoading>true</insecureAllowFrameLoading>\
</gui>\
<options>\
    <listenAddress>default</listenAddress>\
    <globalAnnounceEnabled>false</globalAnnounceEnabled>\
    <localAnnounceEnabled>true</localAnnounceEnabled>\
    <relaysEnabled>false</relaysEnabled>\
    <startBrowser>false</startBrowser>\
    <natEnabled>true</natEnabled>\
    <urAccepted>-1</urAccepted>\
    <urSeen>-1</urSeen>\
    <crashReportingEnabled>false</crashReportingEnabled>\
    <usageReportingEnabled>false</usageReportingEnabled>\
    <autoUpgradeIntervalH>0</autoUpgradeIntervalH>\
    <upgradeToPreReleases>false</upgradeToPreReleases>\
</options>\
</configuration>' "$SYNCTHING_CONFIG_DIR/config.xml"

# Set proper permissions
sudo chown -R ${DOCKER_USER_ID}:${DOCKER_GROUP_ID} "${SYNCTHING_CONFIG_DIR}"
sudo chmod 600 "${SYNCTHING_CONFIG_DIR}/config.xml"

# Restart Syncthing to apply changes
echo -e "${BLUE}Restarting Syncthing to apply changes...${NC}"
docker restart syncthing

echo -e "${GREEN}✅ Syncthing configuration completed${NC}"