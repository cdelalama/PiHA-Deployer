# Home Assistant Docker Standby

This module documents the Home Assistant container stack that runs on a Raspberry Pi as a warm standby. It reuses the existing installer scripts (`home-assistant/install-home-assistant.sh`, `uninstall-home-assistant.sh`) until they migrate into this directory.

## Role and Behaviour
- Mirrors the configuration of the HAOS primary but remains in observer mode.
- Subscribes to the leadership MQTT topics published by HAOS and the NAS control plane.
- Stops running automations and avoids recorder writes unless promoted.
- Provides a fast takeover path when HAOS fails or is intentionally taken offline.

## Prerequisites
- Raspberry Pi with Docker/Compose capable OS (Raspberry Pi OS recommended).
- NAS share mounted following the group-by-host convention (`/mnt/piha/hosts/<HOST_ID>/...`).
- Access to shared infrastructure services:
  - MariaDB recorder (same DSN as HAOS primary).
  - Mosquitto broker (same credentials/topics).
- `.env` file configured as today (see legacy `home-assistant/.env.example`) plus new leadership-related variables (to be added when scripts move here).
- Git-based configuration sync from HAOS with 24?48 h delay.

## Installation (Current State)
1. Clone or download the repository on the standby Pi.
2. Prepare working directory (as documented in `home-assistant/README.md`).
3. Run the legacy installer:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/install-home-assistant.sh | sudo bash
   ```
4. Keep this instance stopped (or running in observer-only mode) until the leadership contract is enforced.

During Phase 3 the installer will move into this folder and gain awareness of leadership variables. Until then, use the legacy path for actual deployments.

## Observer Mode Checklist
- Disable all automations by default:
  - Use `automation.turn_off` after startup.
  - Optionally set `homeassistant.disable_autostart: true` for specific automation packages.
- Recorder configuration:
  - Point to MariaDB (same `recorder_db_url` as HAOS).
  - Set `commit_interval` high (e.g., 300 s) and rely on NAS control-plane to block writes when standby.
  - Alternatively, keep recorder disabled (`recorder:` omitted) until promotion.
- Integrations that should remain passive (examples):
  - Zigbee2MQTT integration set to `listen_only` (when possible) or disabled.
  - Node-RED websockets and MQTT flows should ignore standby topics.

## Leadership Contract (Draft)
- Subscribe to `piha/leadership/home-assistant/state` and `piha/leadership/home-assistant/heartbeat` (see HAOS README).
- Observer logic:
  - If `state=leader` and heartbeat fresh ? stay passive.
  - If state absent for >60 s ? prepare for promotion.
  - Promotion requires NAS control-plane command; do not self-promote automatically yet.
- On promotion:
  - Publish retained `state=leader` and start heartbeat every 30 s.
  - Re-enable automations and recorder writes.
  - Notify NAS control-plane through designated MQTT command topic (TBD).

## Configuration Synchronization
- NAS maintains a Git repository (`git@nas:piha/home-assistant.git`).
- Branching model:
  - `main` ? authoritative HAOS configuration.
  - `standby` ? mirrors `main` with delay.
- Sync cadence:
  - NAS job checks `main` daily; merges into `standby` if the freeze flag is unset and no incidents were recorded in the last 24?48 h.
- Standby Pi pulls `standby` branch before restarting containers or after promotion.

## Promotion Runbook (Draft)
1. NAS control-plane detects HAOS heartbeat loss.
2. NAS triggers PoE reset to HAOS port; if still down ? continue.
3. NAS publishes command to standby: `piha/leadership/commands` payload `promote`.
4. Standby applies latest `standby` branch, restarts container stack, enables automations.
5. Standby publishes retained `state=leader` and heartbeat.
6. Monitoring confirms automations/task queue running; manual verification optional.

## Demotion / Return to Normal
1. HAOS restored from snapshot and healthy.
2. NAS freezes standby sync (`standby_sync_freeze=true`).
3. NAS commands standby to demote (`piha/leadership/commands` payload `demote`).
4. Standby publishes `state=standby`, stops heartbeat, disables automations.
5. NAS clears freeze flag after HAOS stable for 24?48 h and resumes delayed sync.

Detailed automation scripts and control-plane implementation will be added as part of future phases. Keep this README aligned with the evolving MQTT contract and helper tooling.
