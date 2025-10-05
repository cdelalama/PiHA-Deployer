#!/bin/bash
set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
NEW_SCRIPT="${SCRIPT_DIR}/../../infrastructure/mariadb/setup-nas-mariadb.sh"

if [ -f "$NEW_SCRIPT" ]; then
  echo "[INFO] Delegating to infrastructure/mariadb/setup-nas-mariadb.sh"
  exec "$NEW_SCRIPT" "$@"
fi

echo "[WARN] This helper moved to infrastructure/mariadb/setup-nas-mariadb.sh"
if command -v curl >/dev/null 2>&1; then
  echo "[INFO] Fetching latest script from GitHub..."
  curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/infrastructure/mariadb/setup-nas-mariadb.sh | bash -s -- "$@"
else
  echo "[ERROR] curl not available. Download infrastructure/mariadb/setup-nas-mariadb.sh manually." >&2
  exit 1
fi
