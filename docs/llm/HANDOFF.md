# LLM Work Handoff

## Current Status

Last Updated: 2025-10-07 - Codex
Session Focus: Mosquitto bootstrap hardens NAS data directory permissions and tolerates NAS shares without chown support.
Status: Home Assistant installer v1.4.0 validates the NAS MariaDB instance unconditionally. Mosquitto bootstrap 1.0.5 now copies compose assets, writes healthcheck credentials, enforces secure perms on mosquitto.db, and falls back to 770 when the NAS share rejects chown. Uninstaller v1.3.0 only prompts for preserving NAS config and MariaDB.

## Immediate Context

- `home-assistant/install-home-assistant.sh` requires MariaDB reachability before launching containers.
- NAS Mosquitto bootstrap instructions now cover the automatic docker-compose download, credentialled healthcheck, post-deployment checks, and passwd permission fix.
- `home-assistant/uninstall-home-assistant.sh` cleans the NAS MariaDB deployment unless the operator keeps it.
- `.env.example`, README, and TEST_MATRIX describe the MariaDB-only workflow; SQLite guidance was removed.
- Shared infrastructure services live under `infrastructure/` (`mariadb/` v1.1.1, `mqtt/` v1.0.4 with automatic data directory hardening).

## Active Files
- home-assistant/install-home-assistant.sh
- home-assistant/uninstall-home-assistant.sh
- home-assistant/docker-compose.yml
- home-assistant/.env.example
- home-assistant/README.md
- home-assistant/TEST_MATRIX.md
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
- infrastructure/mqtt/setup-mosquitto.sh: 1.0.5
- node-red/install-node-red.sh: 1.0.67
- node-red/PiHA-Deployer-NodeRED.sh: 1.0.34
- node-red/configure-syncthing.sh: 1.1.5
- node-red/load_env_vars.sh: 1.0.4
- zigbee2mqtt/install-zigbee2mqtt.sh: 1.1.3

## Top Priorities
1. Validate the MariaDB-only installer/uninstaller on hardware (fresh install, reuse flow, failure paths, NAS cleanup).
2. Update dual-node runbooks once both HAOS primary and Docker standby are proven against the shared MariaDB/MQTT services.
3. Continue the control-plane design (leadership topics, PoE automation, delayed Git replication).
4. Plan the Zigbee2MQTT migration to the shared Mosquitto broker, including rollback steps.

## Do Not Touch
- Production Zigbee2MQTT compose (still bundling Mosquitto) until the shared broker validation plan is complete.
- Legacy installer branches that were not part of this refactor.

## Open Questions
- Migration steps for existing SQLite deployments?document required manual actions before upgrading to v1.4.0.
- Final ACL and credential model for the leadership/control-plane topics on Mosquitto.
- Tooling choice for the control-plane watcher (Bash vs Python vs Node-RED scripts).

## Testing Notes
- No automated tests executed; manual validation pending on real hardware.
- Need to exercise installer/uninstaller prompts and error cases once access to the Pi + NAS lab is available.







