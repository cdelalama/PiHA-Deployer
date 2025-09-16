# LLM Development History

## 2024-01-06 - Claude - Documentation system implementation

Summary: Created minimal documentation structure for LLM coordination with single entry point and clear handoff mechanism.

Files created/updated:
- LLM_START_HERE.md (single entry point with critical rules)
- docs/PROJECT_CONTEXT.md (project overview and architecture)
- docs/VERSIONING_RULES.md (SemVer rules with quick reference)
- docs/llm/HANDOFF.md (operational handoff state)
- docs/llm/HISTORY.md (this file)

Version impact: none
Next priority: complete component READMEs and create home-assistant structure

---

## 2025-09-06 - ChatGPT - Docs cleanup and alignment

Summary: Cleaned encoding artifacts across docs; corrected Node-RED README prerequisites; synchronized LLM_START_HERE, HANDOFF, and HISTORY.

Files updated:
- LLM_START_HERE.md (clean rewrite, linear reading order, rules)
- docs/PROJECT_CONTEXT.md (cleaned, clarified architecture and structure)
- docs/VERSIONING_RULES.md (cleaned, clarified examples and process)
- docs/llm/HANDOFF.md (current state, priorities, do-not-touch)
- docs/llm/HISTORY.md (this entry)
- node-red/README.md (requirements corrected)

Version impact: none (code behavior unchanged)
Notes: Rule to update HANDOFF and HISTORY after every code change is emphasized in multiple files.
Env policy: Added clear guidance - do not edit .env.example (generated from .env), never change credentials in .env; document new vars and ask user to populate.

---

## 2025-09-06 - ChatGPT - Home Assistant scaffolding

Summary: Added home-assistant component scaffolding (README, installer, compose) and updated docs to reflect it.

Files added:
- home-assistant/install-home-assistant.sh (v1.0.0)
- home-assistant/docker-compose.yml
- home-assistant/README.md

Files updated:
- docs/PROJECT_CONTEXT.md (component structure)
- docs/llm/HANDOFF.md (current status, priorities, versions)

Version impact: none (new component scaffolding; existing components unchanged)
Notes: Installer installs Docker/Compose if missing, mounts NAS, binds data directories on NAS, deploys Portainer + Home Assistant. Environment file policy respected.

---

## 2025-09-06 - ChatGPT - Doc tweaks and installer IP autodetect

Summary: Cleaned non-ASCII separators in LLM docs; refined Home Assistant README Quick Start to create .env (not copy .env.example); added IP autodetection to HA installer output; no logic changes beyond display.

Files updated:
- LLM_START_HERE.md (clean ASCII; no content change to rules)
- docs/llm/HANDOFF.md (clean ASCII; clarified status and priorities)
- home-assistant/README.md (Quick Start and env notes)
- home-assistant/install-home-assistant.sh (auto-detect IP for URLs)
- node-red/README.md (align .env creation instructions)

Version impact: none

---

## 2025-09-06 - ChatGPT - Adopt Group-by-Host storage convention

Summary: Added Group-by-Host NAS convention; updated docs and adjusted installers to respect env-provided directories and derive NAS paths per HOST_ID.

Docs updated:
- docs/PROJECT_CONTEXT.md (Storage Layout Convention; examples)
- node-red/README.md (HOST_ID and recommended NAS paths)
- home-assistant/README.md (HOST_ID and recommended NAS paths; DOCKER_COMPOSE_DIR on NAS)

Installers updated:
- node-red/install-node-red.sh (create NAS dirs using env paths; keep nas_data shared)
- node-red/configure-syncthing.sh (permissions and markers based on env paths)
- home-assistant/install-home-assistant.sh (derive HA/Portainer/compose dirs from HOST_ID when missing)

Version impact: none (path behavior follows .env; default derivation only when env not set)

---

## 2025-09-06 - ChatGPT - Consolidate .env per host (HA and Node-RED)

Summary: Provided finalized .env templates for Home Assistant and Node-RED using Group-by-Host convention; ensured DOCKER_COMPOSE_DIR, data dirs and HOST_ID are consistent across components.

Docs touched:
- node-red/README.md (required variables include HOST_ID; recommended NAS paths)
- home-assistant/README.md (required variables include HOST_ID; recommended NAS paths)

Notes:
- User updated both .env files accordingly. Next step is on-device validation on HA Pi.
Version impact: none (env/config only)

---

## 2025-09-06 - ChatGPT - HA install check: missing PORTAINER_PASS

Summary: User ran HA installer; error reported missing `PORTAINER_PASS`. Added README notes and HANDOFF checklist to ensure required var is present and to escape `$` in passwords as `\$`.

Docs updated:
- home-assistant/README.md (password escape note)
- node-red/README.md (password escape note)
- docs/llm/HANDOFF.md (validation checklist bullet)

Version impact: none

---

## 2025-09-06 - ChatGPT - Harden .env parsing (no $ expansion, ignore non KEY=VALUE)

Summary: Improved .env loading to avoid accidental shell expansion (e.g., `$5`) and to ignore non-KEY lines. This prevents false negatives like missing variables due to formatting.

Files updated:
- home-assistant/install-home-assistant.sh (robust loader)
- node-red/load_env_vars.sh (robust loader)

Docs: password escape notes already present in component READMEs.

Version impact: none (behavior safer; no functional change intended)

---

## 2025-09-06 - ChatGPT - Normalize .env lines (BOM/NBSP)

Summary: Normalize .env input lines by stripping UTF-8 BOM, converting NBSP to regular space, and removing CR. Prevents missed variables when copy-pasting from rich editors.

Files updated:
- home-assistant/install-home-assistant.sh (line normalization in loader)
- node-red/load_env_vars.sh (line normalization in loader)

Version impact: none

---

## 2025-09-06 - ChatGPT - HA loader fallback for PORTAINER_PASS

Summary: Added a defensive fallback to recover `PORTAINER_PASS` directly from `.env` if the primary parser misses it due to edge formatting; improves robustness during on-device install.

Files updated:
- home-assistant/install-home-assistant.sh (post-load fallback)

Version impact: none
---

## 2025-09-06 - ChatGPT - Add optional shared config (common.env)

Summary: Installers now load optional shared env files before component .env to reduce duplication (defaults in common.env, overrides in .env). Documented precedence and suggested variables.

Code:
- home-assistant/install-home-assistant.sh (load ../common/common.env, common/common.env, ~/.piha/common.env, /etc/piha/common.env, then .env)
- node-red/load_env_vars.sh (same precedence)

Docs:
- docs/PROJECT_CONTEXT.md (Shared Configuration section with precedence)
- home-assistant/README.md and node-red/README.md (Optional shared config notes)

Version impact: none

---

## 2025-09-06 - ChatGPT - Standardize shared config location (common/Common.env)

Summary: Standardized shared config to common/Common.env (gitignored) as the primary location. Loaders extended to read that file (plus legacy fallbacks) before .env. Updated docs and READMEs accordingly.

Code:
- home-assistant/install-home-assistant.sh (load ../common/Common.env and common/Common.env first)
- node-red/load_env_vars.sh (same)

Docs:
- docs/PROJECT_CONTEXT.md (primary location and precedence)
- home-assistant/README.md and node-red/README.md (usage notes)

Version impact: none

---

## 2025-09-06 - ChatGPT - Add NAS MariaDB compose and HA recorder docs

Summary: Added `nas/docker-compose.yml` + `nas/README.md` to run MariaDB on NAS; documented Home Assistant recorder configuration to point to NAS MariaDB via secrets. Aims to avoid SQLite-on-SMB corruption and preserve history across Pi reinstalls.

Files added/updated:
- nas/docker-compose.yml (MariaDB service)
- nas/README.md (NAS setup and HA configuration)
- home-assistant/README.md (Recorder with MariaDB instructions)
- docs/llm/HANDOFF.md (status and next steps)

Version impact: none
---

## 2025-09-16 - Codex - Home Assistant MariaDB validation + NAS bootstrap

Summary: Added optional MariaDB reachability/credential checks to the Home Assistant installer (v1.1.0) and created a NAS automation script to provision MariaDB over SSH. Updated documentation (Home Assistant README, NAS README, PROJECT_CONTEXT, HANDOFF) with new environment variables and workflows.

Files added:
- nas/setup-nas-mariadb.sh (v1.0.0)

Files updated:
- home-assistant/install-home-assistant.sh (now 1.1.0)
- home-assistant/README.md
- nas/README.md
- docs/PROJECT_CONTEXT.md
- docs/llm/HANDOFF.md
- docs/llm/HISTORY.md (this entry)

Version impact: yes (home-assistant installer bumped to 1.1.0; new NAS script at 1.0.0)
Notes: New `.env` knobs: `ENABLE_MARIADB_CHECK`, `MARIADB_HOST`, `MARIADB_PORT`, `MARIADB_DATABASE`, `MARIADB_USER`, `MARIADB_PASSWORD`, plus NAS SSH variables for the bootstrap script.
---

## 2025-09-16 - Codex - Harden Zigbee2MQTT installer and docs

Summary: Improved Zigbee2MQTT deployment by hashing Mosquitto credentials, persisting the detected USB device path into `.env`, and aligning documentation with required variables and group-by-host conventions. Docker compose now defaults to `${USB_DEVICE_PATH:-/dev/zigbee}`. Project context updated to reflect the new component.

Files updated:
- zigbee2mqtt/install-zigbee2mqtt.sh (now 1.1.0)
- zigbee2mqtt/docker-compose.yml
- zigbee2mqtt/README.md
- docs/PROJECT_CONTEXT.md
- docs/llm/HANDOFF.md

Version impact: yes (zigbee2mqtt installer bumped to 1.1.0)
Notes: Mosquitto password hashes generated via containerized `mosquitto_passwd`; broker falls back to anonymous if credentials omitted. `.env` copy keeps the auto-detected `/dev/zigbee` path for subsequent compose runs.
