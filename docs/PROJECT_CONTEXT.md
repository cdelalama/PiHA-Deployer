# PiHA-Deployer Project Context

## Vision
Deliver a home automation platform that can operate unattended for months, with the NAS orchestrating recovery, PoE-managed resets, and planned failover between a primary HAOS appliance and a Docker-based standby. The repository is being restructured to encode this design explicitly.

## Architectural Layers
1. **Infrastructure (NAS-centric)**
   - MariaDB recorder backend with backups and periodic restore drills.
   - Mosquitto broker hosting leadership markers and automation traffic.
   - Zigbee2MQTT coordinator plus cold-standby strategy and NVRAM exports.
   - Node-RED flow engine deployed in active/passive mode with leadership gates.
   - Supporting services: monitoring/alerting, VPN access, PoE switch automation.
2. **Application (Consumers)**
   - Home Assistant OS as the primary appliance (snapshots, Safe Mode, guided restore).
   - Home Assistant in Docker as a standby observer that promotes itself when the NAS withdraws the primary heartbeat.
   - Control-plane scripts that enforce leadership rules and manage promotion/demotion.
3. **Operations & Runbooks**
   - Git-based configuration replication with deliberate delay and freeze flag.
   - Scheduled failover/return drills, backup validation exercises, and Zigbee coordinator swap procedures.

## Repository Layout (Target)
```
PiHA-Deployer/
??? infrastructure/                # Shared services (Nas-managed)
?   ??? mariadb/
?   ??? mqtt/
?   ??? zigbee2mqtt/
?   ??? node-red/
?   ??? monitoring/
?   ??? vpn/
?   ??? poe-control/
??? application/
?   ??? home-assistant/
?   ?   ??? haos/
?   ?   ??? docker-standby/
?   ?   ??? leadership/
?   ??? control-plane/
??? docs/
?   ??? PROJECT_CONTEXT.md          # This document
?   ??? RESTRUCTURE_PLAN.md         # Live tracker for the migration
?   ??? VERSIONING_RULES.md
?   ??? OPERATIONS/                 # (Planned) Runbooks and drills
?   ??? llm/
?       ??? HANDOFF.md
?       ??? HISTORY.md
??? home-assistant/ (legacy until Phase 3)
??? node-red/        (legacy until Phase 2)
??? zigbee2mqtt/     (legacy until Phase 2)
??? ...
```

> The legacy top-level component folders remain operational until their content migrates into the new structure. Track progress in `docs/RESTRUCTURE_PLAN.md`.

## Current Status (2025-10-05)
- Restructure plan published; infrastructure/application directories scaffolded.
- Installer/uninstaller scripts for Home Assistant continue to live in `home-assistant/` and will move into `application/home-assistant/docker-standby/` during Phase 3.
- Node-RED and Zigbee2MQTT deployments remain in production under the legacy layout.
- Documentation updates in progress to reflect the leadership contract, delayed sync policy, and PoE-managed recovery.

## Next Milestones
1. Update root `README.md` to present the new layer split and navigation.
2. Document the MQTT leadership contract and synchronization policies.
3. Migrate MariaDB/MQTT scripts into `infrastructure/` with refreshed guidance.
4. Split Home Assistant documentation into HAOS vs standby roles.

Refer to `docs/RESTRUCTURE_PLAN.md` for detailed task tracking and ownership.
