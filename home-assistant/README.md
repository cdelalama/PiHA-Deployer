# Home Assistant Deployment Scripts

## Purpose
Automated Docker deployment of Home Assistant with Portainer and NAS-backed persistent data on a fresh Raspberry Pi.

## Requirements
- Fresh Raspberry Pi OS installation with SSH access
- Network access to a NAS with an SMB/CIFS share
- Sudo privileges on the Raspberry Pi

Note: This installer will install Docker and the Docker Compose plugin if missing, and will ensure SMB client packages are present.

## Quick Start
1. SSH into the Home Assistant Pi and create the working directory:

```
mkdir -p ~/piha-home-assistant
cd ~/piha-home-assistant
```

2. Create a `common/` subdirectory here and drop your shared defaults in `common/common.env` (NAS credentials, mount path, UID/GID, Portainer password, etc.). You can copy from `common/common.env.example` in this repo and adjust values.
3. Place the component-specific `.env` in the working directory (only the Home Assistant overrides live here; the installer loads `common/common.env` first and then `.env`). You can copy `home-assistant/.env.example` as a template (or reuse your existing `home-assistant/.env`) and fill in your secrets.
   - For the SQLite-only flow (scenario 1A), the installer defaults `/config` to `/var/lib/piha/home-assistant` on the Pi; override it by setting `SQLITE_DATA_DIR` or `HA_DATA_DIR` in `.env`.
4. Run the installer directly from GitHub (requires `curl` and `sudo`):

```
curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/install-home-assistant.sh | sudo bash
```

- The installer waits 5 seconds for NAS writes to settle (configurable via `NAS_COOLDOWN_SECONDS`) to prevent SQLite lock errors on CIFS shares.

**Post-install checks**
```bash
sudo docker compose ps
sudo docker logs homeassistant --tail 50
sudo docker logs portainer --tail 20
mount | grep /mnt/piha
```
- Home Assistant reachable at `http://<pi-ip>:8123` and Portainer at `http://<pi-ip>:9000`.

> Heads-up: if the NAS already contains previous Home Assistant data (e.g. `${HA_DATA_DIR}`), the installer detects it. When running interactively it will ask whether to reuse the data; in non-interactive runs (e.g. `curl ... | sudo bash`) the installer exits unless `HA_ALLOW_EXISTING_DATA=true` is set in `.env` (or you remove the directories for a clean install). Inline comments after the flag are fine (`HA_ALLOW_EXISTING_DATA=true  # reuse NAS data` will be honoured).

## Reset / Uninstall

If you need a full reset (containers, NAS data, and the NAS MariaDB deployment), use the uninstaller from your Home Assistant working directory (by default `~/piha-home-assistant`, created in Quick Start step 1).

**Recommended (keeps the confirmation prompt):**

```
curl -fSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/uninstall-home-assistant.sh -o uninstall-home-assistant.sh
printf '\033[0;34mDownloaded uninstall-home-assistant.sh; run sudo bash uninstall-home-assistant.sh next\033[0m\n'
sudo bash uninstall-home-assistant.sh
```

**Automation-friendly one-liner (skips confirmation):**

```
curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/uninstall-home-assistant.sh | sudo bash -s -- --force
```

Add `--skip-nas-ssh` when you do *not* want the script to remove `${NAS_DEPLOY_DIR}` on the NAS via SSH. In interactive runs the uninstaller now asks (after the confirmation) whether to delete this working directory and remove the Home Assistant/Portainer Docker images; answer `y` to apply. Automation can continue to pass `--purge-local`, `--purge-images`, or set the `UNINSTALL_PURGE_LOCAL/UNINSTALL_PURGE_IMAGES` env vars; use `--keep-env`/`UNINSTALL_KEEP_ENV` when you need `.env` to survive the cleanup.

- The script loads your `.env`, stops the stack, and deletes `${HA_DATA_DIR}`, `${PORTAINER_DATA_DIR}`, and `${DOCKER_COMPOSE_DIR}` from their configured locations (NAS or local).
- By default it also connects to the NAS via SSH (using `NAS_SSH_*`) to remove `${NAS_DEPLOY_DIR}` for MariaDB.
- Unless `--keep-env` (or `UNINSTALL_KEEP_ENV=true`) is set, the run deletes `.env` (and `.env.bootstrap` when present) from the working directory so credentials are not left behind.
- Staying in interactive mode (recommended) gives you a final confirmation before deleting.

Afterwards recreate your working folder (e.g. `mkdir -p ~/piha-home-assistant && cd ~/piha-home-assistant`) and repopulate both `common/common.env` and `.env` from your secrets backup before rerunning the installer.

To double-check the cleanup on the Pi, run:

```
sudo docker ps -a
sudo docker images
```

Both commands should return empty lists (or only show other services you have installed).
## What It Installs
- Docker + Docker Compose plugin (if missing)
- Portainer (local instance on this Raspberry Pi)
- Home Assistant container
- SMB/CIFS mounting to store all container data on the NAS

## Data Persistence Model
- **SQLite (scenario 1A)**: Home Assistant /config lives on the Pi (default /var/lib/piha/home-assistant). Back it up or rsync it manually if you need to migrate.
- **MariaDB (scenario 1B)**: the NAS share is mounted and used for configuration; the recorder data sits in MariaDB on the NAS.
- Portainer and compose metadata continue to live on the NAS for both scenarios (unless you override the paths).
## Default Ports
- Home Assistant: 8123 (host network)
- Portainer: 9000 (mapped from `${PORTAINER_PORT}`, default 9000)

## Configuration (.env)

1. Create a `.env` file and add required variables (you may base it on your Node-RED `.env` conventions)
2. Required variables:
   - Host and paths: `HOST_ID`, `BASE_DIR`, `DOCKER_USER_ID`, `DOCKER_GROUP_ID`, `DOCKER_COMPOSE_DIR`, `HA_DATA_DIR`, `PORTAINER_DATA_DIR`
   - Ports and network: `HA_PORT` (default 8123)
   - NAS (CIFS): `NAS_IP`, `NAS_SHARE_NAME`, `NAS_USERNAME`, `NAS_PASSWORD`, `NAS_MOUNT_DIR`
   - Portainer admin: `PORTAINER_PASS`

Recommended paths:
- **SQLite (scenario 1A)**: set `HA_DATA_DIR=/var/lib/piha/home-assistant` (local on the Pi). Override with `SQLITE_DATA_DIR` if you prefer a different local path.
- **MariaDB (scenario 1B)**: keep NAS-backed directories:
  - `HA_DATA_DIR=${NAS_MOUNT_DIR}/hosts/${HOST_ID}/home-assistant`
  - `PORTAINER_DATA_DIR=${NAS_MOUNT_DIR}/hosts/${HOST_ID}/portainer`
  - `DOCKER_COMPOSE_DIR=${NAS_MOUNT_DIR}/hosts/${HOST_ID}/compose`
Variables to consider as well:
- `TZ` (optional timezone, e.g., `Europe/Madrid`) used by Home Assistant container
- `SQLITE_DATA_DIR` (optional override for the local SQLite directory; defaults to `/var/lib/piha/home-assistant`).
Optional: MariaDB recorder validation

- Set `ENABLE_MARIADB_CHECK=true` to have the installer verify MariaDB before deployment
- Provide `MARIADB_HOST` (defaults to `NAS_IP`), `MARIADB_PORT` (defaults to `3306`), `MARIADB_DATABASE`, `MARIADB_USER`, `MARIADB_PASSWORD`
- Optionally set `MARIADB_CONTAINER_NAME` to customize the MariaDB container name (defaults to `mariadb`).
- The installer uses `netcat-openbsd` and `mariadb-client` to verify port reachability and credentials
- When MariaDB is enabled, the installer ensures `requirements.txt` inside `${HA_DATA_DIR}` contains `PyMySQL==1.1.0` and automatically restarts the `homeassistant` container when it was already running, so the Recorder picks up the MySQL driver without manual steps.

Refer to this README and your existing environment. Do not edit `.env.example` (it is generated from `.env` by a plugin).

Password note: if any password contains a `$`, escape it as `\$` in `.env` to avoid shell expansion during loading.

Optional shared config (common/Common.env)
- To avoid duplication, place shared defaults in `common/Common.env` (gitignored) which is loaded before `.env`.
- Load order: `../common/Common.env` -> `../common/common.env` -> `common/Common.env` -> `common/common.env` -> `$HOME/.piha/common.env` -> `/etc/piha/common.env` -> `./Common.env` -> `./common.env` -> `.env` (last wins).
- Suggested contents: `NAS_MOUNT_DIR`, `DOCKER_USER_ID`, `DOCKER_GROUP_ID`, `TZ`, `PORTAINER_PASS` (if you want a single password per host), `PORTAINER_PORT=9000` (standardize across Pis).

Important:
- Do not edit `.env.example` manually; it is generated automatically from `.env` by a plugin.
- Do not change or commit existing credentials in `.env`. If a new variable is required, document it and add it to `.env`; the plugin will regenerate `.env.example`.

## How to Run
- From this folder with a properly configured `.env`, run:
  - `bash install-home-assistant.sh`

## Compose Services
- `homeassistant`: ghcr.io/home-assistant/home-assistant:stable, `network_mode: host`, data at `${HA_DATA_DIR}` (NAS-backed)
- `portainer`: portainer/portainer-ce:latest, data at `${PORTAINER_DATA_DIR}` (NAS-backed)
  - Runs as root (no `user:` override) to access `/var/run/docker.sock`
  - Docker socket is mounted read-write to manage the local Docker engine

## Recorder Database (MariaDB on NAS)

Running Recorder on MariaDB avoids SQLite-on-SMB corruption and preserves UI history across Pi reinstalls.

> Set `ENABLE_MARIADB_CHECK=true` plus all `MARIADB_*` variables in `.env` if you want MariaDB. The installer will stop if the database is unavailable (printing the bootstrap command) and will write `secrets.yaml` + a managed `recorder` block automatically when the database is reachable.

1) Deploy MariaDB on your NAS (via SSH)
- Option A: run `home-assistant/mariadb/setup-nas-mariadb.sh` from this repository. It connects via SSH, copies `docker-compose.yml` and `.env`, and starts the container automatically (Docker required on the NAS).
  - One-liner: `ssh <nas-user>@<NAS_IP> "curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/mariadb/setup-nas-mariadb.sh | bash"`
- Option B: manually follow `home-assistant/mariadb/docker-compose.yml` and `home-assistant/mariadb/README.md` as a template.
- Ensure MariaDB listens on `3306` and is reachable from the Pi.

2) (Optional) Manual configuration
- If you prefer to manage recorder settings yourself, edit `${HA_DATA_DIR}/secrets.yaml` and `${HA_DATA_DIR}/configuration.yaml` using the snippet below (this matches what the installer writes when the check succeeds).
```
# secrets.yaml
recorder_db_url: mysql+pymysql://homeassistant:changeMeUser@<NAS_IP>:3306/homeassistant?charset=utf8mb4

# configuration.yaml
recorder:
  db_url: !secret recorder_db_url
  purge_keep_days: 14
  commit_interval: 30
```

- After editing manually, restart Home Assistant:
```
docker compose -f "${BASE_DIR}/docker-compose.yml" up -d --force-recreate homeassistant
```

Notes:
- Keep MariaDB data on a local NAS filesystem (not on SMB/CIFS).
- The installer issues a NAS cooldown (`NAS_COOLDOWN_SECONDS`, default 5s) before launching containers to minimise CIFS locking issues.
- If you previously had SQLite on SMB, remove `home-assistant_v2.db*` from `${HA_DATA_DIR}`.
- If the installer reports that MariaDB is missing or misconfigured, fix it using the one-liner above and rerun the script. See `home-assistant/mariadb/README.md` for detailed setup instructions.

## Troubleshooting
- Verify Docker and Compose: `docker ps` and `docker compose ls`
- Check mount status: `mountpoint -q "${NAS_MOUNT_DIR}"` and connectivity `ping ${NAS_IP}`
- Container logs: `docker logs homeassistant`, `docker logs portainer`

## Security
- Use strong passwords for Portainer.
- `.env` contains sensitive credentials; restrict permissions (600) and storage.

## Notes
- This setup uses a local Portainer per Raspberry Pi for simplicity. A centralized Portainer Server + Agents can be added later as an enhancement.
  - Future plan: move Portainer Server to NAS and install Portainer Agent on each Raspberry Pi.



