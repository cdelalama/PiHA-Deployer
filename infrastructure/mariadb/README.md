# MariaDB Service (Infrastructure Layer)

Managed deployment of MariaDB on the NAS for Home Assistant Recorder. This replaces the legacy `home-assistant/mariadb/` directory and is now the single source of truth for scripts, compose files, and operations guidance.

## Files
- `setup-nas-mariadb.sh` - bootstrap helper (runs locally or over SSH)
- `docker-compose.yml` - MariaDB service definition (Docker on NAS)
- `.env.example` - template with required variables

## Environment Variables (`.env`)
| Variable | Description |
|----------|-------------|
| `NAS_SSH_HOST` | NAS host/IP for SSH (use `localhost` when running directly on NAS) |
| `NAS_SSH_USER` | User with permission to run Docker on the NAS |
| `NAS_SSH_PORT` | SSH port (default `22`) |
| `NAS_SSH_USE_SUDO` | `true` if `docker` requires sudo on NAS |
| `NAS_DEPLOY_DIR` | Directory on NAS for compose files (default `/share/Container/compose/mariadb`) |
| `MARIADB_DATA_DIR` | Data directory on NAS (default `${NAS_DEPLOY_DIR}/data`) |
| `MARIADB_ROOT_PASSWORD` | Root password for MariaDB |
| `MARIADB_DATABASE` | Database name for Home Assistant (`homeassistant`) |
| `MARIADB_USER` | Application user |
| `MARIADB_PASSWORD` | Application user password |
| `PUBLISHED_PORT` | TCP port exposed (default `3306`) |
| `TZ` | Timezone inside container |

## Deployment
### Option A ? Run on the NAS (recommended)
```bash
ssh <nas-user>@<NAS_IP>
mkdir -p /share/Container/compose/mariadb
cd /share/Container/compose/mariadb
curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/infrastructure/mariadb/setup-nas-mariadb.sh -o setup-nas-mariadb.sh
bash setup-nas-mariadb.sh
```

### Option B ? Run remotely from your PiHA-Deployer clone
```bash
# On your workstation or Pi where this repo lives
cp infrastructure/mariadb/.env.example infrastructure/mariadb/.env  # fill in secrets
bash infrastructure/mariadb/setup-nas-mariadb.sh
```
The helper reads `.env`, copies `docker-compose.yml` to the NAS (if missing), and launches the container via Docker Compose.

## Home Assistant Integration
Add the secrets and recorder block (applies to HAOS and Docker standby):
```yaml
# secrets.yaml
recorder_db_url: mysql+pymysql://homeassistant:<password>@<NAS_IP>:3306/homeassistant?charset=utf8mb4

# configuration.yaml
recorder:
  db_url: !secret recorder_db_url
  purge_keep_days: 14
  commit_interval: 30
```

## Backup & Restore
- **Backups**: schedule `mysqldump` from the NAS (e.g., cron) to `${NAS_BACKUP_DIR}/mariadb/YYYY-MM-DD.sql.gz`.
- **Retention**: keep last 30 daily dumps + 12 monthly; adjust to storage.
- **Restore drill**: monthly, restore a dump into a disposable MariaDB container and run `SELECT COUNT(*) FROM states;` to confirm integrity.
- **Automation**: document the cron job and test results under `docs/OPERATIONS/` when available.

## Control Plane Hooks
- Expose health endpoint: `mysqladmin ping -h <host>` for monitoring.
- NAS control plane should alert if container exits or replication fails.
- Leadership contract consumers (HAOS/standby) rely on this MariaDB DSN; ensure backups + retention protect long-term history.

## Migration Notes
- Legacy directory `home-assistant/mariadb/` now contains compatibility stubs that call these scripts.
- Update all documentation/instructions to use `infrastructure/mariadb`. See `docs/RESTRUCTURE_PLAN.md` for status.





