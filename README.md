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
2. Create a `.env` file with the required variables (see `home-assistant/README.md` for all variables).
3. Run the installer directly from GitHub (requires `curl` and `sudo`):
   ```bash
   curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/install-home-assistant.sh | sudo bash
   ```
   - The script auto-downloads `docker-compose.yml` if missing.
   - If `ENABLE_MARIADB_CHECK=true` and MariaDB is absent, it prints a command to bootstrap the NAS service.
4. Access Home Assistant at `http://<pi-ip>:8123` and Portainer at `http://<pi-ip>:9000`.

## Quick Start (Zigbee2MQTT)
1. SSH into your Pi and create a working directory:
   ```bash
   mkdir -p ~/piha-zigbee2mqtt && cd ~/piha-zigbee2mqtt
   ```
2. Create a `.env` file with the required variables (see `zigbee2mqtt/README.md` for all variables).
3. Ensure the SONOFF dongle is connected and run the installer:
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
2. Create a `.env` file with the required variables (see `node-red/README.md` for all variables).
3. Run the installer directly from GitHub:
   ```bash
   curl -sSL "https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/node-red/install-node-red.sh" | bash
   ```

## Contributing / Updates
- Make sure to update `docs/llm/HANDOFF.md` and `docs/llm/HISTORY.md` with every change.
- Follow ASCII-only rule unless the file already contains non-ASCII.
- Never edit `.env.example` files manually; they are generated from user secrets.
