# LLM Work Handoff

## Current Status

Last Updated: 2025-09-28 - Codex
Session Focus: Replaced the MariaDB toggle with `RECORDER_BACKEND`, blocking SQLite-on-NAS and updating docs/test matrix for the new flow.
Status: Zigbee2MQTT stack remains stable on `cdelalamazigbee`; Home Assistant installer 1.2.0 now derives the recorder backend from `RECORDER_BACKEND`, forces local SQLite by default, and the uninstaller still honours purge prompts.

## Immediate Context

Current Work
- Home Assistant installer v1.2.0 introduces `RECORDER_BACKEND` (defaults to `sqlite`) and refuses SQLite on NAS; `HA_STORAGE_MODE` is now auto-managed while the uninstaller v1.1.0 still scrubs `.env` and honours purge prompts.
- Home Assistant test matrix updated to v1.2.0: scenario 1A/1B call out `RECORDER_BACKEND` usage and the enforced storage combinations.
- MariaDB helper (`home-assistant/mariadb/setup-nas-mariadb.sh` v1.0.9) supports local execution, forces docker compose to consume the bundled file, and the NAS guide is vendor-agnostic.
- Zigbee2MQTT installer v1.1.3 is validated on production host `cdelalamazigbee`; containers `zigbee2mqtt`, `mosquitto`, and `portainer_z2m` are up with MQTT exposed on 1883 and the UI on 8080.

Active Files
- docs/PROJECT_CONTEXT.md (component status updated for production Zigbee2MQTT)
- docs/llm/HANDOFF.md (this file)
- docs/llm/HISTORY.md (recent session log)
- home-assistant/install-home-assistant.sh (v1.2.0 RECORDER_BACKEND + storage enforcement)
- home-assistant/uninstall-home-assistant.sh (v1.1.0 env scrub + interactive purge prompts)
- home-assistant/mariadb/setup-nas-mariadb.sh (v1.0.9 local/remote aware)
- home-assistant/TEST_MATRIX.md (v1.2.0 recorder backend scenarios)
- zigbee2mqtt/install-zigbee2mqtt.sh (v1.1.3 production-proven)

Current Versions
- node-red/install-node-red.sh: 1.0.67
- node-red/PiHA-Deployer-NodeRED.sh: 1.0.34
- node-red/configure-syncthing.sh: 1.1.5
- node-red/load_env_vars.sh: 1.0.4
- home-assistant/install-home-assistant.sh: 1.2.0
- home-assistant/mariadb/setup-nas-mariadb.sh: 1.0.9
- zigbee2mqtt/install-zigbee2mqtt.sh: 1.1.3

## Top Priorities

1) **VERIFY**: Execute Test Matrix scenario 1H (run the uninstaller, then fresh installs 1A/1B) to confirm `.env` removal, local SQLite path recreation, the cooldown message, purge prompts, directory cleanup, automatic PyMySQL restart messaging, and container health on a clean run.
2) **DECIDE**: Confirm whether MariaDB data should stay under `${NAS_DEPLOY_DIR}/data` (current default) or move to a different NAS path. Update README + `.env` if needed.
3) **VALIDATE**: Run `home-assistant/mariadb/setup-nas-mariadb.sh` against the QNAP with the new defaults to confirm directories and permissions.
4) **DOCUMENT**: Capture the production Zigbee2MQTT deployment footprint (host `cdelalamazigbee`, NAS paths, monitoring/log rotation) and fold it into component docs/ops notes.
5) **LATER**: Execute full Home Assistant + NAS MariaDB flow with `RECORDER_BACKEND=mariadb` (legacy: `ENABLE_MARIADB_CHECK=true`) and document recorder migration.
6) **ONGOING**: Keep HISTORY and HANDOFF current; document any new env vars or behavioural changes.
7) **DOC**: Record the final decision on MariaDB data directory layout for future automation runs.

## Do Not Touch

- Node-RED script logic (stable) unless explicitly requested
- Existing docker-compose service definitions

## Open Questions

- Central Portainer Server + Agents: postpone until HA + Zigbee stacks are validated.
- Additional Home Assistant sidecar services (MQTT broker, etc.): future scope.

## Testing Notes

During development you may copy files from Windows to the Pi using a Samba share on the Pi. For production, rely on GitHub-based installs.


