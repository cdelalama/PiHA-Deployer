## 2025-10-03 - ChatGPT - Hybrid SQLite layout for HA + preserve Zigbee config

Summary: Home Assistant installer v1.3.0 now keeps configuration on the NAS while mounting the SQLite recorder locally, migrates legacy installs, and ensures the uninstaller cleans the new directory; Zigbee2MQTT installer skips rewriting configuration.yaml after the first run. Documentation, compose, and test matrix updated to reflect the hybrid behaviour.

Files updated:
- home-assistant/install-home-assistant.sh (hybrid SQLite mode, migration helpers, version 1.3.0)
- home-assistant/docker-compose.yml (bind mount ${SQLITE_DATA_DIR} into /config/.sqlite-local)
- home-assistant/uninstall-home-assistant.sh (v1.1.1 removes local recorder directory)
- home-assistant/README.md
- home-assistant/TEST_MATRIX.md (v1.3.0 scenarios)
- home-assistant/.env.example
- README.md
- docs/PROJECT_CONTEXT.md
- docs/llm/HANDOFF.md
- zigbee2mqtt/install-zigbee2mqtt.sh (preserve configuration.yaml when present)
- zigbee2mqtt/README.md
- docs/llm/HISTORY.md (this entry)

Version impact: yes (home-assistant/install-home-assistant.sh -> 1.3.0, home-assistant/uninstall-home-assistant.sh -> 1.1.1)

---`n## 2025-09-28 - Codex - Enforce recorder backend switch and block SQLite-on-NAS

Summary: Introduced `RECORDER_BACKEND` in the Home Assistant installer (v1.2.0) to derive the recorder backend, removed `HA_STORAGE_MODE`, forbade SQLite-on-NAS, and refreshed documentation/test matrix accordingly.

Files updated:
- home-assistant/install-home-assistant.sh (v1.2.0 recorder backend normalization)
- README.md
- home-assistant/.env.example
- home-assistant/.env (session-only update: set RECORDER_BACKEND=sqlite)
- home-assistant/README.md
- home-assistant/TEST_MATRIX.md
- docs/llm/HANDOFF.md
- docs/llm/HISTORY.md (this entry)

Version impact: yes (home-assistant/install-home-assistant.sh -> 1.2.0)
Notes: Install runs now choose between `RECORDER_BACKEND=sqlite` (local `/var/lib/piha/home-assistant`) and `RECORDER_BACKEND=mariadb` for NAS; legacy `ENABLE_MARIADB_CHECK` is still honoured but maps to the new backend value.

---
## 2025-09-21 - Codex - Add interactive purge prompts to HA uninstaller

Summary: Bumped `home-assistant/uninstall-home-assistant.sh` to v1.1.0 so interactive runs ask about purging the working directory and project images while keeping automation flags available. Updated README/test matrix guidance and synced HANDOFF with the new workflow.

Files updated:
- home-assistant/uninstall-home-assistant.sh (v1.1.0 interactive purge prompts)
- home-assistant/README.md
- home-assistant/TEST_MATRIX.md
- docs/llm/HANDOFF.md
- docs/llm/HISTORY.md (this entry)

Version impact: yes (home-assistant/uninstall-home-assistant.sh -> 1.1.0)
Notes: Interactive runs now display a blue curl confirmation message, prompt about purging the workspace/images, and still default to removing `.env` unless `--keep-env` is chosen.

---

## 2025-09-21 - Codex - Prepare HA reset test plan

Summary: Updated the Home Assistant test matrix to v1.1.13 with the end-to-end reset scenario (1H), switched the curl download to -fSL with a blue English confirmation message, and refreshed HANDOFF priorities to point at executing the uninstall -> reinstall validation.

Files updated:
- home-assistant/TEST_MATRIX.md
- docs/llm/HANDOFF.md
- docs/llm/HISTORY.md (this entry)

Version impact: no (documentation and coordination updates only).
Notes: Scenario 1H now guides running the uninstaller followed by fresh installs 1A/1B to confirm PyMySQL restart messaging; the curl command runs with -fSL (progress shown) and prints a blue reminder when the download completes.

---
## 2025-09-21 - Codex - Align Zigbee2MQTT docs with production stack

Summary: Documented that Zigbee2MQTT is already running on host cdelalamazigbee, refreshed component status, and updated HANDOFF priorities so future work captures the production footprint.

Files updated:
- docs/PROJECT_CONTEXT.md
- docs/llm/HANDOFF.md
- docs/llm/HISTORY.md (this entry)

Version impact: no (documentation alignment only).
Notes: Zigbee2MQTT stack validated with running containers (`zigbee2mqtt`, `mosquitto`, `portainer_z2m`) and MQTT exposed on 1883 with UI on 8080.

---

## 2025-09-21 - Codex - Auto-restart HA after PyMySQL injection

Summary: Home Assistant installer v1.1.13 now restarts the running container when rewriting requirements for MariaDB recorder so users don?t have to reboot manually.

Files updated:
- home-assistant/install-home-assistant.sh (v1.1.13 restarts homeassistant via docker compose restart)
- home-assistant/README.md (clarify restart handled automatically)
- home-assistant/TEST_MATRIX.md (reuse scenarios note the automatic restart)
- docs/llm/HANDOFF.md (version/priorities refreshed)
- docs/llm/HISTORY.md (this entry)

Version impact: yes (home-assistant/install-home-assistant.sh -> 1.1.13)
Notes: re-running the installer over existing data now fully configures MariaDB without manual docker commands.

---

## 2025-09-21 - Codex - Warn about restart when reusing HA stack

Summary: Installer v1.1.12 now tells users to restart Home Assistant if the container was already running when MariaDB recorder config is updated, so the new requirements take effect automatically.

Files updated:
- home-assistant/install-home-assistant.sh (v1.1.12 emits restart hint when `homeassistant` is running)
- home-assistant/README.md (mention restart after automatic PyMySQL entry)
- home-assistant/TEST_MATRIX.md (reuse scenarios remind to restart container)
- docs/llm/HANDOFF.md (status/priorities updated)
- docs/llm/HISTORY.md (this entry)

Version impact: yes (home-assistant/install-home-assistant.sh -> 1.1.12)
Notes: Reinstalling over existing data now clearly prompts for a container restart to load `requirements.txt` changes.

---

## 2025-09-21 - Codex - Auto-manage PyMySQL requirement

Summary: Home Assistant installer v1.1.11 now ensures `${HA_DATA_DIR}/requirements.txt` includes PyMySQL when MariaDB is enabled so the recorder loads the MySQL driver automatically.

Files updated:
- home-assistant/install-home-assistant.sh (v1.1.11 writes PyMySQL==1.1.0 to requirements.txt)
- home-assistant/README.md (document automatic PyMySQL handling)
- home-assistant/TEST_MATRIX.md (expectations mention requirements.txt)
- docs/llm/HANDOFF.md (status/version updates)
- docs/llm/HISTORY.md (this entry)

Version impact: yes (home-assistant/install-home-assistant.sh -> 1.1.11)
Notes: Users no longer need to install PyMySQL manually; a restart after installation pulls the dependency.

---

## 2025-09-21 - Codex - Fix NAS helper compose copy

Summary: When running setup-nas-mariadb.sh from the deployment directory the helper now redownloads docker-compose.yml if it is missing, preventing the 'stat ... no such file or directory' failure.

Files updated:
- home-assistant/mariadb/setup-nas-mariadb.sh (v1.0.9 ensures compose file exists before skipping copy)
- home-assistant/README.md (clarify `.env` reuse for MariaDB helper)
- home-assistant/mariadb/README.md (explicitly mention copying home-assistant/.env)
- docs/llm/HISTORY.md (this entry)

Version impact: yes (home-assistant/mariadb/setup-nas-mariadb.sh -> 1.0.9)
Notes: Running the helper in-place on the NAS now bootstraps docker-compose.yml automatically even after cleanup.

---

## 2025-09-21 - Codex - Harden NAS helper compose defaults

Summary: Tweaked the NAS MariaDB helper so `docker compose` always loads the local file and shipped a `.env.example` to simplify bootstrapping.

Files updated:
- home-assistant/mariadb/setup-nas-mariadb.sh (v1.0.8 uses `-f docker-compose.yml` when starting containers)
- home-assistant/mariadb/.env.example (new template with required variables)
- home-assistant/README.md (Quick Start points to .env template)
- home-assistant/mariadb/README.md (references the example file)
- docs/llm/HANDOFF.md (status notes updated)
- docs/llm/HISTORY.md (this entry)

Version impact: yes (home-assistant/mariadb/setup-nas-mariadb.sh -> 1.0.8)
Notes: Running the helper directly on the NAS no longer fails with 'no configuration file provided'.

---

## 2025-09-21 - Codex - Document shared env requirement

Summary: Clarified that installers load shared defaults from `common/common.env`, updated Quick Start/Test Matrix to recreate it after purges, and added an installer hint when required vars are missing.

Files updated:
- home-assistant/install-home-assistant.sh (missing var hint references common/common.env)
- home-assistant/README.md (Quick Start + reset instructions call out recreating common/common.env)
- home-assistant/TEST_MATRIX.md (prep steps mention common/common.env)
- docs/llm/HANDOFF.md (status/priorities mention new reminder)
- docs/llm/HISTORY.md (this entry)

Version impact: no (installer message tweak only).
Notes: After running the uninstaller with `--purge-local`, users must repopulate both `common/common.env` and `.env` before reinstalling.

---

## 2025-09-21 - Codex - Remove .env during HA uninstall

Summary: Bumped the Home Assistant uninstaller to v1.0.9, deleting `.env`/`.env.bootstrap` by default, adding a `--keep-env` toggle, and clarifying docs/test coverage for the new behaviour.

Files updated:
- home-assistant/uninstall-home-assistant.sh (v1.0.9 with .env cleanup + --keep-env option)
- home-assistant/.env.example (document UNINSTALL_KEEP_ENV)
- home-assistant/README.md (reset section clarifies .env removal + new flag)
- home-assistant/TEST_MATRIX.md (1G expectations cover .env cleanup)
- docs/llm/HANDOFF.md (status/priorities refreshed)
- docs/llm/HISTORY.md (this entry)

Version impact: yes (home-assistant/uninstall-home-assistant.sh -> 1.0.9)
Notes: Unless `--keep-env`/`UNINSTALL_KEEP_ENV=true` is supplied, the uninstaller removes credential files but leaves the working dir unless `--purge-local` is requested.

---

## 2025-09-20 - Codex - Ensure HA uninstaller finds docker on QNAP

Summary: Tweaked the Home Assistant uninstaller to locate the docker binary on QNAP volumes, scope cleanups to the configurable MariaDB container, and optionally purge the Pi working directory and images.

Files updated:
- home-assistant/uninstall-home-assistant.sh (docker lookup fallback + configurable container name + purge flags, v1.0.8)
- home-assistant/mariadb/docker-compose.yml (container_name now configurable via env)
- home-assistant/.env.example (document MARIADB_CONTAINER_NAME and purge flags)
- home-assistant/README.md (mention container name override and purge options)
- home-assistant/TEST_MATRIX.md (automation notes for new flags)
- docs/llm/HANDOFF.md (version/reference update)

Version impact: yes (home-assistant/uninstall-home-assistant.sh -> 1.0.8)
Notes: Cleanup now targets `--filter name=^${MARIADB_CONTAINER_NAME:-mariadb}$`; use `--purge-local`/`--purge-images` (or env vars) to remove the Pi working directory and project images as part of the teardown.

---

## 2025-09-20 - Codex - Add Home Assistant uninstaller

Summary: Added a scripted teardown that stops the HA stack, removes NAS-hosted data directories, and (optionally) cleans the NAS MariaDB deployment over SSH (falling back to MARIADB_HOST, then NAS_IP, when NAS_SSH_HOST=localhost) and validates the remote docker path so cleanup works from the Pi.

Files updated:
- home-assistant/uninstall-home-assistant.sh (new helper script, v1.0.6)
- home-assistant/README.md (document reset instructions + interactive vs automation guidance)
- home-assistant/TEST_MATRIX.md (new scenario 1G for cleanup script)
- docs/llm/HANDOFF.md (status + tooling update)

Version impact: yes (home-assistant/uninstall-home-assistant.sh -> 1.0.6)
Notes: The uninstaller prompts before deleting; pipelines can pass --force and --skip-nas-ssh when needed. MariaDB cleanup requires the NAS SSH variables to be set.

---

## 2025-09-20 - Codex - Harden HA reuse flag parsing (v1.1.10)

Summary: Made the Home Assistant installer tolerant to inline comments/extra tokens when reading `HA_ALLOW_EXISTING_DATA`, ensuring non-interactive runs honor the flag. Cleaned up the generated `.env.example` and refreshed the test matrix version.

Files updated:
- home-assistant/install-home-assistant.sh (boolean parser trims comments/whitespace and falls back to .env parsing, bumped to v1.1.10)
- home-assistant/.env.example (deduplicated installer behaviour block)
- home-assistant/TEST_MATRIX.md (reflects installer v1.1.10)
- docs/llm/HANDOFF.md (status/version refresh)

Version impact: yes (home-assistant/install-home-assistant.sh -> 1.1.10)
Notes: Pipeline command `curl ... | sudo bash` now respects `HA_ALLOW_EXISTING_DATA=true` even when comments follow the value; existing data reuse behaves consistently across scenarios.

---

## 2025-09-20 - ChatGPT - Refine HA installer non-interactive behaviour

Summary: Updated the Home Assistant installer to abort without prompting when run via pipeline unless `HA_ALLOW_EXISTING_DATA=true` is set, keeping the interactive prompt for local executions.

Files updated:
- home-assistant/install-home-assistant.sh (non-interactive guard, now 1.1.8)
- home-assistant/.env.example (document HA_ALLOW_EXISTING_DATA)
- docs/llm/HANDOFF.md (version/status updated)

Version impact: yes (home-assistant/install-home-assistant.sh -> 1.1.8)
Notes: Pipeline runs (`curl � | sudo bash`) now exit immediately unless the reuse flag is set; interactive runs still prompt for confirmation.

---

## 2025-09-20 - ChatGPT - Remove legacy nas directory

Summary: Deleted the obsolete `nas/` helper folder now that MariaDB lives under `home-assistant/mariadb/`. All references now point to the maintained location.

Files updated:
- docs/llm/HANDOFF.md (note on removal)
- docs/llm/HISTORY.md (this entry)
- Removed `nas/` directory from repository

Version impact: yes (home-assistant/uninstall-home-assistant.sh -> 1.0.6)
Notes: Historical entries referencing `nas/` remain for context; future updates must use `home-assistant/mariadb/`.

---

## 2025-09-18 - Codex - Interactive reuse guard for Home Assistant

Summary: Home Assistant installer v1.1.7 now prompts to reuse existing NAS data when a TTY is available, while keeping the HA_ALLOW_EXISTING_DATA override for non-interactive runs.

Files updated:
- home-assistant/install-home-assistant.sh (interactive prompt + TTY detection, continues to support HA_ALLOW_EXISTING_DATA)
- home-assistant/README.md (document prompt vs override)
- home-assistant/.env.example (document HA_ALLOW_EXISTING_DATA usage)
- home-assistant/TEST_MATRIX.md (scenario checklist)
- docs/llm/HANDOFF.md (status + priorities refreshed)
- docs/llm/HISTORY.md (this entry)

Version impact: yes (home-assistant/install-home-assistant.sh -> 1.1.7)
Notes: Users running `curl ... | sudo bash` should pre-set HA_ALLOW_EXISTING_DATA=true if they intentionally keep old data; otherwise the installer asks interactively when possible.

---

## 2025-09-18 - Codex - Guard against stale Home Assistant data

Summary: The Home Assistant installer now halts when NAS data directories already contain configuration unless the operator opts in, preventing accidental reuse of old state.

Files updated:
- home-assistant/install-home-assistant.sh (warn/abort on existing data, `HA_ALLOW_EXISTING_DATA` override, v1.1.6)
- home-assistant/README.md (document the safety check)
- docs/llm/HANDOFF.md (status update)
- docs/llm/HISTORY.md (this entry)

Version impact: yes (home-assistant/install-home-assistant.sh -> 1.1.6)
Notes: Remove `${HA_DATA_DIR}` (and related NAS folders) or set `HA_ALLOW_EXISTING_DATA=true` before rerunning when you deliberately want to reuse state.

---

## 2025-09-18 - Codex - Drop docker-compose version field

Summary: Removed the deprecated `version` key from Home Assistant and MariaDB compose files to silence the compose v2 warning.

Files updated:
- home-assistant/docker-compose.yml (removed top-level version)
- home-assistant/mariadb/docker-compose.yml (removed top-level version)
- docs/llm/HISTORY.md (this entry)

Version impact: yes (home-assistant/uninstall-home-assistant.sh -> 1.0.6) (compose files only)
Notes: Compose v2 ignores `version`; removing it avoids noisy WARN0000 messages during installs.

---

## 2025-09-18 - Codex - Clarify NAS bootstrap guidance

Summary: Made the manual NAS bootstrap the default Home Assistant guidance, kept the SSH helper script as an optional alternative once `.env` is ready, and fixed NAS shell compatibility / bootstrap-env preservation in the helper.

Files updated:
- home-assistant/install-home-assistant.sh (bootstrap hint now prioritises manual steps and mentions optional automation)
- home-assistant/README.md (Quick Start aligned with curl-based install and working directory setup)
- home-assistant/mariadb/README.md (manual-first flow with single-command helper usage and optional automation)
- home-assistant/mariadb/setup-nas-mariadb.sh (local-bypass, compose fetch fallback, and bootstrap .env preservation, v1.0.7)
- docs/NAS_CONFIGURATION.md (NAS directory prep snippet + one-liner reference)
- docs/llm/HISTORY.md (this entry)

Version impact: yes (home-assistant/mariadb/setup-nas-mariadb.sh -> 1.0.7)
Notes: Manual NAS setup is now the recommended path for fresh installs; the helper script works on busybox/old bash shells and remains available locally or via SSH once `.env` exists.

---

# LLM Development History

## 2025-09-18 - Codex - Align MariaDB defaults with QNAP layout

Summary: Completed post-restructure cleanup by updating docs and scripts to reference `home-assistant/mariadb/` and baked in QNAP-friendly defaults for the NAS bootstrap script.

Files updated:
- README.md (component list now includes MariaDB + NAS guide)
- home-assistant/install-home-assistant.sh (links point to new MariaDB directory)
- home-assistant/mariadb/setup-nas-mariadb.sh (default paths + version 1.0.1)
- home-assistant/mariadb/README.md (default paths, ASCII cleanup)
- docs/NAS_CONFIGURATION.md (rewritten vendor guide)
- docs/llm/HANDOFF.md (status + priorities)
- docs/llm/HISTORY.md (this entry)

Version impact: yes (home-assistant/mariadb/setup-nas-mariadb.sh -> 1.0.1)
Notes: Need to validate the QNAP defaults on real hardware and remove the legacy `nas/` copies once confirmed obsolete. (Resolved 2025-09-20: legacy `nas/` directory removed.)

---


## 2024-01-06 - Claude - Documentation system implementation

Summary: Created minimal documentation structure for LLM coordination with single entry point and clear handoff mechanism.

Files created/updated:
- LLM_START_HERE.md (single entry point with critical rules)
- docs/PROJECT_CONTEXT.md (project overview and architecture)
- docs/VERSIONING_RULES.md (SemVer rules with quick reference)
- docs/llm/HANDOFF.md (operational handoff state)
- docs/llm/HISTORY.md (this file)

Version impact: yes (home-assistant/uninstall-home-assistant.sh -> 1.0.6)
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

Version impact: yes (home-assistant/uninstall-home-assistant.sh -> 1.0.6) (code behavior unchanged)
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

Version impact: yes (home-assistant/uninstall-home-assistant.sh -> 1.0.6) (new component scaffolding; existing components unchanged)
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

Version impact: yes (home-assistant/uninstall-home-assistant.sh -> 1.0.6)

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

Version impact: yes (home-assistant/uninstall-home-assistant.sh -> 1.0.6) (path behavior follows .env; default derivation only when env not set)

---

## 2025-09-06 - ChatGPT - Consolidate .env per host (HA and Node-RED)

Summary: Provided finalized .env templates for Home Assistant and Node-RED using Group-by-Host convention; ensured DOCKER_COMPOSE_DIR, data dirs and HOST_ID are consistent across components.

Docs touched:
- node-red/README.md (required variables include HOST_ID; recommended NAS paths)
- home-assistant/README.md (required variables include HOST_ID; recommended NAS paths)

Notes:
- User updated both .env files accordingly. Next step is on-device validation on HA Pi.
Version impact: yes (home-assistant/uninstall-home-assistant.sh -> 1.0.6) (env/config only)

---

## 2025-09-06 - ChatGPT - HA install check: missing PORTAINER_PASS

Summary: User ran HA installer; error reported missing `PORTAINER_PASS`. Added README notes and HANDOFF checklist to ensure required var is present and to escape `$` in passwords as `\$`.

Docs updated:
- home-assistant/README.md (password escape note)
- node-red/README.md (password escape note)
- docs/llm/HANDOFF.md (validation checklist bullet)

Version impact: yes (home-assistant/uninstall-home-assistant.sh -> 1.0.6)

---

## 2025-09-06 - ChatGPT - Harden .env parsing (no $ expansion, ignore non KEY=VALUE)

Summary: Improved .env loading to avoid accidental shell expansion (e.g., `$5`) and to ignore non-KEY lines. This prevents false negatives like missing variables due to formatting.

Files updated:
- home-assistant/install-home-assistant.sh (robust loader)
- node-red/load_env_vars.sh (robust loader)

Docs: password escape notes already present in component READMEs.

Version impact: yes (home-assistant/uninstall-home-assistant.sh -> 1.0.6) (behavior safer; no functional change intended)

---

## 2025-09-06 - ChatGPT - Normalize .env lines (BOM/NBSP)

Summary: Normalize .env input lines by stripping UTF-8 BOM, converting NBSP to regular space, and removing CR. Prevents missed variables when copy-pasting from rich editors.

Files updated:
- home-assistant/install-home-assistant.sh (line normalization in loader)
- node-red/load_env_vars.sh (line normalization in loader)

Version impact: yes (home-assistant/uninstall-home-assistant.sh -> 1.0.6)

---

## 2025-09-06 - ChatGPT - HA loader fallback for PORTAINER_PASS

Summary: Added a defensive fallback to recover `PORTAINER_PASS` directly from `.env` if the primary parser misses it due to edge formatting; improves robustness during on-device install.

Files updated:
- home-assistant/install-home-assistant.sh (post-load fallback)

Version impact: yes (home-assistant/uninstall-home-assistant.sh -> 1.0.6)
---

## 2025-09-06 - ChatGPT - Add optional shared config (common.env)

Summary: Installers now load optional shared env files before component .env to reduce duplication (defaults in common.env, overrides in .env). Documented precedence and suggested variables.

Code:
- home-assistant/install-home-assistant.sh (load ../common/common.env, common/common.env, ~/.piha/common.env, /etc/piha/common.env, then .env)
- node-red/load_env_vars.sh (same precedence)

Docs:
- docs/PROJECT_CONTEXT.md (Shared Configuration section with precedence)
- home-assistant/README.md and node-red/README.md (Optional shared config notes)

Version impact: yes (home-assistant/uninstall-home-assistant.sh -> 1.0.6)

---

## 2025-09-06 - ChatGPT - Standardize shared config location (common/Common.env)

Summary: Standardized shared config to common/Common.env (gitignored) as the primary location. Loaders extended to read that file (plus legacy fallbacks) before .env. Updated docs and READMEs accordingly.

Code:
- home-assistant/install-home-assistant.sh (load ../common/Common.env and common/Common.env first)
- node-red/load_env_vars.sh (same)

Docs:
- docs/PROJECT_CONTEXT.md (primary location and precedence)
- home-assistant/README.md and node-red/README.md (usage notes)

Version impact: yes (home-assistant/uninstall-home-assistant.sh -> 1.0.6)

---

## 2025-09-06 - ChatGPT - Add NAS MariaDB compose and HA recorder docs

Summary: Added `nas/docker-compose.yml` + `nas/README.md` to run MariaDB on NAS; documented Home Assistant recorder configuration to point to NAS MariaDB via secrets. Aims to avoid SQLite-on-SMB corruption and preserve history across Pi reinstalls.

Files added/updated:
- nas/docker-compose.yml (MariaDB service)
- nas/README.md (NAS setup and HA configuration)
- home-assistant/README.md (Recorder with MariaDB instructions)
- docs/llm/HANDOFF.md (status and next steps)

Version impact: yes (home-assistant/uninstall-home-assistant.sh -> 1.0.6)
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
---

## 2025-09-16 - Codex - Zigbee2MQTT Portainer password fix

Summary: Adjusted Zigbee2MQTT installer to store the Portainer admin password file inside `${PORTAINER_DATA_DIR}` so the compose command `--admin-password-file /data/portainer_password.txt` works on first boot. Bumped installer to v1.1.1 and refreshed docs.

Files updated:
- zigbee2mqtt/install-zigbee2mqtt.sh (now 1.1.1)
- zigbee2mqtt/README.md
- docs/PROJECT_CONTEXT.md
- docs/llm/HANDOFF.md

Version impact: yes (zigbee2mqtt installer bumped to 1.1.1)
Notes: No behavioural changes elsewhere; rerun installer or recreate the password file in `${PORTAINER_DATA_DIR}` if you ran v1.1.0 already.
---

## 2025-09-16 - Codex - Ensure Mosquitto config is created

Summary: Hardended Zigbee2MQTT installer (v1.1.2) to always create the Mosquitto configuration, even on fresh NAS directories. The script now pre-creates config/data/log folders, verifies `mosquitto.conf` exists, and tolerates CIFS mounts by relaxing chown errors. Docs updated accordingly.

Files updated:
- zigbee2mqtt/install-zigbee2mqtt.sh (now 1.1.2)
- zigbee2mqtt/README.md
- docs/PROJECT_CONTEXT.md
- docs/llm/HANDOFF.md

Version impact: yes (zigbee2mqtt installer bumped to 1.1.2)
Notes: Installer aborts if `mosquitto.conf` could not be written, avoiding silent container restarts.
---

## 2025-09-16 - Codex - Complete Zigbee2MQTT bootstrap config

Summary: Zigbee2MQTT installer (v1.1.3) now writes a full `configuration.yaml` (homeassistant integration, MQTT v5 keepalive, permit_join enabled, onboarding disabled) and tolerates CIFS permissions. Mosquitto config directories are created up front and `mqtt_auth_block` adds credentials cleanly. Docs updated with the new defaults.

Files updated:
- zigbee2mqtt/install-zigbee2mqtt.sh (now 1.1.3)
- zigbee2mqtt/README.md
- docs/PROJECT_CONTEXT.md
- docs/llm/HANDOFF.md

Version impact: yes (zigbee2mqtt installer bumped to 1.1.3)
Notes: Zigbee2MQTT UI should skip onboarding wizard on first boot; remember to disable `permit_join` manually after pairing.
---

## 2025-09-16 - Codex - HA installer MariaDB bootstrap hints

Summary: Bumped Home Assistant installer to v1.1.1. When MariaDB validation fails or is skipped, the script now prints a ready-to-run `curl` command (ssh to NAS + `setup-nas-mariadb.sh` from GitHub) so users can provision the database quickly. Updated README with the one-liner.

Files updated:
- home-assistant/install-home-assistant.sh (now 1.1.1)
- home-assistant/README.md
- docs/PROJECT_CONTEXT.md
- docs/llm/HANDOFF.md

Version impact: yes (home-assistant installer bumped to 1.1.1)
Notes: MariaDB check logic unchanged otherwise; ENABLE_MARIADB_CHECK still optional but now guides the bootstrap flow when missing.
---

## 2025-09-16 - Codex - HA installer curl-friendly compose

Summary: Home Assistant installer now auto-downloads `docker-compose.yml` from GitHub when missing, enabling `curl ... | sudo bash` usage. Bumped to v1.1.2.

Files updated:
- home-assistant/install-home-assistant.sh (now 1.1.2)
- README.md (project root quick-starts)
- docs/PROJECT_CONTEXT.md
- docs/llm/HANDOFF.md

Version impact: yes (home-assistant installer bumped to 1.1.2)
Notes: Root README adds quick-start one-liners for HA/Zigbee2MQTT/Node-RED.
---

## 2025-09-16 - Codex - Document common env usage

Summary: Updated root README with guidance on maintaining shared credentials in `common/Common.env` (gitignored) so multiple components can keep per-host `.env` files minimal.

Files updated:
- README.md

Version impact: yes (home-assistant/uninstall-home-assistant.sh -> 1.0.6) (documentation only)
Notes: Remind future installers that NAS credentials/UID/GID should live in the shared env file.
---

## 2025-09-17 - Claude - Fix README markup and standardize Quick Start instructions

Summary: Fixed broken code blocks in main README.md where `NAS_MOUNT_DIR` was outside the EOF block. Standardized working directory guidance across all three components (Home Assistant, Zigbee2MQTT, Node-RED) to follow consistent pattern: SSH + mkdir ~/piha-{component} + create common/Common.env + create .env + run installer.

Files updated:
- README.md (markup fixes, standardized Quick Start sections)
- docs/llm/HANDOFF.md (updated status and current work)
- docs/llm/HISTORY.md (this entry)

Version impact: yes (home-assistant/uninstall-home-assistant.sh -> 1.0.6) (documentation cleanup only)
Notes: All Quick Start sections now provide clear SSH instructions and specific working directory creation. Addresses user feedback about incomplete directory guidance.
---

## 2025-09-17 - Claude - Add commit message policy to LLM guidelines

Summary: Added mandatory commit message policy to LLM_START_HERE.md requiring all LLMs to provide commit title and description at the end of responses containing code changes. Also analyzed the significant improvements in Home Assistant installer v1.1.3 which now aborts installation when MariaDB is enabled but unavailable, and automatically configures recorder when MariaDB is reachable.

Files updated:
- LLM_START_HERE.md (commit message policy)
- docs/llm/HISTORY.md (this entry)

Version impact: yes (home-assistant/uninstall-home-assistant.sh -> 1.0.6) (documentation/policy only)
Notes: Future LLM responses with code changes must include commit information. HA installer v1.1.3 behavior significantly improved with automatic MariaDB recorder configuration.
---

## 2025-09-17 - Claude - Architectural restructure: move MariaDB into Home Assistant

Summary: Major architectural improvement - moved nas/ directory to home-assistant/mariadb/ for consistency. MariaDB is specific to Home Assistant recorder, not a general NAS service. Updated all references across documentation, scripts, and URLs. Cleaned NAS_CONFIGURATION.md to be vendor-agnostic. Project structure now follows pattern: each top-level directory = Pi component, dependencies inside respective components.

Files moved:
- nas/README.md -> home-assistant/mariadb/README.md
- nas/docker-compose.yml -> home-assistant/mariadb/docker-compose.yml
- nas/setup-nas-mariadb.sh -> home-assistant/mariadb/setup-nas-mariadb.sh

Files updated:
- README.md (updated MariaDB references and structure)
- docs/PROJECT_CONTEXT.md (updated project tree)
- docs/NAS_CONFIGURATION.md (cleaned MariaDB-specific content, now vendor-agnostic)
- home-assistant/README.md (updated MariaDB paths)
- home-assistant/install-home-assistant.sh (updated bootstrap URLs)
- docs/llm/HANDOFF.md (updated status, priorities, file locations)
- docs/llm/HISTORY.md (this entry)

Version impact: yes (home-assistant/uninstall-home-assistant.sh -> 1.0.6) (structural reorganization, no code logic changes)
Notes: QNAP path issue remains - setup-nas-mariadb.sh still defaults to /opt/piha-mariadb instead of /share/Container/compose/mariadb. Next LLM should fix these paths.
---

## 2025-09-16 - Codex - Enforce MariaDB check + auto recorder config

Summary: Home Assistant installer now aborts when `ENABLE_MARIADB_CHECK=true` and MariaDB is unavailable (printing the bootstrap command) and configures `secrets.yaml` + a managed `recorder` block automatically when the database is reachable. Also downloads `docker-compose.yml` if missing to support curl-based installs.

Files updated:
- home-assistant/install-home-assistant.sh (now 1.1.5)
- home-assistant/README.md (documented new behaviour)
- README.md (common env steps before running installers)
- README.md (Environment section reordered)
- docs/PROJECT_CONTEXT.md
- docs/llm/HANDOFF.md

Version impact: yes (home-assistant installer bumped to 1.1.5)
Notes: Managed recorder block is marked in `configuration.yaml`; existing manual recorder configs remain untouched.


