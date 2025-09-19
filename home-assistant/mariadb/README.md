# MariaDB for Home Assistant Recorder

## Overview
Run MariaDB on your NAS (via Docker Compose) so Home Assistant (running on a Raspberry Pi) can use it as the Recorder backend. This avoids SQLite-on-SMB issues and preserves history across Raspberry Pi reinstalls.

## Requirements
- NAS with Docker and Docker Compose available via SSH
- An open TCP port `3306` on the NAS (or mapped) reachable from the Home Assistant Pi

## Setup

### Primary flow: Manual bootstrap directly on the NAS
1) SSH into the NAS and prepare the working directory (QNAP defaults shown):
```
ssh <nas-user>@<NAS_IP>
mkdir -p /share/Container/compose/mariadb
cd /share/Container/compose/mariadb
```
2) Copy or create `.env` in that directory using the variables above (upload it via SFTP/Samba or generate it with a secrets manager).
3) Download the compose file if it is not already present:
```
curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/mariadb/docker-compose.yml -o docker-compose.yml
```
4) Start MariaDB on the NAS:
```
docker compose up -d
```
5) Test connectivity from the Home Assistant Pi:
```
nc -vz <NAS_IP> 3306
```

### Optional: Automated bootstrap from a PiHA-Deployer clone
1) On the machine where you keep this repository (Pi or workstation), populate `home-assistant/mariadb/.env` with:
   - SSH: `NAS_SSH_HOST`, `NAS_SSH_USER`, optional `NAS_SSH_PORT` (default `22`), optional `NAS_SSH_USE_SUDO=true` if Docker requires sudo
   - Deployment: `NAS_DEPLOY_DIR` (default `/share/Container/compose/mariadb`), `MARIADB_DATA_DIR` (defaults to `${NAS_DEPLOY_DIR}/data`)
   - MariaDB credentials: `MARIADB_ROOT_PASSWORD`, `MARIADB_DATABASE`, `MARIADB_USER`, `MARIADB_PASSWORD`, `PUBLISHED_PORT`
2) Run `bash setup-nas-mariadb.sh` from this directory. The helper script will:
   - Create `${NAS_DEPLOY_DIR}` and `${MARIADB_DATA_DIR}` on the NAS over SSH
   - Copy `docker-compose.yml` and the rendered `.env` to the NAS
   - Start the MariaDB stack using Docker Compose
3) Verify the container with `docker ps | grep mariadb` on the NAS if desired.

> Tip: You can also copy the helper script to the NAS (`curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/mariadb/setup-nas-mariadb.sh -o setup-nas-mariadb.sh`), but it still expects the `.env` file next to it and will execute SSH back to the host defined in `.env`. For fresh installs, the manual NAS flow above is usually the most straightforward.

## Home Assistant configuration (on the Pi)

1) Add a local DB folder for MariaDB (not needed for remote DB) - skip for NAS DB

2) Point Recorder to MariaDB using secrets
- In `${HA_DATA_DIR}/secrets.yaml` add:
```
recorder_db_url: mysql+pymysql://homeassistant:changeMeUser@<NAS_IP>:3306/homeassistant?charset=utf8mb4
```

- In `${HA_DATA_DIR}/configuration.yaml` add or edit:
```
recorder:
  db_url: !secret recorder_db_url
  purge_keep_days: 14
  commit_interval: 30
```

3) Restart Home Assistant
```
docker compose -f "${BASE_DIR}/docker-compose.yml" up -d --force-recreate homeassistant
```

## Notes
- Do NOT store MariaDB data on an SMB/CIFS share. Use a local filesystem on the NAS (e.g., ext4).
- Ensure the NAS firewall allows port `3306` from the Home Assistant Pi.
- Keep credentials in the NAS `.env` only; do not commit them.
- After the container is running, set `ENABLE_MARIADB_CHECK=true` and the `MARIADB_*` variables in `home-assistant/.env` so the installer can verify the database.
