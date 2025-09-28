# PiHA-Deployer

Automation scripts to deploy the Pi Home Automation stack (Node-RED, Home Assistant, Zigbee2MQTT, supporting NAS services) on Raspberry Pi devices with NAS-backed persistence.

## Components

- **Home Assistant** (`home-assistant/`)
- **Zigbee2MQTT** (`zigbee2mqtt/`)
- **Node-RED** (`node-red/`)
- **Home Assistant / MariaDB** (`home-assistant/mariadb/`)
- **NAS guidance** (`docs/NAS_CONFIGURATION.md`)

## Documentation Map

- `LLM_START_HERE.md`: entry point with rules and checklist (read first)
- `docs/PROJECT_CONTEXT.md`: architecture, conventions, repo layout
- `docs/VERSIONING_RULES.md`: SemVer policy for scripts
- `docs/NAS_CONFIGURATION.md`: NAS-specific setup and directory structures
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
   - Choose the recorder backend with `RECORDER_BACKEND`: `sqlite` (default) keeps Home Assistant data on the Pi, `mariadb` uses the NAS database.
   - With `RECORDER_BACKEND=sqlite`, ensure `HA_STORAGE_MODE=sqlite_local` (default) and optionally override `SQLITE_DATA_DIR` (defaults to `/var/lib/piha/home-assistant`).
   - With `RECORDER_BACKEND=mariadb`, leave `HA_STORAGE_MODE` unset/`nas` and provide the full `MARIADB_*` block; the installer aborts if the database is unreachable.
   - `ENABLE_MARIADB_CHECK` is still read for legacy setups but the installer now derives it from `RECORDER_BACKEND`.
4. Run the installer directly from GitHub (requires `curl` and `sudo`):

- The script auto-downloads `docker-compose.yml` if missing.
- When `RECORDER_BACKEND=mariadb`, the installer validates MariaDB:
  - When the database is reachable, it configures `secrets.yaml` and `configuration.yaml` automatically.
  - When the database is missing or misconfigured, it prints the bootstrap command and **aborts**, so you can provision the database and rerun.
- Keep `RECORDER_BACKEND=sqlite` to stay on the local SQLite backend (the installer enforces `HA_STORAGE_MODE=sqlite_local`).
5. Access Home Assistant at `http://<pi-ip>:8123` and Portainer at `http://<pi-ip>:9000`.

### MariaDB on the NAS
- **IMPORTANT**: The one-liner bootstrap command requires NAS-specific configuration. See `docs/NAS_CONFIGURATION.md` for your NAS vendor setup.
- For QNAP NAS: Command currently broken - see HANDOFF.md for issue details
- Generic setup: If the installer reports that MariaDB is missing, run this on the NAS (replace `<nas-user>` and `<NAS_IP>`):
  ```bash
  ssh <nas-user>@<NAS_IP> "curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/mariadb/setup-nas-mariadb.sh | bash"
  ```
- After it finishes, rerun the Home Assistant installer with `RECORDER_BACKEND=mariadb`.

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
