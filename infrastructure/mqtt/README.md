# Mosquitto MQTT Broker (Infrastructure Layer)

This directory will aggregate the assets for the NAS-hosted Mosquitto broker that supports Home Assistant leadership arbitration, Zigbee2MQTT traffic, and other automation services. The production broker currently ships inside the legacy `zigbee2mqtt/` component; migration will split it out so MQTT becomes a shared service with its own backups and monitoring.

## Current State
- Mosquitto is deployed alongside Zigbee2MQTT using `zigbee2mqtt/docker-compose.yml` with NAS-backed config/data directories.
- Authentication, ACLs, and listener configuration are defined through the legacy installer.
- Leadership contract topics (`piha/leader/...`) are defined in `application/home-assistant/leadership/README.md` but not yet enforced in the Mosquitto configuration.

## Migration Plan
1. **Extract Compose & Config**
   - Copy the Mosquitto service definition and configuration templates from `zigbee2mqtt/` into this folder.
   - Introduce a standalone installer/bootstrap script for Mosquitto if required.
2. **Harden Configuration**
   - Ensure TLS/username-password policies align with the central secrets contract.
   - Add ACL entries for leadership topics, restricting write access to HAOS, standby, and NAS control plane.
3. **Monitoring & Backups**
   - Configure log rotation and metrics (e.g., Telegraf/Prometheus exporters).
   - Document backup strategy for configuration and retained messages (if needed).
4. **Update Dependents**
   - Point Zigbee2MQTT and the Home Assistant scripts to the new MQTT service path.
   - Remove the Mosquitto service from `zigbee2mqtt/docker-compose.yml` once a shared broker is in place.

## Immediate Tasks (Phase 2)
- Define MQTT credential storage within the shared secrets file (`PIHA_MQTT_USER`, `PIHA_MQTT_PASS`).
- Draft ACL rules for `piha/leader/#`, Zigbee2MQTT topics, and any future services.
- Specify how the NAS control plane will publish commands (`piha/leader/home-assistant/cmd`).

Until the migration completes, continue managing Mosquitto through the legacy Zigbee2MQTT stack. Track progress in `docs/RESTRUCTURE_PLAN.md`.
