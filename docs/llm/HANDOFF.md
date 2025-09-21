# LLM Work Handoff

## Current Status

Last Updated: 2025-09-20 - Codex
Session Focus: Hardened the Home Assistant installer reuse flow after the restructure so non-interactive runs honour reuse flags, while keeping QNAP-aligned defaults in place.
Status: Architectural move completed (MariaDB lives in `home-assistant/mariadb/`). Repository docs and installers now point to the new location. QNAP defaults were corrected and NAS guide rewritten in ASCII. Recent work hardened the NAS helper + Home Assistant installer to avoid surprises when data already exists.

## Immediate Context

Current Work
- Finalized architecture restructure: MariaDB assets now under `home-assistant/mariadb/`
- Root README component list updated to surface MariaDB subdirectory and NAS guide
- `home-assistant/install-home-assistant.sh` now at v1.1.9: references the new MariaDB path, halts when NAS data directories contain HA state, and correctly honours `HA_ALLOW_EXISTING_DATA` even when comments trail the value (interactive prompt locally; pipelines rely on the flag).
- `home-assistant/mariadb/setup-nas-mariadb.sh` now handles local execution (skips SSH & downloads compose when missing) while keeping remote/QNAP defaults; skips copying when source/destination match
- `home-assistant/mariadb/README.md` documents manual-first bootstrap, single-command helper, security notes, and highlights that MariaDB data lives at `MARIADB_DATA_DIR` (default `${NAS_DEPLOY_DIR}/data`)
- `home-assistant/README.md` Quick Start now mirrors the curl-based install workflow
- `docs/NAS_CONFIGURATION.md` rewritten as vendor-agnostic ASCII guide with NAS prep snippet
- Legacy `nas/` directory removed; `home-assistant/mariadb/` is now the sole MariaDB source (see HISTORY entry).
- `home-assistant/TEST_MATRIX.md` documents the agreed test scenarios (updated for installer v1.1.9)
- `home-assistant/.env.example` deduplicated the installer behaviour section so the reuse flag guidance stays single-sourced
- `home-assistant/docker-compose.yml` / `home-assistant/mariadb/docker-compose.yml` drop deprecated compose `version`
- `docs/llm/HISTORY.md` tracking latest helper + compose updates
- Known gap: script still unvalidated on real QNAP after default change

Active Files
- README.md (component map fix)
- home-assistant/README.md (Quick Start aligned with curl workflow + inline comment guidance for reuse flag)
- home-assistant/install-home-assistant.sh (path references + bootstrap hint)
- home-assistant/mariadb/setup-nas-mariadb.sh (v1.0.7 local/remote-aware helper)
- home-assistant/mariadb/README.md (manual-first docs + security notes)
- home-assistant/docker-compose.yml (version key removed)
- home-assistant/mariadb/docker-compose.yml (version key removed)
- docs/NAS_CONFIGURATION.md (rewritten guide + NAS prep snippet)
- docs/llm/HANDOFF.md (this file)
- docs/llm/HISTORY.md (recent entries added)

Current Versions
- node-red/install-node-red.sh: 1.0.67
- node-red/PiHA-Deployer-NodeRED.sh: 1.0.34
- node-red/configure-syncthing.sh: 1.1.5
- node-red/load_env_vars.sh: 1.0.4
- home-assistant/install-home-assistant.sh: 1.1.9
- home-assistant/mariadb/setup-nas-mariadb.sh: 1.0.7
- zigbee2mqtt/install-zigbee2mqtt.sh: 1.1.3

## Top Priorities

1) **DECIDE**: Confirm whether MariaDB data should stay under `${NAS_DEPLOY_DIR}/data` (current default) or move to a different NAS path. Update README + `.env` if needed.
2) **VALIDATE**: Run `home-assistant/mariadb/setup-nas-mariadb.sh` against the QNAP with the new defaults to confirm directories and permissions.
3) **NEXT**: Deploy Zigbee2MQTT on a fresh Pi for relay/device testing (same checklist as before).
4) **LATER**: Execute full Home Assistant + NAS MariaDB flow with `ENABLE_MARIADB_CHECK=true` and document recorder migration.
5) **ONGOING**: Keep HISTORY and HANDOFF current; document any new env vars or behavioural changes.
6) **DOC**: Record the final decision on MariaDB data directory layout for future automation runs.

## Do Not Touch

- Node-RED script logic (stable) unless explicitly requested
- Existing docker-compose service definitions

## Open Questions

- Central Portainer Server + Agents: postpone until HA + Zigbee stacks are validated.
- Additional Home Assistant sidecar services (MQTT broker, etc.): future scope.

## Testing Notes

During development you may copy files from Windows to the Pi using a Samba share on the Pi. For production, rely on GitHub-based installs.


