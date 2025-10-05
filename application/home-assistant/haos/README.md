# Home Assistant OS (Primary Appliance)

This guide describes how to operate the Home Assistant OS instance that acts as the primary automation brain. It assumes the shared infrastructure (MariaDB, Mosquitto, Zigbee2MQTT, Node-RED, monitoring, PoE control) is managed from the NAS according to `docs/RESTRUCTURE_PLAN.md`.

## Goal and Scope
- Run Home Assistant OS (HAOS) on a Raspberry Pi with PoE HAT.
- Connect HAOS to the NAS-hosted services without holding any single point of failure locally.
- Publish leadership heartbeats over MQTT so the standby Docker instance knows when to stay quiet.
- Produce regular snapshots and store them on the NAS for rapid recovery.

## Prerequisites
- Raspberry Pi 4/5 with PoE HAT connected to a managed PoE switch.
- microSD (32 GB+) or SSD prepared with the latest HAOS image.
- Network reachability to the NAS (VPN-friendly) and the shared infrastructure services:
  - MariaDB recorder (default: `mysql+pymysql://homeassistant:...@nas:3306/homeassistant`).
  - Mosquitto broker (default host: `nas` or `mqtt.local`).
  - Zigbee2MQTT stack (existing production Pi; keep unchanged for now).
  - Node-RED (existing production Pi; keep unchanged for now).
- SSH access to the NAS for remote automation and PoE switching.

## Installation Workflow
1. **Flash HAOS**
   - Download the latest Home Assistant OS image and flash it onto the SD/SSD (see official HAOS installer).
   - Insert the media into the Pi, connect the PoE-enabled Ethernet cable, and power up.

2. **Initial Onboarding**
   - Wait for HAOS to boot (typically `http://homeassistant.local:8123`).
   - Complete the onboarding wizard (owner account, location, etc.).
   - Enable SSH add-on (optional) for remote troubleshooting.

3. **Configure Recorder to use MariaDB**
   - Add the following snippet via the UI or by editing `configuration.yaml`:
     ```yaml
     recorder:
       db_url: !secret recorder_db_url
     ```
   - In `secrets.yaml` define `recorder_db_url` with the NAS DSN (example):
     ```yaml
     recorder_db_url: mysql+pymysql://homeassistant:changeMe@192.168.1.50:3306/homeassistant?charset=utf8mb4
     ```
   - Restart Home Assistant to validate the connection.

4. **Connect to Mosquitto**
   - Go to Settings ? Devices & Services ? Integrations ? Add Integration ? MQTT.
   - Provide the NAS broker host/IP and credentials managed in infrastructure.
   - Confirm the HAOS instance can subscribe/publish (see logs for retained messages).

5. **Install Critical Add-ons**
   - File Editor or SSH & Web Terminal (for quick config tweaks when remote).
   - Optional: Samba share for quick access, but prefer Git sync and snapshots as primary backup mechanisms.

6. **Configure Leadership Heartbeat**
   - Add an automation or template entity that publishes a retained payload to the leadership topic every 30 seconds (contract draft below).
   - Use the `mqtt.publish` service or an automation.
   - Configure a `binary_sensor` that mirrors the standby heartbeat to monitor split-brain (optional).

### MQTT Leadership Contract (Draft)
- Topic namespace: `piha/leadership/home-assistant`.
- Retained messages:
  - `piha/leadership/home-assistant/state` ? payload `leader` (primary) or `standby`.
  - `piha/leadership/home-assistant/heartbeat` ? payload `alive` (timestamp or ISO string) updated every 30 s.
- Standby instance only promotes if `state` is absent for >60 s **and** `heartbeat` has not been updated for >60 s.
- NAS control plane enforces this contract and performs the final switch (future work).

## Snapshot and Backup Policy
1. **Create Weekly Snapshots** (full backups): Settings ? System ? Backups ? Create Backup.
2. **Export to NAS**: Use the built-in backup uploader (Samba/Google Drive) or schedule `ha backups download` via automation to `${NAS_MOUNT_DIR}/snapshots/haos`.
3. **Retention**: Keep the last 6 weekly snapshots plus the last 7 daily incremental backups.
4. **Validation Drill**: Monthly, restore a snapshot on a lab HAOS VM to confirm viability.
5. **Documentation**: Log backup executions and restores in `docs/OPERATIONS/` runbooks.

## Configuration Synchronization
- All HAOS configuration changes are committed to a Git repo (per host or monorepo) stored on the NAS.
- Sync cadence:
  - Apply changes on HAOS primary.
  - Observe stability for 24?48 hours.
  - NAS sync job mirrors changes into the standby repo branch.
- Freeze flag: toggle `standby_sync_freeze=true` on the NAS when you want to block replication during risky weeks.

## Return-to-Service Runbook (Summary)
1. Restore the latest working snapshot (if required).
2. Rejoin MariaDB and MQTT (ensure credentials have not rotated).
3. Re-enable leadership heartbeat.
4. Inform the NAS control plane to hand control back to HAOS (clear `standby` state).
5. Run smoke tests (automations, dashboards, recorder timeline).

Full drill steps will be published in `docs/OPERATIONS/failover-return.md` during later phases.

## Monitoring Hooks
- Expose HAOS health via:
  - Supervisor API: `http://<haos-ip>:4357/supervisor/ping`.
  - MQTT: publish `alive` heartbeat.
  - HTTP sensor for NAS control plane.
- NAS monitoring service polls these endpoints and decides on promotion/demotion, triggering PoE resets if HAOS stops responding.

## TODOs / Open Questions
- Finalize MQTT topic naming with the NAS control-plane team.
- Automate the heartbeat publisher (script vs automation blueprint).
- Define exact Git workflow and branch naming for delayed sync.
- Link to Zigbee coordinator standby procedures once documented.

Keep this document up to date as scripts move from the legacy `home-assistant/` directory into `application/home-assistant/docker-standby/` and the NAS control plane takes shape.
