# LLM Work Handoff

## Current Status

Last Updated: 2025-10-05 - Codex
Session Focus: Kick-off of the repository restructure (infrastructure vs application split) and documentation realignment.
Status: Target layout published with scaffolded directories under `infrastructure/` and `application/`; restructure plan and core docs updated. Legacy installers remain in place until migration phases move them.

## Immediate Context

- `docs/RESTRUCTURE_PLAN.md` captures the target tree, configuration contract, phased roadmap, and progress tracker.
- `docs/PROJECT_CONTEXT.md` and the root `README.md` now describe the layered architecture and reference the restructure plan.
- Placeholder READMEs created for new directories (infrastructure services, application roles, operations runbooks).
- Legacy component READMEs include a notice pointing to the ongoing migration.
- No scripts or compose files have been relocated yet; functional behaviour is unchanged.

## Active Files
- docs/RESTRUCTURE_PLAN.md (new)
- docs/PROJECT_CONTEXT.md (rewritten for new architecture)
- README.md (root navigation updated)
- infrastructure/** (scaffolding)
- application/** (scaffolding)
- docs/OPERATIONS/README.md (placeholder)
- home-assistant/README.md (restructure notice)
- node-red/README.md (restructure notice)
- zigbee2mqtt/README.md (restructure notice)

## Current Versions
- node-red/install-node-red.sh: 1.0.67 (no changes)
- node-red/PiHA-Deployer-NodeRED.sh: 1.0.34
- node-red/configure-syncthing.sh: 1.1.5
- node-red/load_env_vars.sh: 1.0.4
- home-assistant/install-home-assistant.sh: 1.3.0
- home-assistant/uninstall-home-assistant.sh: 1.2.1
- home-assistant/mariadb/setup-nas-mariadb.sh: 1.0.9
- zigbee2mqtt/install-zigbee2mqtt.sh: 1.1.3

## Top Priorities
1. **Docs**: Flesh out `application/home-assistant/` (HAOS vs Docker standby) and document MQTT leadership contract + delayed sync policy.
2. **Infrastructure Migration**: Move MariaDB and Mosquitto assets into `infrastructure/` with refreshed guidance and cross-links.
3. **Control Plane**: Draft the NAS orchestration workflow (health checks, heartbeat topics, PoE integration) inside `application/control-plane/`.
4. **Runbooks**: Populate `docs/OPERATIONS/` with failover, return-to-primary, backup validation, and Zigbee coordinator swap procedures.
5. **Testing**: Plan validation strategy for leadership promotion/demotion and recorder integrity once tooling lands.

## Do Not Touch
- Existing installer/uninstaller logic until documentation under the new structure is ready to replace it.
- Zigbee2MQTT production configuration files (coordinate with user before modifications).

## Open Questions
- MQTT topic hierarchy and payload schema for leadership heartbeats.
- Git repository layout for delayed config sync (one repo per host vs monorepo).
- PoE switch API specifics (model, authentication, rate limits).

## Testing Notes
- No automated or manual tests were run in this session (documentation-only changes).
- Once control plane scripts exist, design mock/simulated environments for promotion drills before touching production hardware.
