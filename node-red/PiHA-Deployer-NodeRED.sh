#!/bin/bash

# Define colors
BLUE='\033[0;36m'  # Lighter blue (cyan)
RED='\033[1;31m'
NC='\033[0m' # No Color

# Ask user if they want to be prompted for each step
echo -e "${BLUE}🤔 Do you want to be prompted for each step? (y/n)${NC}"
read -r prompt_choice

# Function for confirmation prompts
confirm_step() {
    if [ "$prompt_choice" = "y" ] || [ "$prompt_choice" = "Y" ]; then
        echo -e "${BLUE}📌 Next step: $1${NC}"
        echo -n "Press ENTER to continue or wait 10 seconds for automatic continuation..."
        read -t 10
        echo
    else
        echo -e "${BLUE}🚀 Executing: $1${NC}"
    fi
}

# Load variables from .env file
confirm_step "Load environment variables from .env file"
if [ -f .env ]; then
    export $(cat .env | xargs)
else
    echo -e "${RED}❌ .env file not found. Please create it with all required variables.${NC}"
    exit 1
fi

# Clean up variables (remove carriage returns)
USERNAME=$(echo "$USERNAME" | tr -d '\r')
SAMBA_USER=$(echo "$SAMBA_USER" | tr -d '\r')
SAMBA_PASS=$(echo "$SAMBA_PASS" | tr -d '\r')
BASE_DIR=$(echo "$BASE_DIR" | tr -d '\r')
DOCKER_COMPOSE_DIR=$(echo "$DOCKER_COMPOSE_DIR" | tr -d '\r')
PORTAINER_DATA_DIR=$(echo "$PORTAINER_DATA_DIR" | tr -d '\r')
NODE_RED_DATA_DIR=$(echo "$NODE_RED_DATA_DIR" | tr -d '\r')
PORTAINER_PORT=$(echo "$PORTAINER_PORT" | tr -d '\r')
NODE_RED_PORT=$(echo "$NODE_RED_PORT" | tr -d '\r')
IP=$(echo "$IP" | tr -d '\r')

# Check if required variables are set
confirm_step "Check if all required variables are set in the .env file"
required_vars=(BASE_DIR USERNAME SAMBA_USER SAMBA_PASS DOCKER_COMPOSE_DIR PORTAINER_DATA_DIR NODE_RED_DATA_DIR PORTAINER_PORT NODE_RED_PORT IP)
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo -e "${RED}❌ $var is not set in .env file${NC}"
        exit 1
    fi
done

# Handle automatic IP detection if set to 'auto'
confirm_step "Detect IP address if set to 'auto'"
if [ "$IP" = "auto" ]; then
    IP=$(hostname -I | awk '{print $1}')
    if [ -z "$IP" ]; then
        echo -e "${RED}❌ Failed to automatically detect IP address.${NC}"
        exit 1
    fi
fi

# Debug: Print current directory and list files
confirm_step "Display current directory and files"
echo -e "${BLUE}📂 Current directory: $(pwd)${NC}"
echo -e "${BLUE}📄 Files in current directory:${NC}"
ls -l

# Debug: Print BASE_DIR and DOCKER_COMPOSE_DIR values
echo -e "${BLUE}🏠 BASE_DIR value: $BASE_DIR${NC}"
echo -e "${BLUE}🐳 DOCKER_COMPOSE_DIR value: $DOCKER_COMPOSE_DIR${NC}"

# Update and upgrade the system
confirm_step "Update and upgrade the system packages"
sudo apt update && sudo apt upgrade -y

# Install required dependencies
confirm_step "Install required dependencies for Docker"
sudo apt install -y curl gnupg lsb-release

# Download Docker's GPG key
confirm_step "Download and verify Docker's GPG key"
curl -fsSL https://download.docker.com/linux/debian/gpg -o docker.gpg

# Verify the GPG key
if [ "$(md5sum docker.gpg | awk '{print $1}')" != "1afae06b34a13c1b3d9cb61a26285a15" ]; then
    echo -e "${RED}❌ Docker GPG key verification failed. Exiting.${NC}"
    exit 1
fi

# Create the keyrings directory and add the GPG key
confirm_step "Add Docker's GPG key to the system"
sudo mkdir -p /etc/apt/keyrings
sudo gpg --dearmor < docker.gpg | sudo tee /etc/apt/keyrings/docker.gpg > /dev/null

# Verify the dearmored GPG key was created
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    echo -e "${RED}❌ Failed to create dearmored Docker GPG key. Exiting.${NC}"
    exit 1
fi

# Add the Docker repository
confirm_step "Add Docker repository to system sources"
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update the package index
sudo apt update

# Install Docker and Docker Compose
confirm_step "Install Docker and Docker Compose"
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-compose

# Start and enable the Docker service
confirm_step "Start and enable Docker service"
sudo systemctl start docker
sudo systemctl enable docker

# Add your user to the docker group
confirm_step "Add user to Docker group"
sudo usermod -aG docker $USERNAME

# Install necessary packages for Samba
confirm_step "Install Samba packages"
sudo apt install -y samba samba-common-bin

# Create directories
confirm_step "Create necessary directories"
sudo mkdir -p "$PORTAINER_DATA_DIR" "$NODE_RED_DATA_DIR"

# Ensure DOCKER_COMPOSE_DIR exists and has correct permissions
sudo mkdir -p "$DOCKER_COMPOSE_DIR"
sudo chown "$USERNAME:$USERNAME" "$DOCKER_COMPOSE_DIR"

# Copy docker-compose.yml to the Docker Compose directory
confirm_step "Copy and modify docker-compose.yml"
echo -e "${BLUE}📄 Copying docker-compose.yml to $DOCKER_COMPOSE_DIR${NC}"
if [ ! -f "$BASE_DIR/docker-compose.yml" ]; then
    echo -e "${RED}❌ docker-compose.yml not found in $BASE_DIR. Please ensure it exists.${NC}"
    exit 1
fi

sudo cp "$BASE_DIR/docker-compose.yml" "$DOCKER_COMPOSE_DIR/docker-compose.yml"

# Replace environment variables in docker-compose.yml
sed -i "s|\${PORTAINER_DATA_DIR}|$PORTAINER_DATA_DIR|g" "$DOCKER_COMPOSE_DIR/docker-compose.yml"
sed -i "s|\${PORTAINER_PORT}|$PORTAINER_PORT|g" "$DOCKER_COMPOSE_DIR/docker-compose.yml"
sed -i "s|\${NODE_RED_DATA_DIR}|$NODE_RED_DATA_DIR|g" "$DOCKER_COMPOSE_DIR/docker-compose.yml"
sed -i "s|\${NODE_RED_PORT}|$NODE_RED_PORT|g" "$DOCKER_COMPOSE_DIR/docker-compose.yml"

# Print the modified docker-compose.yml
echo -e "${BLUE}📄 Content of modified $DOCKER_COMPOSE_DIR/docker-compose.yml:${NC}"
cat "$DOCKER_COMPOSE_DIR/docker-compose.yml"

# Set correct permissions for Node-RED data directory
confirm_step "Set permissions for Node-RED data directory"
sudo chown -R 1000:1000 "$NODE_RED_DATA_DIR"
sudo chmod -R 775 "$NODE_RED_DATA_DIR"

# Start Docker containers
confirm_step "Start Docker containers (Portainer and Node-RED)"
sudo docker-compose -f "$DOCKER_COMPOSE_DIR/docker-compose.yml" up -d

# Configure Samba
confirm_step "Configure Samba for sharing Docker folders"
sudo tee -a /etc/samba/smb.conf << EOF

[docker]
   comment = Docker Folders
   path = $DOCKER_COMPOSE_DIR
   browseable = yes
   read only = no
   create mask = 0755
   directory mask = 0755
EOF

# Set Samba password for the user (non-interactively)
confirm_step "Set Samba password for user"
echo -e "$SAMBA_PASS\n$SAMBA_PASS" | sudo smbpasswd -s -a $SAMBA_USER

# Restart Samba service
confirm_step "Restart Samba service"
sudo systemctl restart smbd

# Verify Docker containers are running
confirm_step "Verify Docker containers are running"
if ! docker ps | grep -q 'portainer'; then
    echo -e "${RED}❌ Portainer container is not running. Check Docker logs for more information.${NC}"
fi
if ! docker ps | grep -q 'node-red'; then
    echo -e "${RED}❌ Node-RED container is not running. Check Docker logs for more information.${NC}"
fi

echo -e "${BLUE}✅ Installation complete!${NC}"
echo -e "${BLUE}🌐 Portainer is accessible at http://$IP:$PORTAINER_PORT${NC}"
echo -e "${BLUE}🔴 Node-RED is accessible at http://$IP:$NODE_RED_PORT${NC}"
echo -e "${BLUE}📁 Docker folders are shared via Samba at \\\\$IP\\docker${NC}"
echo -e "${BLUE}👤 Please use your Samba username ($SAMBA_USER) and the password you set in the .env file to access the share.${NC}"
echo -e "${BLUE}🔄 You may need to log out and log back in for Docker permissions to take effect.${NC}"

# Clean up sensitive files
confirm_step "Clean up temporary files for security"
cd ~
sudo rm -rf $BASE_DIR

echo -e "${BLUE}🎉 Setup complete. Temporary files have been removed for security.${NC}"
echo -e "${BLUE}🔍 If you encounter any issues, please check the Docker logs using 'docker logs portainer' or 'docker logs node-red'${NC}"