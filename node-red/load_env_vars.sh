#!/bin/bash

# Version
VERSION="1.0.4"

echo -e "${BLUE}Reading and exporting environment variables from .env file...${NC}"

# Verify file exists
if [ ! -f .env ]; then
    echo -e "${RED}[ERROR] .env file not found${NC}"
    echo -e "${RED}Please create a .env file with the required variables${NC}"
    exit 1
fi

# Ensure .env file has correct permissions
chmod 600 .env || true

_load_env_file() {
    local file="$1"
    [ -f "$file" ] || return 0
    while IFS= read -r line; do
        line="$(printf '%s' "$line" | sed $'s/\xEF\xBB\xBF//g; s/\xC2\xA0/ /g' | tr -d '\r')"
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        if [[ $line =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            key="$(echo "$key" | xargs)"
            value="$(echo "$value" | xargs)"
            if [[ $value =~ ^\"(.*)\"$ ]]; then value="${BASH_REMATCH[1]}"; fi
            if [[ $value =~ ^\'(.*)\'$ ]]; then value="${BASH_REMATCH[1]}"; fi
            printf -v "$key" '%s' "$value"
            export "$key"
        fi
    done < "$file"
}

# Load optional shared config first (defaults), then component .env (overrides)
_load_env_file "../common/Common.env"
_load_env_file "../common/common.env"
_load_env_file "common/Common.env"
_load_env_file "common/common.env"
_load_env_file "$HOME/.piha/common.env"
_load_env_file "/etc/piha/common.env"
_load_env_file "./Common.env"
_load_env_file "./common.env"
_load_env_file ".env"

echo -e "${GREEN}[OK] Environment variables loaded successfully${NC}"
