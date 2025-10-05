# Infrastructure Layer

This folder will gather every shared service that keeps the home automation stack alive even when the primary application node is down. Each subdirectory contains deployment scripts, configuration contracts, hardening guidance, and runbooks managed from the NAS.

## Scope
- **MariaDB (`mariadb/`)**: historical recorder backend, backup/restore policy, retention tests.
- **MQTT (`mqtt/`)**: Mosquitto deployment, authentication, leadership heartbeat topics, monitoring hooks.
- **Zigbee2MQTT (`zigbee2mqtt/`)**: coordinator stack, NVRAM backup tooling, standby strategy.
- **Node-RED (`node-red/`)**: active/passive deployment scripts with leadership gating.
- **Monitoring (`monitoring/`)**: health checks, alert routing, heartbeat publishers.
- **VPN (`vpn/`)**: remote access footprint for NAS orchestration and administrators.
- **PoE Control (`poe-control/`)**: switch automation clients, port mapping, power-cycle runbooks.

> The existing component directories at the repository root remain the source of truth until migration tasks land in each subfolder. This README and the restructure plan track progress and will replace the old layout when the move is complete.
