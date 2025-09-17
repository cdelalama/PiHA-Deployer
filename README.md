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
1. Create a working directory on the Pi and drop a `.env` file with the required variables (see `home-assistant/README.md`).
2. Run the installer directly from GitHub (requires `curl` and `sudo`):
   ```bash
   curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/install-home-assistant.sh | sudo bash
   ```
   - The script auto-downloads `docker-compose.yml` if missing.
   - If `ENABLE_MARIADB_CHECK=true` and MariaDB is absent, it prints a command to bootstrap the NAS service.
3. Access Home Assistant at `http://<pi-ip>:8123` and Portainer at `http://<pi-ip>:9000`.

## Quick Start (Zigbee2MQTT)
1. Prepare `.env` (see `zigbee2mqtt/README.md`) and run the installer:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/zigbee2mqtt/install-zigbee2mqtt.sh -o install-zigbee2mqtt.sh
   chmod +x install-zigbee2mqtt.sh
   sudo bash install-zigbee2mqtt.sh
   ```
   (Ensure the SONOFF dongle is connected; the script writes a full configuration and skips the onboarding wizard.)

## Quick Start (Node-RED)
- Refer to `node-red/README.md` for existing deployment instructions. A remote installer is available at:
  ```bash
  curl -sSL "https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/node-red/install-node-red.sh" | bash
  ```

## Contributing / Updates
- Make sure to update `docs/llm/HANDOFF.md` and `docs/llm/HISTORY.md` with every change.
- Follow ASCII-only rule unless the file already contains non-ASCII.
- Never edit `.env.example` files manually; they are generated from user secrets.
