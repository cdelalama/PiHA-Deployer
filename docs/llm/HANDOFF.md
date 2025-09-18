# LLM Work Handoff

## Current Status

Last Updated: 2025-09-17 - Claude
Session Focus: Project restructuring - moved MariaDB to correct architectural location
Status: MAJOR ARCHITECTURAL CHANGE - Moved nas/ directory to home-assistant/mariadb/ for consistency. Updated all references across documentation and scripts. MariaDB is specific to Home Assistant recorder, not general NAS service. QNAP path issues remain (script expects /opt/piha-mariadb but should use /share/Container/compose/mariadb). Cleaned NAS_CONFIGURATION.md to be vendor-agnostic. Next: fix QNAP-specific paths in setup script.

## Immediate Context

Current Work
- **ARCHITECTURAL RESTRUCTURE**: Moved nas/ → home-assistant/mariadb/ (MariaDB is HA-specific, not general NAS service)
- Updated all references: URLs, paths, documentation across 9+ files
- Path updates: nas/setup-nas-mariadb.sh → home-assistant/mariadb/setup-nas-mariadb.sh
- Project structure now consistent: each directory = Pi component, MariaDB inside HA as dependency
- NAS_CONFIGURATION.md cleaned: removed MariaDB specifics, now vendor-agnostic NAS guide
- **REMAINING ISSUE**: setup-nas-mariadb.sh still defaults to `/opt/piha-mariadb` (needs QNAP `/share/Container/compose/mariadb`)
- QNAP structure analyzed: Docker at `/share/ZFS530_DATA/.qpkg/container-station/`, user containers at `/share/Container/`
- Home Assistant installer v1.1.5: MariaDB check aborts when unavailable, auto-configures recorder when reachable
- All Quick Start sections standardized with working directory guidance and commit message policy added

Active Files
- **MOVED**: nas/ → home-assistant/mariadb/ (complete restructure)
- home-assistant/mariadb/setup-nas-mariadb.sh (NEEDS QNAP PATH FIXES)
- docs/NAS_CONFIGURATION.md (cleaned, vendor-agnostic)
- docs/PROJECT_CONTEXT.md (updated structure tree)
- README.md (updated references to new mariadb location)
- home-assistant/README.md (updated MariaDB references)
- home-assistant/install-home-assistant.sh (v1.1.5; updated bootstrap URLs)
- docs/llm/HANDOFF.md (this file)
- docs/llm/HISTORY.md (pending restructure entry)
- LLM_START_HERE.md (commit message policy added)

Current Versions
- node-red/install-node-red.sh: 1.0.67
- node-red/PiHA-Deployer-NodeRED.sh: 1.0.34
- node-red/configure-syncthing.sh: 1.1.5
- node-red/load_env_vars.sh: 1.0.4
- home-assistant/install-home-assistant.sh: 1.1.5
- home-assistant/mariadb/setup-nas-mariadb.sh: 1.0.0 (moved from nas/)
- zigbee2mqtt/install-zigbee2mqtt.sh: 1.1.3

## Top Priorities

1) **URGENT**: Fix QNAP paths in home-assistant/mariadb/setup-nas-mariadb.sh
   - Update NAS_DEPLOY_DIR default from `/opt/piha-mariadb` to `/share/Container/compose/mariadb`
   - Update MARIADB_DATA_DIR default to `/share/Container/compose/mariadb/data`
   - Test one-liner curl command with proper working directory
2) **NEXT**: Deploy Zigbee2MQTT on fresh Pi for relay tests
   - Flash clean Raspberry Pi OS, connect SONOFF dongle, populate `.env` with values above
   - Run `install-zigbee2mqtt.sh`, confirm `/dev/zigbee` mapping, Mosquitto auth (or anon) and Zigbee2MQTT UI availability
   - Pair relay devices and verify MQTT reachability from existing Home Assistant instance
3) **LATER**: Validate Home Assistant v1.1.5 + NAS MariaDB setup
   - Run `home-assistant/mariadb/setup-nas-mariadb.sh` against real NAS `.env`, ensure container starts and port 3306 reachable
   - Execute `home-assistant/install-home-assistant.sh` with `ENABLE_MARIADB_CHECK=true` and full `MARIADB_*` variables
   - Confirm recorder migration and document outcomes (success + any manual tweaks)
4) **ONGOING**: Documentation & coordination hygiene
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



