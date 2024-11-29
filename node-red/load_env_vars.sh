#!/bin/bash

# Version
VERSION="1.0.4"

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
        value=$(echo "$value" | tr -d '\r' | tr -d '"' | tr -d "'" | xargs)

        # Export variable
        export "${key}=${value}"
    fi
done < .env

# Desactivar el modo de exportación automática
set +a

echo -e "${GREEN}✅ Environment variables loaded successfully${NC}"