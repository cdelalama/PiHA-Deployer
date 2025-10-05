# LLM Work Handoff

## Current Status

Last Updated: 2025-10-05 - Codex
Session Focus: Documented the infrastructure migration plan for MariaDB and Mosquitto as part of the new repository layout.
Status: Infrastructure READMEs outline how MariaDB and Mosquitto will move into `infrastructure/`; scripts remain in legacy paths pending migration.

## Immediate Context

- `infrastructure/mariadb/README.md` describes the upcoming relocation of MariaDB assets and the required backup/restore playbook.
- `infrastructure/mqtt/README.md` captures the plan to extract Mosquitto from the Zigbee2MQTT stack and enforce leadership ACLs.
- `docs/RESTRUCTURE_PLAN.md` tracker updated (MariaDB/Mosquitto rows set to ?In progress?).
- No scripts moved yet; production services continue using legacy directories.

## Active Files
- infrastructure/mariadb/README.md
- infrastructure/mqtt/README.md
- docs/RESTRUCTURE_PLAN.md

## Current Versions
- node-red/install-node-red.sh: 1.0.67
- node-red/PiHA-Deployer-NodeRED.sh: 1.0.34
- node-red/configure-syncthing.sh: 1.1.5
- node-red/load_env_vars.sh: 1.0.4
- home-assistant/install-home-assistant.sh: 1.3.0
- home-assistant/uninstall-home-assistant.sh: 1.2.1
- home-assistant/mariadb/setup-nas-mariadb.sh: 1.0.9
- zigbee2mqtt/install-zigbee2mqtt.sh: 1.1.3

## Top Priorities
1. Physically move MariaDB scripts/compose into `infrastructure/mariadb/` and document backup/restore procedures.
2. Extract Mosquitto assets into `infrastructure/mqtt/` with ACL and credential alignment.
3. Draft NAS control-plane overview (`application/control-plane/README.md`).
4. Design delayed Git sync automation and freeze flag mechanism.
5. Populate operations runbooks once tooling is in place.

## Do Not Touch
- Production Zigbee2MQTT deployment until Mosquitto migration plan is executed with care.
- Legacy installer logic until new paths are wired and tested.

## Open Questions
- Final directory layout for NAS backups (where to store MariaDB dumps, MQTT configs).
- Whether Mosquitto will remain dockerized on NAS or move to dedicated VM/container stack.
- Automation tooling for control plane (language/runtime decision).

## Testing Notes
- No tests executed this session (documentation only).
- Plan for validation once services relocate (MariaDB connectivity, MQTT ACL enforcement).
