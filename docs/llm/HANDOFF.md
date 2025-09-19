# LLM Work Handoff

## Current Status

Last Updated: 2025-09-18 - Codex
Session Focus: Clean up post-restructure issues and align MariaDB NAS defaults with QNAP layout.
Status: Architectural move completed (MariaDB lives in `home-assistant/mariadb/`). Repository docs and installers now point to the new location. QNAP defaults were corrected and NAS guide rewritten in ASCII.

## Immediate Context

Current Work
- Finalized architecture restructure: MariaDB assets now under `home-assistant/mariadb/`
- Root README component list updated to surface MariaDB subdirectory and NAS guide
- `home-assistant/install-home-assistant.sh` references the new MariaDB path and prints the updated bootstrap checklist
- `home-assistant/mariadb/setup-nas-mariadb.sh` defaults updated for QNAP (`/share/Container/compose/mariadb`)
- `home-assistant/mariadb/README.md` now promotes the manual NAS bootstrap flow and keeps the SSH helper as optional
- `home-assistant/README.md` Quick Start now mirrors the curl-based install workflow
- `docs/NAS_CONFIGURATION.md` rewritten as vendor-agnostic ASCII guide with NAS prep snippet
- Known gap: script still unvalidated on real QNAP after default change

Active Files
- README.md (component map fix)
- home-assistant/README.md (Quick Start aligned with curl workflow)
- home-assistant/install-home-assistant.sh (path references + bootstrap hint)
- home-assistant/mariadb/setup-nas-mariadb.sh (v1.0.1 defaults)
- home-assistant/mariadb/README.md (manual-first docs, optional automation)
- docs/NAS_CONFIGURATION.md (rewritten guide + NAS prep snippet)
- docs/llm/HANDOFF.md (this file)
- docs/llm/HISTORY.md (new entry required)

Current Versions
- node-red/install-node-red.sh: 1.0.67
- node-red/PiHA-Deployer-NodeRED.sh: 1.0.34
- node-red/configure-syncthing.sh: 1.1.5
- node-red/load_env_vars.sh: 1.0.4
- home-assistant/install-home-assistant.sh: 1.1.5
- home-assistant/mariadb/setup-nas-mariadb.sh: 1.0.1
- zigbee2mqtt/install-zigbee2mqtt.sh: 1.1.3

## Top Priorities

1) **VALIDATE**: Run `home-assistant/mariadb/setup-nas-mariadb.sh` against the QNAP with the new defaults to confirm directories and permissions.
2) **NEXT**: Deploy Zigbee2MQTT on a fresh Pi for relay/device testing (same checklist as before).
3) **LATER**: Execute full Home Assistant + NAS MariaDB flow with `ENABLE_MARIADB_CHECK=true` and document recorder migration.
4) **ONGOING**: Keep HISTORY and HANDOFF current; document any new env vars or behavioural changes.

## Do Not Touch

- Node-RED script logic (stable) unless explicitly requested
- Existing docker-compose service definitions

## Open Questions

- Central Portainer Server + Agents: postpone until HA + Zigbee stacks are validated.
- Additional Home Assistant sidecar services (MQTT broker, etc.): future scope.

## Testing Notes

During development you may copy files from Windows to the Pi using a Samba share on the Pi. For production, rely on GitHub-based installs.
