# LLM Work Handoff

## Current Status

Last Updated: 2025-09-21 - Codex
Session Focus: Tightened the Home Assistant uninstall/reset flow so `.env` secrets are scrubbed by default, added an opt-in keep flag, and synced documentation + test coverage.
Status: Architectural move completed (MariaDB lives in `home-assistant/mariadb/`). Repository docs and installers stay aligned with QNAP defaults. Latest work focuses on polishing the Home Assistant teardown tooling, defaulting to delete `.env`/`.env.bootstrap`, adding `--keep-env`, and documenting the behaviour across README + test matrix.

## Immediate Context

Current Work
- Finalized architecture restructure: MariaDB assets now under `home-assistant/mariadb/`
- Root README component list updated to surface MariaDB subdirectory and NAS guide
- `home-assistant/install-home-assistant.sh` now at v1.1.10: references the new MariaDB path, halts on existing NAS data, and falls back to parsing `.env` directly so pipelines honour `HA_ALLOW_EXISTING_DATA` even with inline comments or parsing edge cases (interactive prompt locally; pipelines rely on the flag).
- `home-assistant/mariadb/setup-nas-mariadb.sh` now handles local execution (skips SSH & downloads compose when missing), forces compose to read the bundled file, and keeps remote/QNAP defaults; skips copying when source/destination match
- `home-assistant/mariadb/README.md` documents manual-first bootstrap, single-command helper, security notes, and highlights that MariaDB data lives at `MARIADB_DATA_DIR` (default `${NAS_DEPLOY_DIR}/data`)
- `home-assistant/README.md` Quick Start now mirrors the curl-based install workflow
- `docs/NAS_CONFIGURATION.md` rewritten as vendor-agnostic ASCII guide with NAS prep snippet
- Legacy `nas/` directory removed; `home-assistant/mariadb/` is now the sole MariaDB source (see HISTORY entry).
- `home-assistant/TEST_MATRIX.md` documents the agreed test scenarios (updated for installer v1.1.10, cleanup script, and common/common.env prep)
- `home-assistant/.env.example` deduplicated the installer behaviour section so the reuse flag guidance stays single-sourced
- `home-assistant/uninstall-home-assistant.sh` teardown helper now at v1.0.9 (removes `.env`/`.env.bootstrap` by default, adds `--keep-env`, keeps purge flags + docker lookup fallbacks)
- `home-assistant/docker-compose.yml` / `home-assistant/mariadb/docker-compose.yml` drop deprecated compose `version`; new `.env.example` for MariaDB helper
- `docs/llm/HISTORY.md` tracking latest helper + compose updates
- Known gap: script still unvalidated on real QNAP after default change

Active Files
- README.md (component map fix)
- home-assistant/README.md (Quick Start now calls out recreating common/common.env + curl workflow guidance)
- home-assistant/install-home-assistant.sh (path references + bootstrap hint)
- home-assistant/uninstall-home-assistant.sh (teardown helper, v1.0.9 with .env cleanup + keep flag)
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
- home-assistant/install-home-assistant.sh: 1.1.10
- home-assistant/mariadb/setup-nas-mariadb.sh: 1.0.8
- zigbee2mqtt/install-zigbee2mqtt.sh: 1.1.3

## Top Priorities

1) **VERIFY**: Re-run `home-assistant/uninstall-home-assistant.sh` (interactive, pipeline, `--keep-env`, `--purge-local`) to confirm `.env` removal behaves as documented and that purge flags leave the Pi ready for reinstall; confirm reinstall requires restoring both `common/common.env` and `.env`.
2) **DECIDE**: Confirm whether MariaDB data should stay under `${NAS_DEPLOY_DIR}/data` (current default) or move to a different NAS path. Update README + `.env` if needed.
3) **VALIDATE**: Run `home-assistant/mariadb/setup-nas-mariadb.sh` against the QNAP with the new defaults to confirm directories and permissions.
4) **NEXT**: Deploy Zigbee2MQTT on a fresh Pi for relay/device testing (same checklist as before).
5) **LATER**: Execute full Home Assistant + NAS MariaDB flow with `ENABLE_MARIADB_CHECK=true` and document recorder migration.
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

