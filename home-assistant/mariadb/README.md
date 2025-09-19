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
3) With `.env` in place, download and run the helper in a single command (it will honour the values in your `.env` and start the stack):
```
curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/mariadb/setup-nas-mariadb.sh -o setup-nas-mariadb.sh && bash setup-nas-mariadb.sh
```
   - The script reads `NAS_SSH_HOST`, `NAS_SSH_USER`, etc. from `.env`. If you are running it directly on the NAS, you can set `NAS_SSH_HOST=localhost` (or the NAS IP) and `NAS_SSH_USER` to your current user.
4) Test connectivity from the Home Assistant Pi:
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

> Tip: If you prefer to run the script directly on the NAS, download it into `/share/Container/compose/mariadb/` and execute it as shown above; the script still reads `.env` and can run locally when `NAS_SSH_HOST` points to the NAS itself.

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
