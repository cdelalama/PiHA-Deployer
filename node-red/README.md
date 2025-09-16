# Node-RED Deployment Scripts

## Purpose
Automated Docker deployment of Node-RED with Portainer, Syncthing, and NAS synchronization for Raspberry Pi home automation.

## Quick Start
1. Copy `.env.example` to `.env` and configure all variables
2. Ensure NAS is accessible and CIFS/SMB share is available  
3. Run: `./install-node-red.sh`

## Services Deployed
- **Node-RED**: Visual programming for IoT and automation flows
- **Portainer**: Docker container management web interface
- **Syncthing**: File synchronization with NAS storage

## Requirements
- Fresh Raspberry Pi OS installation
- Network access to NAS with CIFS/SMB share
- Docker and Docker Compose installed and running (the installer only ensures SMB client packages)

## Current Version
Check VERSION lines in scripts (main installer: 1.0.67)

## Configuration (.env)

1. Create a `.env` file and fill in values for your environment. You may set `IP=auto` for auto-detection. You can base it on your existing `.env` conventions.
2. Required variables (ensure all are present in `.env`):
   - Host and paths: `HOST_ID`, `BASE_DIR`, `DOCKER_USER_ID`, `DOCKER_GROUP_ID`, `DOCKER_COMPOSE_DIR`, `PORTAINER_DATA_DIR`, `NODE_RED_DATA_DIR`, `SYNCTHING_CONFIG_DIR`
   - Ports and network: `PORTAINER_PORT`, `NODE_RED_PORT`, `IP`
   - NAS (CIFS): `NAS_IP`, `NAS_SHARE_NAME`, `NAS_USERNAME`, `NAS_PASSWORD`, `NAS_MOUNT_DIR`
   - Samba (NAS share credentials if applicable): `SAMBA_USER`, `SAMBA_PASS`
   - Syncthing: `SYNCTHING_USER`, `SYNCTHING_PASS`, `NAS_SYNCTHING_ID`, `NAS_NAME`
   - Other: `SYNC_INTERVAL`, `PORTAINER_PASS`

See `.env.example` for the full list and expected format.

Important:
- Do not edit `.env.example` manually; it is generated automatically from `.env` by a plugin.
- Do not change or commit existing credentials in `.env`. If a new variable is required, document it and add it to `.env`; the plugin will regenerate `.env.example`.

Recommended NAS paths (group by host):
- `NODE_RED_DATA_DIR=${NAS_MOUNT_DIR}/hosts/${HOST_ID}/node-red`
- `PORTAINER_DATA_DIR=${NAS_MOUNT_DIR}/hosts/${HOST_ID}/portainer`
- `DOCKER_COMPOSE_DIR=${NAS_MOUNT_DIR}/hosts/${HOST_ID}/compose`

Password note: if any password contains a `$`, escape it as `\$` in `.env` to avoid shell expansion during loading.

Optional shared config (common/Common.env)
- Place shared defaults in `common/Common.env` (gitignored) loaded before `.env`.
- Load order: `../common/Common.env` → `../common/common.env` → `common/Common.env` → `common/common.env` → `$HOME/.piha/common.env` → `/etc/piha/common.env` → `.env`.
- Suggested: `NAS_MOUNT_DIR`, `DOCKER_USER_ID`, `DOCKER_GROUP_ID`, `TZ`, `PORTAINER_PASS` (if shared).

## How to Run

Option A: Run from a cloned repository
- Navigate to the `node-red` folder where your `.env` is located and run:
  - `bash install-node-red.sh`

Option B: Remote one-liner
- Place a valid `.env` in the current working directory on the target system, then run:
  - `curl -sSL "https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/node-red/install-node-red.sh" | bash`

## What the Installer Does

1. (Optional) Cleans previous deployments and recreates base directories.
2. Installs `cifs-utils` and `smbclient` if missing.
3. Loads variables from `.env` and verifies NAS connectivity.
4. Creates `BASE_DIR`, copies `.env`, and downloads `PiHA-Deployer-NodeRED.sh` and `docker-compose.yml` from GitHub when appropriate.
5. Mounts the NAS at `NAS_MOUNT_DIR` (CIFS) and creates structure (`node-red`, `portainer`, `nas_data`, `.stfolder`).
6. Starts Portainer, Node-RED, and Syncthing via `docker-compose` and configures Syncthing (GUI/auth, devices, and folders). Saves Syncthing ID into config directories.

## Access After Installation

- Node-RED: `http://<IP>:<NODE_RED_PORT>`
- Portainer: `http://<IP>:<PORTAINER_PORT>`
- Syncthing (GUI): `http://<IP>:8384`
- NAS mount point: `NAS_MOUNT_DIR`

## Troubleshooting

- Verify Docker and Compose: `docker ps` and `docker-compose -f "${BASE_DIR}/docker-compose.yml" logs`
- Check mount status: `mountpoint -q "${NAS_MOUNT_DIR}"` and connectivity `ping ${NAS_IP}`
- Container logs: `docker logs portainer`, `docker logs node-red`, `docker logs syncthing`
- Syncthing ID: `docker logs syncthing | grep 'My ID:'`

## Security

- Use strong passwords for Syncthing and Portainer. The `.env` file contains sensitive credentials.
- The installer may copy `.env` into `BASE_DIR`. Manage permissions appropriately.

## Contributing

Contributions and PRs are welcome.

## License

MIT License

Copyright (c) 2024 cdelalama

