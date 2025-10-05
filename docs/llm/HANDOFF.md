# LLM Work Handoff

## Current Status

Last Updated: 2025-10-05 - Codex
Session Focus: Formalised the MQTT leadership contract for Home Assistant failover and updated the restructure tracker accordingly.
Status: Leadership topic/payload schema documented; doc scaffolding for HAOS and standby complete. Infrastructure migration (MariaDB/Mosquitto) and control-plane drafts still pending.

## Immediate Context

- `application/home-assistant/leadership/README.md` now defines topics, payloads, timeouts, and actor responsibilities for leadership arbitration.
- `docs/RESTRUCTURE_PLAN.md` progress tracker marks the contract complete and lists new next actions (migrate MariaDB, outline control plane, design sync automation).
- No scripts changed yet; legacy installers continue operating from the root `home-assistant/` directory.
- Upcoming work: move services into `infrastructure/`, describe NAS control-plane workflow, document delayed Git replication.

## Active Files
- application/home-assistant/leadership/README.md (new detailed contract)
- docs/RESTRUCTURE_PLAN.md (tracker update)
- docs/llm/HISTORY.md (session log)

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
1. Migrate MariaDB documentation/scripts into `infrastructure/mariadb/` with backup/restore instructions.
2. Align Mosquitto guidance (leadership topics, auth) inside `infrastructure/mqtt/`.
3. Draft NAS control-plane overview in `application/control-plane/README.md` (health checks, PoE workflow, command publishing).
4. Document the delayed Git replication mechanism and freeze flag behaviour.
5. Populate runbooks in `docs/OPERATIONS/` once the above pieces exist.

## Do Not Touch
- Production Zigbee2MQTT configuration until migration plan approved.
- Legacy installers/uninstallers logic unless the new directories are ready to replace them.

## Open Questions
- Command acknowledgement strategy for `piha/leader/home-assistant/cmd`.
- Shared `events` schema across services (include duration, previous leader?).
- NAS control-plane implementation stack (Bash vs Python vs Node-RED flow).

## Testing Notes
- No automated/manual tests yet; focus was documentation.
- Need to design simulated promotion/demotion tests once the control-plane prototype exists.
