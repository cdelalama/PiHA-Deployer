# LLM Work Handoff

## Current Status

Last Updated: 2025-10-03 - ChatGPT
Session Focus: Added hybrid SQLite storage for Home Assistant and prevented Zigbee2MQTT from overwriting existing configuration files.
Status: Home Assistant installer 1.3.0 now keeps configuration on the NAS while isolating the SQLite database locally; the uninstaller 1.1.1 removes the recorder directory when wiping and lets you preserve NAS config. Zigbee2MQTT installer 1.1.3 preserves `configuration.yaml` after the first run; production stack on `cdelalamazigbee` remains healthy.

## Immediate Context

Current Work
- Home Assistant installer v1.3.0 keeps YAML/configuration on the NAS and mounts `${SQLITE_DATA_DIR}` locally for the recorder, migrating legacy installs automatically; uninstaller v1.1.1 now cleans that local recorder directory.
- Home Assistant test matrix updated to v1.3.0 to cover the hybrid SQLite mode (config on NAS, DB local) alongside the MariaDB scenarios.
- MariaDB helper (home-assistant/mariadb/setup-nas-mariadb.sh v1.0.9) unchanged; NAS guide still vendor-agnostic.
- Zigbee2MQTT installer v1.1.3 now seeds `configuration.yaml` only when missing so customised deployments persist; production host `cdelalamazigbee` remains stable (containers: zigbee2mqtt, mosquitto, portainer_z2m).

Active Files
- docs/PROJECT_CONTEXT.md (status + version table refreshed)
- docs/llm/HANDOFF.md (this file)
- docs/llm/HISTORY.md (recent session log)
- home-assistant/install-home-assistant.sh (v1.3.0 hybrid SQLite)
- home-assistant/uninstall-home-assistant.sh (v1.1.1 recorder dir cleanup + keep-config prompt)
- home-assistant/TEST_MATRIX.md (v1.3.0 scenario updates)
- README.md (root) & home-assistant/README.md (doc alignment)
- zigbee2mqtt/install-zigbee2mqtt.sh (v1.1.3 config preservation)
- zigbee2mqtt/README.md (config retention note)

Current Versions
- node-red/install-node-red.sh: 1.0.67
- node-red/PiHA-Deployer-NodeRED.sh: 1.0.34
- node-red/configure-syncthing.sh: 1.1.5
- node-red/load_env_vars.sh: 1.0.4
- home-assistant/install-home-assistant.sh: 1.3.0
- home-assistant/uninstall-home-assistant.sh: 1.1.1
- home-assistant/mariadb/setup-nas-mariadb.sh: 1.0.9
- zigbee2mqtt/install-zigbee2mqtt.sh: 1.1.3

## Top Priorities

1) **VERIFY**: Execute Test Matrix scenario 1A + 1H on real hardware to confirm the new hybrid SQLite layout (config reused from NAS, database recreated under `${SQLITE_DATA_DIR}`) and the uninstaller's keep-config branch vs full wipe, plus recorder directory cleanup.
2) **CHECK**: Re-run Zigbee2MQTT installer on `cdelalamazigbee` (or a lab box) to ensure `configuration.yaml` is left untouched after the first deployment.
3) **DECIDE**: Confirm whether MariaDB data should stay under `${NAS_DEPLOY_DIR}`/data (current default) or move to a different NAS path. Update README + `.env` if needed.
4) **VALIDATE**: Run home-assistant/mariadb/setup-nas-mariadb.sh against the QNAP with the new defaults to confirm directories and permissions.
5) **DOCUMENT**: Capture the production Zigbee2MQTT deployment footprint (host `cdelalamazigbee`, NAS paths, monitoring/log rotation) and fold it into component docs/ops notes.
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


