# PiHA-Deployer

Scripts and documentation to deploy a resilient home automation stack on Raspberry Pi with NAS-orchestrated failover. The project is being restructured to separate shared infrastructure (MariaDB, Mosquitto, Zigbee2MQTT, Node-RED, monitoring, VPN, PoE control) from application roles (Home Assistant OS primary, Docker standby, control plane).

## Repository Layout (Transition State)
- `infrastructure/` ? new home for NAS-managed services (scaffolded; migration in progress)
- `application/` ? new home for Home Assistant profiles and control plane tooling (scaffolded)
- `docs/` ? project context, restructure plan, operations runbooks (WIP)
- `home-assistant/`, `node-red/`, `zigbee2mqtt/` ? legacy locations for current installers (to be migrated)

See `docs/RESTRUCTURE_PLAN.md` for live tracking of the migration phases and ownership.

## Documentation Map
- `LLM_START_HERE.md` ? onboarding, policies, and workflow
- `docs/PROJECT_CONTEXT.md` ? architecture overview (updated for the restructure)
- `docs/RESTRUCTURE_PLAN.md` ? target layout, phases, and progress tracker
- `docs/VERSIONING_RULES.md` ? script version policy
- `docs/NAS_CONFIGURATION.md` ? NAS setup guidance (legacy; pending refresh)
- `docs/llm/HANDOFF.md` ? current focus / next steps
- `docs/llm/HISTORY.md` ? chronological change log

## Current Quick Starts (Legacy Paths)
While the new structure is populated, use the existing installers:
- **Home Assistant (Docker standby)** ? `home-assistant/install-home-assistant.sh`
- **Home Assistant uninstaller** ? `home-assistant/uninstall-home-assistant.sh`
- **Zigbee2MQTT stack** ? `zigbee2mqtt/install-zigbee2mqtt.sh`
- **Node-RED stack** ? `node-red/install-node-red.sh`

Each folder contains a README with detailed instructions and `.env` expectations. These assets will move into `application/` and `infrastructure/` as phases complete.

## Contribution Notes
- Update `docs/llm/HANDOFF.md` and `docs/llm/HISTORY.md` with every change.
- Keep documentation aligned: remove obsolete guidance when new behaviour is introduced.
- All code/comments in English; conversations with the user in Spanish.
- Follow the restructure plan when creating or moving files.

## Contact & Support
For operational questions during the transition, rely on the runbooks and trackers referenced above. The goal is a system that can recover remotely: NAS-led promotion, PoE power-cycle, and deliberate configuration sync with freeze control.

