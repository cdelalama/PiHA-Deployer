
# LLM Work Handoff

## Current Status

Last Updated: 2025-10-10 - Codex
Session Focus: HAOS heartbeat automation documented and Mosquitto/MariaDB validated for standby bring-up.
Status: Mosquitto bootstrap v1.0.6 and MariaDB v1.1.1 are healthy on the NAS. HAOS primary must copy/import \\pplication/home-assistant/leadership/automations/heartbeat.yaml\\ before installing the Docker standby so the leader publishes retained state/heartbeat messages.

## Immediate Context

- home-assistant/install-home-assistant.sh requires MariaDB reachability before launching containers.
- NAS Mosquitto bootstrap instructions cover compose download, credentialled healthcheck, and chmod fallback for CIFS shares.
- home-assistant/uninstall-home-assistant.sh cleans the NAS MariaDB deployment unless the operator keeps it.
- .env.example, README, and TEST_MATRIX describe the MariaDB-only workflow (no SQLite).
- Automation asset: copy/import pplication/home-assistant/leadership/automations/heartbeat.yaml into HAOS /config (or via UI) before enabling the standby.
- Shared infrastructure services live under infrastructure/ (mariadb/ v1.1.1, mqtt/ v1.0.6 with automatic data directory hardening).

## Active Files

- home-assistant/install-home-assistant.sh
- home-assistant/install-home-assistant.sh
- home-assistant/uninstall-home-assistant.sh
- home-assistant/docker-compose.yml
- home-assistant/.env.example
- home-assistant/README.md
- home-assistant/TEST_MATRIX.md
- application/home-assistant/leadership/automations/heartbeat.yaml
- application/home-assistant/leadership/README.md
- infrastructure/mqtt/setup-mosquitto.sh
- infrastructure/mqtt/docker-compose.yml
- infrastructure/mqtt/README.md
- docs/OPERATIONS/ha-dual-node.md
- docs/llm/HISTORY.md
- docs/llm/HANDOFF.md

## Current Versions
- home-assistant/install-home-assistant.sh: 1.4.0
- home-assistant/uninstall-home-assistant.sh: 1.3.0
- infrastructure/mariadb/setup-nas-mariadb.sh: 1.1.1
- infrastructure/mqtt/setup-mosquitto.sh: 1.0.6
- node-red/install-node-red.sh: 1.0.67
- node-red/PiHA-Deployer-NodeRED.sh: 1.0.34
- node-red/configure-syncthing.sh: 1.1.5
- node-red/load_env_vars.sh: 1.0.4
- zigbee2mqtt/install-zigbee2mqtt.sh: 1.1.3

## Top Priorities
1. Copy/import the HAOS heartbeat automation (heartbeat.yaml) to `/config` and verify retained MQTT messages before enabling the standby.
2. Install and validate the Docker standby on the second Raspberry Pi once the heartbeat is confirmed (follow docs/OPERATIONS/ha-dual-node.md).
3. Update dual-node runbooks and TEST_MATRIX with results from the HAOS/standby validation.
4. Resume control-plane design (MQTT leadership agent, PoE automation, delayed Git replication).
5. Plan the Zigbee2MQTT migration to the shared Mosquitto broker, including rollback steps.

## Do Not Touch
- Production Zigbee2MQTT compose (still bundling Mosquitto) until it is validated against the shared broker.
- Legacy installer branches not part of the restructure.

## Open Questions
- Migration steps for existing SQLite deployments? Document required manual actions before upgrading to v1.4.0.
- Final ACL/credential model for the leadership/control-plane topics on Mosquitto.
- Tooling choice for the control-plane watcher (Bash vs Python vs Node-RED scripts).

## Testing Notes
- No automated tests executed; changes validated manually on NAS/HAOS.
- Need to exercise installer/uninstaller prompts and error cases once access to the Pi + NAS lab is available.
