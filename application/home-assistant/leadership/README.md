# Home Assistant Leadership Contract

This document defines the MQTT-based coordination used to decide which Home Assistant instance (HAOS or Docker standby) is acting as leader. The contract is designed so the NAS can arbitrate promotion/demotion without depending on Home Assistant itself.

## Objectives
- Single source of truth in MQTT about who is leader (`state`) and whether it is alive (`heartbeat`).
- Allow the NAS control plane to command promotions/demotions and trigger PoE resets when needed.
- Keep observers (standby HA, Node-RED flows, monitoring dashboards) informed with retained messages.
- Minimise false failovers by combining retained state and heartbeat timeouts.

## Topic Map
All topics are retained unless stated otherwise. Prefix `piha/leader/` is reserved for leadership semantics.

| Topic | Retained | Description |
|-------|----------|-------------|
| `piha/leader/home-assistant/state` | ? | Retained string: `leader`, `standby`, or `maintenance`. Published by the active instance (or NAS during transitions). Absence indicates no leader. |
| `piha/leader/home-assistant/heartbeat` | ? | Retained JSON payload with `ts` (ISO8601) and `host_id`. Updated every 30 s by the leader. |
| `piha/leader/home-assistant/cmd` | ? | Non-retained commands from NAS to standby: `promote`, `demote`, `freeze`, `thaw`. Consumed by standby/control agents. |
| `piha/leader/home-assistant/events` | ? | Append-only history (retain optional) summarising leadership changes (`{"ts":...,"event":"promoted","actor":"nas"}`). Useful for auditing. |
| `piha/leader/alerts` | ? | Shared channel for alerting (e.g., NAS publishes `haos_heartbeat_missed`). |

Future services (Node-RED, etc.) reuse the same prefix with their own service name.

## Payload Definitions

### `state`
- `leader`: instance currently processing automations and recorder writes.
- `standby`: instance running but observing only.
- `maintenance`: leader intentionally offline (freeze promotion); NAS keeps control until cleared.

Publisher responsibilities:
- Leader publishes `leader` retained at boot and on demotion publishes `standby` before stopping heartbeat.
- NAS may temporarily publish `maintenance` during upgrades to prevent auto-promotion.

### `heartbeat`
JSON object:
```json
{
  "ts": "2025-10-05T20:15:00Z",
  "host_id": "haos-pi-01",
  "uptime_s": 12345,
  "version": "2025.9.2"
}
```
- `ts`: ISO8601 in UTC.
- `host_id`: identifier of the publisher.
- `uptime_s` (optional): seconds since boot.
- `version` (optional): HA version string.

Cadence: every 30 seconds (configurable). Message is retained so a late subscriber sees the last heartbeat immediately.

### `cmd`
Plain-text commands, non-retained. Consumers must acknowledge by publishing to `piha/leader/home-assistant/events`.
- `promote`: standby should promote itself to leader (after validation) and start heartbeats.
- `demote`: current leader should transition to standby (NAS stops heartbeats if HA unresponsive).
- `freeze`: standby suspends config sync and promotion logic (used during risky windows).
- `thaw`: resume normal observation.

### `events`
JSON object appended when a leadership action occurs:
```json
{
  "ts": "2025-10-05T20:17:12Z",
  "event": "promoted",
  "actor": "nas",
  "new_leader": "docker-standby",
  "reason": "heartbeat_timeout"
}
```
This enables monitoring/alerting dashboards to reconstruct history.

## Timeouts & Promotion Rules
- Heartbeat interval: 30 s (configurable).
- Primary timeout: 90 s without new heartbeat ? NAS marks leader as missing.
- Grace period: NAS attempts PoE reset once; if heartbeat still absent after an additional 60 s, NAS issues `promote` command to standby.
- Standby must verify `state` topic is empty or `standby` before accepting promotion; if `state=maintenance`, standby waits for explicit `promote`.
- When promoted, standby publishes `state=leader` retained and begins heartbeats immediately.
- When HAOS returns, it waits for NAS `thaw` + `promote` before resuming leadership.

## Role Responsibilities

### HAOS (Primary)
- Publish `state=leader` retained when active; `standby` before controlled shutdowns.
- Update heartbeat every 30 s via automation/script.
- Honour `cmd=demote` (disable automations, stop heartbeats, publish `standby`).

### Docker Standby
- Subscribe to `state`, `heartbeat`, and `cmd` topics.
- Stay in observer mode while `state=leader` and heartbeat fresh.
- On `cmd=promote`, apply latest configuration, enable automations, publish `state=leader`, begin heartbeats.
- On `cmd=freeze`, block promotions and config sync until `cmd=thaw`.

### NAS Control Plane
- Monitor heartbeats (HTTP + MQTT) and manage PoE resets.
- Publish commands on `cmd` topic.
- Write events to `events` log.
- During maintenance windows, publish `state=maintenance` to prevent automatic promotion.

### Observers (Node-RED, monitoring dashboards)
- Use `state` to gate flows (run only when `leader`).
- Use `events` to raise alerts / timeline.

## Implementation Guidance
- All publishers must set `retain=true` for `state` and `heartbeat`.
- Timestamp comparisons should use UTC to avoid DST issues.
- Standby should implement exponential back-off before retrying promotion if NAS cannot be reached.
- Control plane should persist last known `state`/`heartbeat` for auditing (e.g., InfluxDB, Prometheus).

## Testing Checklist (to be automated)
1. Leader publishes heartbeat; standby stays passive.
2. Stop leader heartbeat ? NAS resets PoE ? promotion occurs.
3. Manual `cmd=promote` triggers takeover even if heartbeat exists (used for drills).
4. `cmd=freeze` prevents promotion despite heartbeat loss.
5. `cmd=demote` gracefully hands control back to HAOS.

## Open Items
- Decide on final JSON schema for `events` (whether to include `old_leader`, `duration_s`).
- Implement acknowledgement for `cmd` messages (e.g., `events` entry or dedicated `ack` topic).
- Align Node-RED leadership gating with the same contract once documented.

Keep this document updated as tooling is implemented. Scripts leveraging this contract will live alongside this README.
