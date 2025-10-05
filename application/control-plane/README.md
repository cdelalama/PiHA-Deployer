# NAS Control Plane

This folder documents the services and scripts that run on the NAS (or management host) to supervise the automation estate, arbitrate leadership, and trigger remote recovery actions. The focus is to keep Home Assistant running (HAOS + Docker standby) with minimal manual intervention.

## Responsibilities
1. **Health Monitoring**
   - Poll HAOS supervisor (`http://<haos-ip>:4357/supervisor/ping`) and Docker standby API (`/api/` ping) on a fixed cadence.
   - Subscribe to leadership heartbeats (`piha/leader/home-assistant/heartbeat`) and raise alerts when the timeout is exceeded.
   - Watch container statuses for shared infrastructure components (MariaDB, Mosquitto) via Docker on the NAS.

2. **Leadership Arbitration**
   - Publish retained state messages (`piha/leader/home-assistant/state`) and keep track of which host currently acts as leader.
   - Issue commands on `piha/leader/home-assistant/cmd` (`promote`, `demote`, `freeze`, `thaw`) when failover or maintenance is required.
   - Maintain an audit log (`piha/leader/home-assistant/events`, plus local syslog) of promotions/demotions.

3. **Recovery Actions**
   - Perform PoE power-cycles on Raspberry Pi ports when a host becomes unresponsive. Requires switch API credentials and port map.
   - Trigger scripted reinstalls (curl + installer) if a host needs rebuilding from scratch.
   - Pull configuration snapshots (HAOS backups, Git repos) and stage them for restore.

4. **Configuration Sync Management**
   - Mirror the HAOS configuration Git repo to the standby branch after the observation window (24?48 h) unless the freeze flag is set.
   - Provide CLI or UI to toggle `standby_sync_freeze` and force syncs during planned maintenance.

5. **Alerting & Reporting**
   - Send notifications (email, messaging webhook) when leadership changes, heartbeats fail, or PoE resets are triggered.
   - Provide a dashboard view (Grafana/Influx or simple HTML) summarising host status, last heartbeat, and queued actions.

## Components (Planned)
- `monitor/` ? scripts/services for periodic health checks and heartbeat validation.
- `leadership-agent/` ? MQTT client that enforces the contract (state/cmd/events) and writes to audit logs.
- `poe/` ? adapters for the PoE switch API, with safety guards and rate limiting.
- `sync/` ? Git automation (delayed replication, freeze flag, manual override commands).
- `cli/` ? optional command-line utility to trigger failover drills (`promote`, `demote`, `reset-haos`, etc.).

## Operational Flow (Draft)
1. **Normal operation**
   - HAOS publishes `state=leader` + heartbeat every 30 s.
   - Control plane records the timestamp and keeps standby in `observing` state.
   - Git mirror job runs daily, checking incident logs before syncing to standby branch.

2. **Heartbeat failure**
   - Monitor detects missed heartbeat (>90 s) and verifies via HTTP ping.
   - Control plane issues PoE reset to HAOS port and waits for recovery (additional 60 s).
   - If still down, publish `cmd=promote`; standby promotes itself, publishes `state=leader`, and begins serving automations.

3. **Return to HAOS**
   - Administrator clears incidents, restores HAOS snapshot, and requests `cmd=demote` to the standby.
   - Control plane sets `state=maintenance` while HAOS boots, then `cmd=promote` back to HAOS when ready.
   - Standby returns to observer mode; Git mirror resumes after the observation window.

4. **Freeze Periods**
   - During risky weeks, set `standby_sync_freeze=true` via control plane (e.g., MQTT retained flag or stored in Git metadata).
   - Control plane blocks promotions unless explicitly commanded (`cmd=promote` overrides freeze for emergency failover).

## Interfaces & Data Stores
- **MQTT Broker**: `infrastructure/mqtt/` service; primary channel for leadership signaling and alerts.
- **Git Repository**: host configuration repo (per host or monorepo) stored on NAS (`/mnt/piha/git/home-assistant.git`).
- **Logs**: system journal, optional structured logs (JSON) under `/var/log/piha-control/` for audit and troubleshooting.
- **PoE Switch API**: REST/SNMP driver (model-specific) with credentials stored in NAS secrets file.

## Next Steps
1. Decide implementation stack (Bash scripts with cron, Python service, or Node-RED flows hosted on NAS).
2. Scaffold monitoring scripts that check HAOS/standby endpoints and publish heartbeats into a status topic.
3. Implement a simple command dispatcher listening to `piha/leader/home-assistant/cmd` to trigger PoE/reset actions.
4. Document failover drill script (simulate HAOS outage, promote standby, restore HAOS) for `docs/OPERATIONS/`.
5. Integrate with alerting (e.g., send webhook when leadership changes or PoE reset occurs).

Keep this README updated as components land. Once the control plane is functional, we can validate the dual-Home-Assistant deployment on two Raspberry Pis before moving on to Zigbee2MQTT and otros servicios.
