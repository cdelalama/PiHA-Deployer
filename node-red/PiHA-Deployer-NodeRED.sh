#!/bin/bash

# Version
VERSION="1.0.33"

# Define colors
BLUE='\033[0;36m'  # Lighter blue (cyan)
RED='\033[1;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${BLUE}PiHA-Deployer Node-RED Installation Script v$VERSION${NC}"
echo -e "${BLUE}===============================================${NC}"

# Function for confirmation prompts
confirm_step() {
    echo -e "${BLUE}🚀 Executing: $1${NC}"
}

# Load variables from .env file
confirm_step "Load environment variables from .env file"
if [ -f .env ]; then
    # Load all variables from .env
    set -a  # Automatically export all variables
    source .env
    set +a

    # Only show confirmation without values
    echo -e "${GREEN}✅ Environment variables loaded successfully${NC}"
else
    echo -e "${RED}❌ .env file not found${NC}"
    exit 1
fi

# Check if required variables are set
confirm_step "Check if all required variables are set in the .env file"
required_vars=(
    BASE_DIR 
    DOCKER_USER_ID 
    DOCKER_GROUP_ID 
    SAMBA_USER 
    SAMBA_PASS 
    DOCKER_COMPOSE_DIR 
    PORTAINER_DATA_DIR 
    NODE_RED_DATA_DIR 
    SYNCTHING_CONFIG_DIR 
    PORTAINER_PORT 
    NODE_RED_PORT 
    IP 
    NAS_IP 
    NAS_SHARE_NAME 
    NAS_USERNAME 
    NAS_PASSWORD 
    NAS_MOUNT_DIR 
    SYNC_INTERVAL 
    SYNCTHING_USER 
    SYNCTHING_PASS
    PORTAINER_PASS
)

# Verify all required variables are set
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo -e "${RED}❌ Required variable $var is not set in .env${NC}"
        exit 1
    fi  
done
echo -e "${GREEN}✅ All required variables are set${NC}"

# Verificar y obtener IP (mover aquí)
echo -e "${BLUE}Verifying IP address...${NC}"
if [ "$IP" = "auto" ]; then
    IP=$(hostname -I | awk '{print $1}')
    echo -e "${BLUE}Auto-detected IP: $IP${NC}"
fi

if [[ ! $IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}❌ Could not determine valid IP address. Got: $IP${NC}"
    exit 1
fi
echo -e "${GREEN}✅ IP address verified: $IP${NC}"

# Create Portainer password file
echo -e "${BLUE}Creating Portainer password file...${NC}"
PORTAINER_PASS_FILE="${DOCKER_COMPOSE_DIR}/portainer_password.txt"
sudo mkdir -p "${DOCKER_COMPOSE_DIR}"
echo "${PORTAINER_PASS}" | sudo tee "${PORTAINER_PASS_FILE}" > /dev/null
sudo chmod 600 "${PORTAINER_PASS_FILE}"
sudo chown "${DOCKER_USER_ID}:${DOCKER_GROUP_ID}" "${PORTAINER_PASS_FILE}"

# Create directories and set permissions
confirm_step "Create necessary directories and set permissions"
echo -e "${BLUE}Creating directories and setting permissions...${NC}"

# Create all required directories
sudo mkdir -p "$DOCKER_COMPOSE_DIR" \
             "$PORTAINER_DATA_DIR" \
             "$NODE_RED_DATA_DIR" \
             "$SYNCTHING_CONFIG_DIR/config" \
             "$SYNCTHING_CONFIG_DIR/data/node-red" \
             "$SYNCTHING_CONFIG_DIR/data/portainer" \
             "$SYNCTHING_CONFIG_DIR/data/nas_data" \
             "$NAS_MOUNT_DIR"

# Create .stfolder directories with correct permissions (solo una vez)
for dir in "node-red" "portainer" "nas_data"; do
    sudo mkdir -p "$SYNCTHING_CONFIG_DIR/data/$dir/.stfolder"
done

# Set permissions once
sudo chown -R "${DOCKER_USER_ID}:${DOCKER_GROUP_ID}" "$PORTAINER_DATA_DIR" "$NODE_RED_DATA_DIR" "$SYNCTHING_CONFIG_DIR" "$NAS_MOUNT_DIR"
sudo chmod -R 775 "$PORTAINER_DATA_DIR" "$NODE_RED_DATA_DIR" "$SYNCTHING_CONFIG_DIR" "$NAS_MOUNT_DIR"

echo -e "${GREEN}Directories created and permissions set successfully${NC}"

# Copy .env to DOCKER_COMPOSE_DIR
confirm_step "Copy .env file to Docker Compose directory"
sudo cp .env "$DOCKER_COMPOSE_DIR/.env"

# Set proper permissions
sudo chown -R "${DOCKER_USER_ID}:${DOCKER_GROUP_ID}" "$SYNCTHING_CONFIG_DIR"

# Start Docker containers
confirm_step "Start Docker containers (Portainer and Node-RED)"
echo -e "${BLUE}Starting Docker containers...${NC}"

# Check if docker-compose exists
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ docker-compose not found. Please install Docker Compose first.${NC}"
    exit 1
fi

# Check if docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}❌ Docker daemon is not running. Please start Docker first.${NC}"
    exit 1
fi

# Attempt to start containers
if ! sudo -E docker-compose -f "${BASE_DIR}/docker-compose.yml" up -d; then
    echo -e "${RED}❌ Failed to start Docker containers. Checking logs...${NC}"
    sudo docker-compose -f "${BASE_DIR}/docker-compose.yml" logs
    echo -e "${RED}❌ Please check the logs above for errors.${NC}"
    exit 1
fi

# Verify containers are running
echo -e "${BLUE}Verifying containers status...${NC}"
if ! docker ps | grep -q "portainer" || ! docker ps | grep -q "node-red"; then
    echo -e "${RED}❌ One or more containers failed to start. Container status:${NC}"
    docker ps -a
    exit 1
fi

# Configuración de Syncthing
confirm_step "Configure Syncthing with authentication"

# Iniciar Syncthing
echo "Starting Syncthing container..."
sudo docker-compose -f "${BASE_DIR}/docker-compose.yml" up -d syncthing

# Función para verificar si Syncthing está listo
check_syncthing_ready() {
    local config_file="$SYNCTHING_CONFIG_DIR/config.xml"
    
    echo -e "\nChecking Syncthing status:"
    echo "- Config file: $config_file"
    
    if [ -f "$config_file" ]; then
        echo "- Config file exists"
        if [ -s "$config_file" ]; then
            echo "- Config file has content"
            if grep -q "<configuration" "$config_file" 2>/dev/null; then
                echo "- Config file is valid XML"
                if nc -z localhost 8384; then
                    echo "- Port 8384 is responding"
                    return 0
                else
                    echo "- Port 8384 is not responding"
                fi
            else
                echo "- Config file is not valid XML"
            fi
        else
            echo "- Config file is empty"
        fi
    else
        echo "- Config file does not exist"
    fi
    return 1
}

# Esperar a que Syncthing esté listo
echo "Waiting for Syncthing to be ready..."
MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if check_syncthing_ready; then
        echo -e "${GREEN}✅ Syncthing is ready${NC}"
        break
    fi
    sleep 2
    ATTEMPT=$((ATTEMPT + 1))
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo -e "\n${RED}❌ Timeout waiting for Syncthing${NC}"
    echo -e "${BLUE}📋 Debugging information:${NC}"
    docker logs --tail 20 syncthing
    ls -la "$SYNCTHING_CONFIG_DIR"
    exit 1
fi

# Dar un pequeño tiempo adicional para asegurar estabilidad
sleep 5

# Espera a que se genere el archivo config.xml con timeout
echo "Waiting for config.xml to be generated..."
TIMEOUT=60
COUNTER=0
while [ ! -f "$SYNCTHING_CONFIG_DIR/config.xml" ]; do
    sleep 1
    COUNTER=$((COUNTER + 1))
    if [ $COUNTER -ge $TIMEOUT ]; then
        echo -e "${RED}❌ Timeout waiting for config.xml to be generated${NC}"
        echo -e "${RED}❌ Please check Syncthing logs: docker logs syncthing${NC}"
        exit 1
    fi
    echo -n "."
done
echo # Nueva línea después de los puntos

# Espera adicional para asegurar que el archivo está completamente escrito
sleep 5

# Detén Syncthing para modificar el archivo config.xml
echo "Stopping Syncthing to modify config..."
sudo docker-compose -f "${BASE_DIR}/docker-compose.yml" stop syncthing || {
    echo -e "${RED}❌ Failed to stop Syncthing${NC}"
    exit 1
}

# Instalar apache2-utils si no está instalado
if ! command -v htpasswd &> /dev/null; then
    echo "Installing apache2-utils for password hashing..."
    sudo apt-get update && sudo apt-get install -y apache2-utils
fi

# Generar hash bcrypt de la contraseña
HASHED_PASSWORD=$(htpasswd -bnBC 10 "" "$SYNCTHING_PASS" | tr -d ':\n')

# Debug - Verificar que el hash tiene el formato correcto
echo "Debug - Password hash format check:"
if [[ $HASHED_PASSWORD == '$2a$'* ]] || [[ $HASHED_PASSWORD == '$2y$'* ]]; then
    echo "✅ Hash format is correct"
else
    echo "❌ Hash format is incorrect"
    exit 1
fi

# Modificar el archivo config.xml
sed -i '/<configuration/,/<\/configuration>/ c\
<configuration version="37">\
<folder id="default" label="Default Folder" path="/data/node-red" type="sendreceive" rescanIntervalS="3600" fsWatcherEnabled="true" fsWatcherDelayS="10" fsWatcherTimeoutS="0" ignorePerms="false" autoNormalize="true">\
    <filesystemType>basic</filesystemType>\
    <device id="'"$DEVICE_ID"'" introducedBy="">\
        <encryptionPassword/>\
    </device>\
    <minDiskFree unit="%">1</minDiskFree>\
    <versioning>\
        <cleanupIntervalS>3600</cleanupIntervalS>\
        <fsPath/>\
        <fsType>basic</fsType>\
    </versioning>\
</folder>\
<folder id="portainer" label="Portainer Data" path="/data/portainer" type="sendreceive" rescanIntervalS="3600" fsWatcherEnabled="true" fsWatcherDelayS="10" fsWatcherTimeoutS="0" ignorePerms="false" autoNormalize="true">\
    <filesystemType>basic</filesystemType>\
    <device id="'"$DEVICE_ID"'" introducedBy="">\
        <encryptionPassword/>\
    </device>\
    <minDiskFree unit="%">1</minDiskFree>\
</folder>\
<folder id="nas" label="NAS Data" path="/data/nas_data" type="sendreceive" rescanIntervalS="3600" fsWatcherEnabled="true" fsWatcherDelayS="10" fsWatcherTimeoutS="0" ignorePerms="false" autoNormalize="true">\
    <filesystemType>basic</filesystemType>\
    <device id="'"$DEVICE_ID"'" introducedBy="">\
        <encryptionPassword/>\
    </device>\
    <minDiskFree unit="%">1</minDiskFree>\
</folder>\
<device id="'"$DEVICE_ID"'" name="syncthing" compression="metadata" introducer="false" skipIntroductionRemovals="false" introducedBy="">\
    <address>dynamic</address>\
    <paused>false</paused>\
    <autoAcceptFolders>false</autoAcceptFolders>\
</device>\
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

# Reinicia Syncthing con la configuración actualizada
sudo docker-compose -f "${BASE_DIR}/docker-compose.yml" up -d syncthing

# Limpieza de archivos temporales
confirm_step "Clean up temporary files for security"
cd ~
sudo rm -rf $BASE_DIR

# Mensaje final unificado (único lugar con todos los mensajes de estado)
echo -e "\n${GREEN}🎉 Setup complete!${NC}"
echo -e "\n${BLUE}📝 Summary of services:${NC}"
echo -e "${BLUE}🌐 Portainer: http://$IP:$PORTAINER_PORT${NC}"
echo -e "${BLUE}🔴 Node-RED: http://$IP:$NODE_RED_PORT${NC}"
echo -e "${BLUE}🔄 Syncthing: http://$IP:8384${NC}"
echo -e "${BLUE}📁 Samba share: \\\\$IP\\docker${NC}"
echo -e "${BLUE}👤 Samba username: $SAMBA_USER${NC}"
echo -e "${BLUE}🔑 Syncthing credentials: ${SYNCTHING_USER}${NC}"

echo -e "\n${BLUE}ℹ️  Additional Information:${NC}"
echo -e "${BLUE}- Data sync interval: ${SYNC_INTERVAL}${NC}"
echo -e "${BLUE}- Docker logs: 'docker logs portainer' or 'docker logs node-red'${NC}"
echo -e "${BLUE}- Log out and log back in if you experience permission issues${NC}"
