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

2. Place your component `.env` (and optional `common/Common.env`) in this directory. The installer reads `.env` from the current working folder.
3. Run the installer directly from GitHub (requires `curl` and `sudo`):

```
curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/install-home-assistant.sh | sudo bash
```

> Heads-up: if the NAS already contains previous Home Assistant data (e.g. `${HA_DATA_DIR}`), the installer detects it. When running interactively it will ask whether to reuse the data; in non-interactive runs (e.g. `curl ... | sudo bash`) the installer exits unless `HA_ALLOW_EXISTING_DATA=true` is set in `.env` (or you remove the directories for a clean install). Inline comments after the flag are fine (`HA_ALLOW_EXISTING_DATA=true  # reuse NAS data` will be honoured).

## Reset / Uninstall

If you need a full reset (containers, NAS data, and the NAS MariaDB deployment), use the uninstaller from your Home Assistant working directory (by default `~/piha-home-assistant`, created in Quick Start step 1).

**Recommended (keeps the confirmation prompt):**

```
curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/uninstall-home-assistant.sh -o uninstall-home-assistant.sh
sudo bash uninstall-home-assistant.sh
```

**Automation-friendly one-liner (skips confirmation):**

```
curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/uninstall-home-assistant.sh | sudo bash -s -- --force
```

Add `--skip-nas-ssh` when you do *not* want the script to remove `${NAS_DEPLOY_DIR}` on the NAS via SSH. Pass `--purge-local` if you also want the script to remove this working directory once cleanup finishes, and `--purge-images` to delete the Home Assistant/Portainer Docker images from the Pi (set `UNINSTALL_PURGE_LOCAL/UNINSTALL_PURGE_IMAGES` in `.env` to make these the default).

- The script loads your `.env`, stops the stack, and deletes `${HA_DATA_DIR}`, `${PORTAINER_DATA_DIR}`, and `${DOCKER_COMPOSE_DIR}` on the NAS share.
- By default it also connects to the NAS via SSH (using `NAS_SSH_*`) to remove `${NAS_DEPLOY_DIR}` for MariaDB.
- Staying in interactive mode (recommended) gives you a final confirmation before deleting.

Afterwards you can remove the local working folder (e.g. `rm -rf ~/piha-home-assistant`) and rerun the installer for a clean deployment.


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
- The NAS share is mounted locally and bind-mounted into containers so data lives on the NAS.
- Reinstall scenario: flash OS, configure `.env`, run the installer; data is reused from the NAS.

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

Recommended NAS paths (group by host):
- `HA_DATA_DIR=${NAS_MOUNT_DIR}/hosts/${HOST_ID}/home-assistant`
- `PORTAINER_DATA_DIR=${NAS_MOUNT_DIR}/hosts/${HOST_ID}/portainer`
- `DOCKER_COMPOSE_DIR=${NAS_MOUNT_DIR}/hosts/${HOST_ID}/compose`

Variables to consider as well:
- `TZ` (optional timezone, e.g., `Europe/Madrid`) used by Home Assistant container

Optional: MariaDB recorder validation
- Set `ENABLE_MARIADB_CHECK=true` to have the installer verify MariaDB before deployment
- Provide `MARIADB_HOST` (defaults to `NAS_IP`), `MARIADB_PORT` (defaults to `3306`), `MARIADB_DATABASE`, `MARIADB_USER`, `MARIADB_PASSWORD`
- Optionally set `MARIADB_CONTAINER_NAME` to customize the MariaDB container name (defaults to `mariadb`).
- The installer uses `netcat-openbsd` and `mariadb-client` to verify port reachability and credentials

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



