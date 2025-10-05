# LLM Work Handoff

## Current Status

Last Updated: 2025-10-05 - Codex
Session Focus: Added version/health reporting to the MariaDB installer and continued NAS infrastructure setup.
Status: MariaDB setup-nas script now reports compose version, waits for health, and shows `docker compose ps`; Mosquitto deployment remains pending.

## Immediate Context

- `infrastructure/mqtt/` contains the README, `.env.example`, compose file, and `setup-mosquitto.sh` helper (v1.0.0) for the NAS-hosted broker.
- Zigbee2MQTT README notes the forthcoming switch to the shared broker; the existing compose still includes Mosquitto until validation.
- `docs/RESTRUCTURE_PLAN.md` marks the Mosquitto migration complete and updates the next actions (control plane, Git sync, runbooks, Zigbee switchover planning).
- MariaDB relocation completed earlier; both shared services now live under `infrastructure/`.

## Active Files
- infrastructure/mariadb/** (unchanged since last handoff)
- infrastructure/mqtt/README.md
- infrastructure/mqtt/.env.example
- infrastructure/mqtt/docker-compose.yml
- infrastructure/mqtt/setup-mosquitto.sh
- zigbee2mqtt/README.md (shared broker note)
- docs/RESTRUCTURE_PLAN.md

## Current Versions
- node-red/install-node-red.sh: 1.0.67
- node-red/PiHA-Deployer-NodeRED.sh: 1.0.34
- node-red/configure-syncthing.sh: 1.1.5
- node-red/load_env_vars.sh: 1.0.4
- home-assistant/install-home-assistant.sh: 1.3.0
- home-assistant/uninstall-home-assistant.sh: 1.2.1
- infrastructure/mariadb/setup-nas-mariadb.sh: 1.1.0
- infrastructure/mqtt/setup-mosquitto.sh: 1.0.0
- zigbee2mqtt/install-zigbee2mqtt.sh: 1.1.3

## Top Priorities
1. Outline NAS control-plane responsibilities and PoE workflow in `application/control-plane/README.md`.
2. Design the delayed Git replication automation and freeze flag implementation.
3. Populate `docs/OPERATIONS/` with failover/backup runbooks once control-plane scaffolding exists.
4. Plan the Zigbee2MQTT switchover from embedded Mosquitto to the shared broker (validation steps, rollback).

## Do Not Touch
- Production Zigbee2MQTT compose (contains Mosquitto) until the shared broker is validated and a cut-over plan is approved.
- Legacy installers beyond the updated path references.

## Open Questions
- Final credential scheme and ACL rules for leadership topics (multiple users vs shared account).
- TLS requirements for the shared broker.
- Control-plane tooling stack (Bash vs Python vs Node-RED).

## Testing Notes
- No automated/manual tests executed; focus was file relocation and documentation.
- Plan validation sequence once control-plane and Zigbee switchover tasks are scheduled.

