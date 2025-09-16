# PiHA-Deployer Project Context

## Project Vision

Goal: Automated deployment of home automation services on Raspberry Pi with NAS synchronization.

Current Status: Node-RED component is complete and stable. Home Assistant installer v1.1.0 (with MariaDB validation) awaits on-device testing. Zigbee2MQTT component has been scaffolded for upcoming relay validation.

## Architecture Overview

Core Components
- Node-RED (complete)
  - Docker container with persistent data
  - Web interface for automation flows
  - Integration with Portainer and Syncthing
- Home Assistant (planned)
  - Similar Docker deployment pattern
  - Home automation hub
  - Integration with the same NAS sync system
- Zigbee2MQTT (scaffolded)
  - Zigbee coordinator + Mosquitto broker + Portainer
  - Runs on dedicated Pi with SONOFF USB dongle and NAS-backed data
  - Provides MQTT bridge for Home Assistant automations
- Supporting Services
  - Portainer: Docker container management
  - Syncthing: File synchronization with NAS
  - SMB/CIFS client: Mounts NAS shares (no Samba server configured on the Pi)

Infrastructure
- Target platform: Multiple Raspberry Pi devices with Raspberry Pi OS
- **Deployment model**: Each component deploys on separate Pi
  - Node-RED component: dedicated Pi
  - Home Assistant component: separate dedicated Pi
- Containerization: Docker + Docker Compose per Pi
- Storage: SMB/CIFS mount to shared NAS for persistent data
- Network: Standard LAN; VLAN/IOT networks optional

## Project Structure

```
PiHA-Deployer/
|-- LLM_START_HERE.md              # LLM entry point
|-- docs/
|   |-- PROJECT_CONTEXT.md         # This file
|   |-- VERSIONING_RULES.md        # Version management
|   `-- llm/
|       |-- HANDOFF.md             # Current state handoff
|       `-- HISTORY.md             # Change history log
|-- node-red/                      # Node-RED deployment (complete)
|   |-- README.md                  # Component overview
|   |-- .env.example               # Configuration template
|   |-- install-node-red.sh        # Main installer (v1.0.67)
|   |-- PiHA-Deployer-NodeRED.sh   # Container setup (v1.0.34)
|   |-- configure-syncthing.sh     # Syncthing configuration (v1.1.5)
|   |-- load_env_vars.sh           # Environment loader (v1.0.4)
|   `-- docker-compose.yml         # Service definitions
|-- home-assistant/                # Home Assistant deployment (scaffolded)
|   |-- README.md                  # Component overview
|   |-- install-home-assistant.sh  # Main installer (v1.1.0)
|   `-- docker-compose.yml         # Service definitions (Portainer + Home Assistant)
|-- zigbee2mqtt/                   # Zigbee coordinator deployment (scaffolded)
|   |-- README.md                  # Component overview
|   |-- install-zigbee2mqtt.sh     # Main installer (v1.1.0)
|   `-- docker-compose.yml         # Service definitions (Z2M + Mosquitto + Portainer)
`-- nas/
    |-- README.md                  # MariaDB setup guide
    |-- docker-compose.yml         # MariaDB service definition
    `-- setup-nas-mariadb.sh       # Optional NAS bootstrap script
```


## Development Conventions

File naming
- Scripts: kebab-case with .sh extension
- Documentation: UPPER_CASE.md for project docs, README.md for components
- Environment: .env for local config, .env.example for templates

Code standards
- Language: All code comments and documentation in English
- Logging: Use [OK]/[ERROR]/[INFO]/[WARN] prefixes
- Colors: Standardized BLUE/GREEN/RED/YELLOW variables
- Versioning: VERSION="x.y.z" at top of each script

Environment configuration
- Required: .env file with variables per component
- NAS integration: SMB/CIFS mount configuration mandatory
- Security: Restrictive file permissions for secrets (e.g., 600 for .env)

Environment files policy
- `.env` is the source of truth and contains sensitive values. Do not commit secrets or change existing credentials.
- `.env.example` is generated automatically from `.env` by a plugin. Do not edit `.env.example` manually.
- When a new variable is needed:
  - Document the new variable (purpose, default/expected format) in the relevant README and in HANDOFF.
  - Update scripts to read the variable (without hardcoding secrets).
  - Ask the user to populate the value in `.env`. The plugin will regenerate `.env.example` from `.env`.
  - Treat making a variable newly required as a MAJOR version change (see VERSIONING_RULES).

## Storage Layout Convention (Group by Host)

- Single mount point on every Raspberry Pi: `${NAS_MOUNT_DIR}` (recommended `/mnt/piha`).
- Group data by host under `hosts/<HOST_ID>/` to avoid collisions and simplify recovery.
- Examples:
  - Node-RED on host `nodered-pi-01`:
    - `NODE_RED_DATA_DIR=${NAS_MOUNT_DIR}/hosts/${HOST_ID}/node-red`
    - `PORTAINER_DATA_DIR=${NAS_MOUNT_DIR}/hosts/${HOST_ID}/portainer`
  - Home Assistant on host `ha-pi-01`:
    - `HA_DATA_DIR=${NAS_MOUNT_DIR}/hosts/${HOST_ID}/home-assistant`
    - `PORTAINER_DATA_DIR=${NAS_MOUNT_DIR}/hosts/${HOST_ID}/portainer`
- Recommended: keep `DOCKER_COMPOSE_DIR` on NAS per host
  - `DOCKER_COMPOSE_DIR=${NAS_MOUNT_DIR}/hosts/${HOST_ID}/compose`
- Optional shared area: `${NAS_MOUNT_DIR}/shared/` (for purely shared assets, if needed).

## Shared Configuration (common.env)

- To reduce duplication across Raspberry Pis/components, common defaults can be kept in a shared env file.
- Primary location (recommended): `common/Common.env` at repo root (ignored by Git to avoid committing secrets).
- Load precedence (later wins):
  1) `../common/Common.env` then `../common/common.env` (repo-level, sibling to component folder)
  2) `common/Common.env` then `common/common.env` (inside component folder)
  3) `$HOME/.piha/common.env` (host-local, not versioned)
  4) `/etc/piha/common.env` (system-wide, not versioned)
  5) `./Common.env` then `./common.env` (current directory, useful in local tests)
  6) `.env` (component-specific, authoritative)
- Recommended in `common.env` (example): `NAS_MOUNT_DIR`, `DOCKER_USER_ID`, `DOCKER_GROUP_ID`, `TZ`.
- Keep secrets in `common/Common.env` (gitignored) or per-host local files; `.env` per componente puede sobrescribirlos si es necesario.

## Component Links

- Node-RED: node-red/README.md (current implementation)
- Home Assistant: home-assistant/README.md (to be created)

## Technology Stack

- Base OS: Raspberry Pi OS (Debian-based)
- Containers: Docker + Docker Compose
- File Sync: Syncthing
- Storage: SMB/CIFS (NAS integration)
- Web UI: Portainer

---

Next: read docs/VERSIONING_RULES.md

