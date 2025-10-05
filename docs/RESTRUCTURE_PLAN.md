# PiHA Replatforming Plan

## Objective
Reorganize PiHA-Deployer to implement the NAS-orchestrated architecture: shared infrastructure services separated from application roles, with controlled leadership and remote recovery.

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
    - `haos/` (primary appliance guidance, snapshot workflows, import/export helpers)
    - `docker-standby/` (standby installer/tooling, observer safeguards)
    - `leadership/` (MQTT contract, promotion scripts, tests)
  - `control-plane/` (NAS orchestration logic, decision engine, PoE actions)
- `docs/`
  - `OPERATIONS/` (runbooks: failover, return-to-primary, backup validation)
  - `RESTRUCTURE_PLAN.md` (this document)
  - Existing reference docs updated to align with the new split
- `_legacy/` (temporary parking for old paths until migration completes)

## Configuration Contract
- Central secrets file managed on the NAS containing:
  - Recorder DSN (MariaDB), MQTT endpoint, leadership topics/retained payload schema
  - PoE switch credentials and port mapping
  - VPN endpoints/credentials for remote administration
- Application profiles consume configuration read-only and write only when acting as leader.
- Configuration sync relies on a Git mirror with deliberate delay (24?48 hours) and a freeze flag to pause replication during risky windows.

## Work Phases
1. **Documentation & Structure**
   - Publish target layout & contracts
   - Update core documentation (README, PROJECT_CONTEXT, HANDOFF)
   - Create initial READMEs for new directories and application roles
2. **Infrastructure Consolidation**
   - Migrate MariaDB & Mosquitto assets under `infrastructure/`
   - Extract NAS health checks, monitoring, VPN, PoE control scaffolding
   - Document backup & restore procedures plus validation drills
3. **Application Realignment**
   - Move Home Assistant scripts into `application/home-assistant/docker-standby/`
   - Flesh out MQTT leadership protocol & control-plane automation
   - Add Node-RED leadership gates mirroring the Home Assistant pattern
4. **Failover Tooling & Testing**
   - Implement NAS watchdog (HTTP + MQTT heartbeat)
   - Automate promotion/demotion workflows with manual override
   - Document and exercise runbooks (failover, rollback, Zigbee coordinator swap)
5. **Decommission Legacy Layout**
   - Retire `_legacy/` and old directories once migration concludes
   - Refresh `.env` templates to match the central configuration contract

## Progress Tracker
| Phase | Item | Owner | Status | Notes |
|-------|------|-------|--------|-------|
| 1 | Define target layout & plan | Codex | Completed | Plan published in this document |
| 1 | Update PROJECT_CONTEXT.md | Codex | Completed | Matches new architecture |
| 1 | Update root README.md | Codex | Completed | Navigation reflects new layers |
| 1 | Refresh HANDOFF/HISTORY | Codex | Completed | Handoff describes restructure status |
| 1 | Document HAOS primary guidance | Codex | Completed | See `application/home-assistant/haos/README.md` |
| 1 | Document Docker standby role | Codex | Completed | See `application/home-assistant/docker-standby/README.md` |
| 3 | Draft MQTT leadership contract | Codex | Completed | Contract defined in `application/home-assistant/leadership/README.md` |
| 3 | Define config sync policy | Codex | In progress | High-level policy documented; implementation pending |
| 2 | Migrate MariaDB docs | Codex | In progress | README scaffolded in infrastructure/mariadb/; scripts pending move |
| 2 | Migrate Mosquitto docs | Codex | In progress | MQTT service plan documented; extraction pending |
| 2 | Migrate Zigbee2MQTT assets | TBA | Blocked | Production host remains active |
| 3 | Build control-plane scaffolding | TBA | Blocked | Depends on leadership tooling implementation |
| 4 | PoE control automation | TBA | Blocked | Requires switch API research |
| 4 | Failover drill runbook | TBA | Blocked | Needs tooling in place |
| 5 | Remove legacy layout | TBA | Blocked | Final clean-up step |

## Immediate Next Actions
1. Move MariaDB scripts (`setup-nas-mariadb.sh`, compose) into `infrastructure/mariadb/` and add backup/restore playbook.
2. Extract Mosquitto service from Zigbee2MQTT into `infrastructure/mqtt/` with ACL updates matching the leadership contract.
3. Outline NAS control-plane responsibilities and PoE workflow in `application/control-plane/README.md`.
4. Design the delayed Git replication automation (repo structure, freeze flag implementation).


