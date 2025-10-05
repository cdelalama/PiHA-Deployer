# PiHA Replatforming Plan

## Objective
Reorganize PiHA-Deployer to follow the new architecture: a resilient, NAS-orchestrated automation stack with clear separation between shared infrastructure services and application failover roles.

## Target Repository Layout (Top Level)
- `infrastructure/`
  - `README.md`
  - `mariadb/` (service definition, hardening, backup & restore playbook)
  - `mqtt/` (Mosquitto deployment, auth policy, monitoring)
  - `zigbee2mqtt/` (coordinator stack, backup/export tooling)
  - `node-red/` (active/passive pattern, leadership gate helpers)
  - `monitoring/` (health checks, heartbeat publishing, alerting hooks)
  - `vpn/` (remote access requirements, client config templates)
  - `poe-control/` (switch automation scripts, API clients, runbooks)
- `application/`
  - `README.md`
  - `home-assistant/`
    - `haos/` (primary instance guidance, snapshot workflows, import/export helpers)
    - `docker-standby/` (installer + tooling for the standby instance)
    - `leadership/` (MQTT contract, promotion scripts, tests)
  - `control-plane/` (NAS orchestration logic, leadership arbitration)
- `docs/`
  - `OPERATIONS/` (runbooks: failover, return-to-primary, backup validation)
  - `RESTRUCTURE_PLAN.md` (this file ? living tracker)
  - Existing reference docs updated to align with the new split
- `_legacy/` (temporary parking for old paths until migration completes)

## Configuration Contract
- Central secrets file managed per environment (NAS) exposing:
  - Database DSN, MQTT endpoint, leadership topics/retained payloads
  - PoE switch credentials and port map
  - VPN endpoints for off-site control
- Application profiles consume read-only configuration, writing only when designated leader.
- Synchronization of Home Assistant configuration via Git mirror with intentional delay (24?48h) and freeze flag.

## Work Phases
1. **Documentation & Structure** (in progress)
   - Publish target layout & contracts
   - Update existing docs (README, PROJECT_CONTEXT, HANDOFF) to reference the new architecture
   - Create placeholder READMEs for new directories
2. **Infrastructure Consolidation**
   - Move MariaDB & Mosquitto under `infrastructure/`
   - Extract NAS health checks, monitoring, VPN, PoE control scaffolding
   - Document backup & restore procedures + validation drills
3. **Application Realignment**
   - Split Home Assistant assets into HAOS guidance vs Docker standby
   - Define MQTT leadership protocol & implement control-plane scripts
   - Introduce Node-RED leadership gates mirroring the HA pattern
4. **Failover Tooling & Testing**
   - Implement NAS watchdog (HTTP + MQTT heartbeat)
   - Automate promotion/demotion workflows with manual override
   - Document and exercise runbooks (failover, rollback, Zigbee coordinator swap)
5. **Decommission Legacy Layout**
   - Remove `_legacy/` once every script & doc references the new structure
   - Refresh `.env` templates to match central contract

## Progress Tracker
| Phase | Item | Owner | Status | Notes |
|-------|------|-------|--------|-------|
| 1 | Define target layout & plan | Codex | In progress | This document captures the structure |
| 1 | Update PROJECT_CONTEXT.md | Codex | Pending | Must replace old per-Pi description |
| 1 | Update root README.md | Codex | Pending | Needs new navigation and scope |
| 1 | Refresh HANDOFF/HISTORY | Codex | Pending | Align with restructure plan |
| 2 | Migrate MariaDB docs | TBA | Blocked | Wait for phase 1 completion |
| 2 | Migrate Zigbee2MQTT assets | TBA | Blocked | Keep production host notes |
| 3 | Draft HA leadership contract | TBA | Blocked | Requires MQTT topics decision |
| 3 | Define config sync policy | TBA | Blocked | Document Git + freeze flag |
| 4 | PoE control automation | TBA | Blocked | Needs switch API research |
| 4 | Failover drill playbook | TBA | Blocked | Depends on leadership tooling |
| 5 | Remove legacy layout | TBA | Blocked | Final clean-up step |

## Immediate Next Actions
1. Rewrite `docs/PROJECT_CONTEXT.md` to reflect the new architecture and link to this plan.
2. Update root `README.md` with the infrastructure/application split and navigation.
3. Document initial leadership & synchronization concepts in `application/home-assistant/README.md` scaffolding.
4. Sync `docs/llm/HANDOFF.md` so future sessions continue from this plan.
