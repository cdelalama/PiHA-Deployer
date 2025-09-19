# MariaDB for Home Assistant Recorder

## Overview
Run MariaDB on your NAS (via Docker Compose) so Home Assistant (running on a Raspberry Pi) can use it as the Recorder backend. This avoids SQLite-on-SMB issues and preserves history across Raspberry Pi reinstalls.

## Requirements
- NAS with Docker and Docker Compose available via SSH
- An open TCP port `3306` on the NAS (or mapped) reachable from the Home Assistant Pi

## Setup

### Option A: Automated bootstrap (run from this repository)
1) Populate `home-assistant/mariadb/.env` with the required variables:
   - SSH: `NAS_SSH_HOST`, `NAS_SSH_USER`, optional `NAS_SSH_PORT` (default `22`), optional `NAS_SSH_USE_SUDO=true` if Docker requires sudo
   - Deployment: `NAS_DEPLOY_DIR` (default `/share/Container/compose/mariadb`), `MARIADB_DATA_DIR` (local filesystem path on the NAS; defaults to `${NAS_DEPLOY_DIR}/data`)
   - MariaDB credentials: `MARIADB_ROOT_PASSWORD`, `MARIADB_DATABASE`, `MARIADB_USER`, `MARIADB_PASSWORD`, `PUBLISHED_PORT`
2) Run `bash setup-nas-mariadb.sh`
   - The script copies `docker-compose.yml` and renders `.env`, creates folders, and starts the stack via SSH.
   - Requires Docker on the NAS and SSH access (password or key-based).
3) Verify the container with `docker ps | grep mariadb` on the NAS if desired.

### Option B: Manual steps
1) Create a working directory on the NAS (e.g. `/share/Container/compose/mariadb`)
   - Place the files from `home-assistant/mariadb/` (this directory) there.

2) Create a `.env` file on the NAS with credentials and data path:
```
MARIADB_ROOT_PASSWORD=changeMeRoot
MARIADB_DATABASE=homeassistant
MARIADB_USER=homeassistant
MARIADB_PASSWORD=changeMeUser
MARIADB_DATA_DIR=/share/Container/compose/mariadb/data  # or another local ext4 path on the NAS
PUBLISHED_PORT=3306             # external port exposed by NAS
```

3) Start MariaDB on the NAS
```
docker compose up -d
```

4) Test connectivity from the Home Assistant Pi
```
nc -vz <NAS_IP> 3306
```

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
