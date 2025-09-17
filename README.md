# PiHA-Deployer

Automation scripts to deploy the Pi Home Automation stack (Node-RED, Home Assistant, Zigbee2MQTT, supporting NAS services) on Raspberry Pi devices with NAS-backed persistence.

## Components

- **Home Assistant** (`home-assistant/`)
- **Zigbee2MQTT** (`zigbee2mqtt/`)
- **Node-RED** (`node-red/`)
- **NAS utilities** (`nas/` - MariaDB bootstrap for recorder)

## Documentation Map

- `LLM_START_HERE.md`: entry point with rules and checklist (read first)
- `docs/PROJECT_CONTEXT.md`: architecture, conventions, repo layout
- `docs/VERSIONING_RULES.md`: SemVer policy for scripts
- `docs/llm/HANDOFF.md`: current focus / next steps
- `docs/llm/HISTORY.md`: chronological log of changes

## Quick Start (Home Assistant)

1. SSH into your Pi and create a working directory:

```bash
mkdir -p ~/piha-home-assistant && cd ~/piha-home-assistant
```

2. Create the shared config folder and add common variables (NAS credentials, UID/GID, Portainer password):

```bash
mkdir -p common
cat <<'EOF' > common/Common.env
DOCKER_USER_ID=1000
DOCKER_GROUP_ID=1000
NAS_IP=192.168.1.50
NAS_SHARE_NAME=piha
NAS_USERNAME=your_nas_user
NAS_PASSWORD=changeMeSecure
NAS_MOUNT_DIR=/mnt/piha
PORTAINER_PASS=changeMePortainer
EOF
```

(Adjust the values to match your NAS; this file is gitignored and must be created per host.)

3. Create the component `.env` with host-specific values (see `home-assistant/README.md` for the full list; at minimum set `HOST_ID`, `BASE_DIR`, `HA_DATA_DIR`, ports).
4. Run the installer directly from GitHub (requires `curl` and `sudo`):
```bash
curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/install-home-assistant.sh | sudo bash
```

- The script auto-downloads `docker-compose.yml` if missing.
- If `ENABLE_MARIADB_CHECK=true` and MariaDB is absent, it prints a command to bootstrap the NAS service.

5. Access Home Assistant at `http://<pi-ip>:8123` and Portainer at `http://<pi-ip>:9000`.

## Quick Start (Zigbee2MQTT)

1. SSH into your Pi and create a working directory:

```bash
mkdir -p ~/piha-zigbee2mqtt && cd ~/piha-zigbee2mqtt
```

2. Create the shared config folder and populate `common/Common.env` with the NAS credentials and shared values (same format as Home Assistant).

3. Create the `.env` for Zigbee2MQTT with host-specific values (HOST_ID, Z2M/MQTT/Portainer directories, USB overrides, ports; see `zigbee2mqtt/README.md`).

4. Ensure the SONOFF dongle is connected and run the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/zigbee2mqtt/install-zigbee2mqtt.sh -o install-zigbee2mqtt.sh
chmod +x install-zigbee2mqtt.sh
sudo bash install-zigbee2mqtt.sh
```

(The script writes a full configuration and skips the onboarding wizard.)

## Quick Start (Node-RED)

1. SSH into your Pi and create a working directory:

```bash
mkdir -p ~/piha-node-red && cd ~/piha-node-red
```

2. Create the shared config folder (`common/Common.env`) with NAS credentials, UID/GID, and ports shared with other components.

3. Create the component `.env` (HOST_ID, Node-RED/MQTT/Syncthing paths, ports; see `node-red/README.md`).

4. Run the installer directly from GitHub:

```bash
curl -sSL "https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/node-red/install-node-red.sh" | bash
```

## Environment Files

- Each component expects a local `.env` with host-specific values (ports, paths, IDs).

- Shared values (NAS credentials, UID/GID, mount path, Portainer password) should live in `common/Common.env` next to the component or in the repo root; the installers load these files automatically but they are **not** tracked in Git.

- Example `common/Common.env` snippet (adjust to your environment):

```bash
DOCKER_USER_ID=1000
DOCKER_GROUP_ID=1000
NAS_IP=192.168.1.50
NAS_SHARE_NAME=piha
NAS_USERNAME=your_nas_user
NAS_PASSWORD=changeMeSecure
NAS_MOUNT_DIR=/mnt/piha
PORTAINER_PASS=changeMePortainer
```

- Keep secrets out of version control; copy these files manually to each Raspberry Pi.

## Contributing / Updates

- Make sure to update `docs/llm/HANDOFF.md` and `docs/llm/HISTORY.md` with every change.
- Follow ASCII-only rule unless the file already contains non-ASCII.
- Never edit `.env.example` files manually; they are generated from user secrets.
