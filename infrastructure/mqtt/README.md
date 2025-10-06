# Mosquitto Broker (Infrastructure Layer)

Managed deployment of the shared Mosquitto MQTT broker running on the NAS. This replaces the broker that currently rides inside the Zigbee2MQTT stack and becomes the coordination hub for leadership heartbeats, Zigbee traffic, and other automations.

> The Zigbee2MQTT Pi still ships with its own Mosquitto container. Keep it running until this shared broker is deployed and validated; afterward, the Zigbee stack will be repointed and the embedded broker removed.

## Files
- `setup-mosquitto.sh` - bootstrap helper (runs locally on the NAS or over SSH)
- `docker-compose.yml` - Mosquitto service definition (Docker on NAS)
- `.env.example` - template with required variables (copy to `.env` and fill in secrets)

## Environment Variables (`.env`)
| Variable | Description |
|----------|-------------|
| `NAS_SSH_HOST` | NAS host/IP for SSH (`localhost` when running script directly on NAS) |
| `NAS_SSH_USER` | NAS user with permission to run Docker |
| `NAS_SSH_PORT` | SSH port (default `22`) |
| `NAS_SSH_USE_SUDO` | `true` if Docker commands on NAS require sudo |
| `NAS_DEPLOY_DIR` | Directory on NAS for compose files (default `/share/Container/compose/mqtt`) |
| `MQTT_CONFIG_DIR` | NAS path for Mosquitto configuration (`/mosquitto/config` inside container) |
| `MQTT_DATA_DIR` | NAS path for persistence files (`/mosquitto/data` inside container) |
| `MQTT_LOG_DIR` | NAS path for logs (`/mosquitto/log` inside container) |
| `MQTT_USER` | Primary automation user (optional but recommended) |
| `MQTT_PASSWORD` | Password for `MQTT_USER` |
| `MQTT_ALLOW_ANONYMOUS` | `false` to enforce auth (default), `true` to keep anonymous access |
| `MQTT_PERSISTENCE` | `true`/`false` (defaults to `true`) |
| `PUBLISHED_PORT` | TCP port exposed (default `1883`) |
| `MQTT_CONTAINER_NAME` | Container name (default `mosquitto`) |
| `TZ` | Timezone inside the container |

## Deployment
### Option A ? Run on the NAS (recommended)
```bash
ssh <nas-user>@<NAS_IP>
mkdir -p /share/Container/compose/mqtt
cd /share/Container/compose/mqtt
curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/infrastructure/mqtt/setup-mosquitto.sh -o setup-mosquitto.sh
chmod +x setup-mosquitto.sh
./setup-mosquitto.sh
```
The helper fetches `docker-compose.yml` automatically when it is not present in the target directory.

### Option B ? Run remotely from your PiHA-Deployer clone
```bash
cp infrastructure/mqtt/.env.example infrastructure/mqtt/.env  # fill in secrets
bash infrastructure/mqtt/setup-mosquitto.sh
```
The helper reads `.env`, copies `docker-compose.yml` to the NAS if missing, writes `mosquitto.conf`, creates password/ACL files when credentials are provided, and launches the service with Docker Compose.

### Post-deployment checks
```bash
cd ${NAS_DEPLOY_DIR:-/share/Container/compose/mqtt}
docker compose ps
chmod 600 ${MQTT_CONFIG_DIR:-/share/Container/compose/mqtt/config}/passwd
```
- Run the commands above on the NAS after the script finishes to verify the `mosquitto` container is `running`.
- Expect the container health status to report `healthy`; if it shows `unhealthy`, verify the generated `.env` contains `MOSQUITTO_HEALTH_AUTH_ARGS` (set automatically when `MQTT_USER`/`MQTT_PASSWORD` are provided) and rerun the chmod/health check.
- Fix the warning from `mosquitto_passwd` by setting `chmod 600` (or `700`) on the generated `passwd` file before restarting the service (`docker compose restart`).

## Configuration Notes
- **Leadership topics**: the generated `mosquitto.conf` references an ACL file (`/mosquitto/config/acl`). By default the script grants the primary `MQTT_USER` full access and allows read access to `piha/leader/#` for all authenticated users. Edit `${MQTT_CONFIG_DIR}/acl` to add granular rules (e.g., read-only observers for the standby instance and control plane).
- **Authentication**: when `MQTT_USER`/`MQTT_PASSWORD` are set, anonymous access is disabled and `passwd` is generated via `mosquitto_passwd`. Leave them empty only for temporary lab setups.
- **TLS**: not enabled by default. Extend `mosquitto.conf` and mount certificates under `${MQTT_CONFIG_DIR}` if encrypted transport is required.

## Backup & Restore
- **Config**: snapshot `${MQTT_CONFIG_DIR}` (contains `mosquitto.conf`, `passwd`, `acl`).
- **Persistence**: snapshot `${MQTT_DATA_DIR}` if you rely on retained messages or persistence.
- **Retention**: keep at least seven daily copies of the config directory; persistence backups depend on operational needs.
- **Restore drill**: quarterly, restore the config onto a disposable Mosquitto container and verify clients can authenticate and publish to leadership topics.

## Integration Plan
1. Deploy this broker on the NAS and configure Home Assistant (HAOS + standby) to point at it.
2. Update Zigbee2MQTT installer/compose to use the shared broker instead of its bundled container.
3. Remove the Mosquitto service from `zigbee2mqtt/docker-compose.yml` once testing completes.
4. Update runbooks (`docs/OPERATIONS/`) with failover procedures and ACL management.

Track progress and ownership in `docs/RESTRUCTURE_PLAN.md`.





