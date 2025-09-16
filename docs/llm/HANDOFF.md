# LLM Work Handoff

## Current Status

Last Updated: 2025-09-16 - Codex
Session Focus: Harden Zigbee2MQTT installer/docs and note next validation steps for HA + MariaDB
Status: User runs Home Assistant via older script on one Pi. Zigbee2MQTT component hardened (installer v1.1.3: Portainer password, mosquitto.conf safeguards, full Zigbee config) and docs updated. Next: deploy Z2M on fresh Pi for relay tests, then validate HA v1.1.0 + NAS MariaDB.

## Immediate Context

Current Work
- Zigbee2MQTT installer v1.1.3: hashes MQTT credentials, persists detected USB path, writes Portainer password, ensures mosquitto.conf is generated, and ships a complete configuration.yaml (onboarding disabled)
- Zigbee2MQTT docs refreshed (required vars, group-by-host paths, MQTT auth note) + docker-compose defaults `${USB_DEVICE_PATH:-/dev/zigbee}`
- Home Assistant installer v1.1.0 + NAS bootstrap script remain ready for validation once Zigbee relays are confirmed
- Documentation synced (PROJECT_CONTEXT tree, HANDOFF, HISTORY) to reflect Zigbee component status

Active Files
- docs/PROJECT_CONTEXT.md (architecture & tree include Zigbee2MQTT)
- docs/llm/HANDOFF.md (this file)
- docs/llm/HISTORY.md (log updated with latest Zigbee2MQTT notes)
- zigbee2mqtt/install-zigbee2mqtt.sh (v1.1.3 hardening)
- zigbee2mqtt/docker-compose.yml (path quoting, USB default)
- zigbee2mqtt/README.md (required vars, auth guidance)
- nas/setup-nas-mariadb.sh (SSH bootstrap)

Current Versions
- node-red/install-node-red.sh: 1.0.67
- node-red/PiHA-Deployer-NodeRED.sh: 1.0.34
- node-red/configure-syncthing.sh: 1.1.5
- node-red/load_env_vars.sh: 1.0.4
- home-assistant/install-home-assistant.sh: 1.1.0
- zigbee2mqtt/install-zigbee2mqtt.sh: 1.1.3
- nas/setup-nas-mariadb.sh: 1.0.0

## Top Priorities

1) **URGENT**: Deploy Zigbee2MQTT on fresh Pi for relay tests
   - Flash clean Raspberry Pi OS, connect SONOFF dongle, populate `.env` with values above
   - Run `install-zigbee2mqtt.sh`, confirm `/dev/zigbee` mapping, Mosquitto auth (or anon) and Zigbee2MQTT UI availability
   - Pair relay devices and verify MQTT reachability from existing Home Assistant instance
2) **NEXT**: Validate Home Assistant v1.1.0 + NAS MariaDB setup
   - Run `nas/setup-nas-mariadb.sh` against real NAS `.env`, ensure container starts and port 3306 reachable
   - Execute `home-assistant/install-home-assistant.sh` with `ENABLE_MARIADB_CHECK=true` and full `MARIADB_*` variables
   - Confirm recorder migration and document outcomes (success + any manual tweaks)
3) **ONGOING**: Documentation & coordination hygiene
   - Append HISTORY entry after each change (mandatory)
   - Surface new required env vars in READMEs / VERSIONING_RULES as needed
   - Revisit centralized Portainer decision once HA + Zigbee stacks are stable

## Do Not Touch

- Node-RED script logic (stable) - do not modify without explicit request
- Working docker-compose configuration

## Open Questions (tracked)

- Central Portainer Server + Agents: when to implement? (defer until HA is stable)
- Additional HA sidecar services? (e.g., MQTT broker) - future scope

## Testing Notes (optional, for convenience)

During development you may copy files from Windows to the Pi using a Samba share on the Pi. For production, rely on GitHub-based install.



