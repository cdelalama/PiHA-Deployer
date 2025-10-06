# Home Assistant Deployment Scripts

Automated Docker deployment of Home Assistant and Portainer on a Raspberry Pi with all persistent data hosted on the NAS. The stack always uses MariaDB for the recorder database; SQLite is no longer supported.

## Requirements
- Raspberry Pi OS (fresh install) with SSH and sudo access
- NAS exposing an SMB/CIFS share for configuration data and running the shared MariaDB container
- Working `curl` on the Pi (for the one-line installer)

The installer ensures Docker, the Docker Compose plugin, and the required CIFS packages are present.

## Quick Start
1. **Prepare the working folder on the Pi**
   ```bash
   mkdir -p ~/piha-home-assistant
   cd ~/piha-home-assistant
   mkdir -p common
   ```

2. **Create configuration files** (keep permissions at 600):
   ```bash
   touch common/common.env .env
   chmod 600 common/common.env .env
   ```

3. **Populate `common/common.env` with shared defaults** (NAS credentials, mount path, UID/GID, etc.). Copy from `common/common.env.example` if needed.

4. **Populate `.env` with host-specific values**. Use `home-assistant/.env.example` as a template; key items:
   - Paths on the NAS (`BASE_DIR`, `DOCKER_COMPOSE_DIR`, `HA_DATA_DIR`, `PORTAINER_DATA_DIR`)
   - `DOCKER_USER_ID` / `DOCKER_GROUP_ID`
   - MariaDB connection (`MARIADB_HOST`, `MARIADB_PORT`, `MARIADB_DATABASE`, `MARIADB_USER`, `MARIADB_PASSWORD`, optional `MARIADB_CONTAINER_NAME`)
   - `PORTAINER_PASS`, `HA_PORT`, `PORTAINER_PORT`, `IP` (usually `auto`)

5. **Ensure MariaDB is running on the NAS** using `infrastructure/mariadb/setup-nas-mariadb.sh` (or follow `infrastructure/mariadb/README.md`). The installer aborts if the database is unreachable or credentials are wrong.

6. **Run the installer**:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/install-home-assistant.sh | sudo bash
   ```

**Verification**
```bash
sudo docker compose ps
sudo docker logs homeassistant --tail 50
sudo docker logs portainer --tail 20
mount | grep /mnt/piha
```
Home Assistant: `http://<pi-ip>:8123` ? Portainer: `http://<pi-ip>:9000`

If NAS directories already contain Home Assistant data, the installer prompts before reusing them (or honours `HA_ALLOW_EXISTING_DATA=true` in `.env`).

## Reset / Uninstall
Run from the working directory (default `~/piha-home-assistant`).

```
curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/uninstall-home-assistant.sh | sudo bash
```

- Interactive mode asks whether to keep the NAS configuration (`${HA_DATA_DIR}`) and, if so, whether to retain the MariaDB deployment on the NAS.
- Flags: `--force` (non-interactive), `--skip-nas-ssh` (keep MariaDB as-is), `--purge-local`, `--purge-images`, `--keep-env`.
- The script stops containers, removes NAS directories (unless preserved), optionally deletes the NAS MariaDB deployment via SSH, and returns the NAS host folder to an empty state.

## Environment Reference
Key variables expected in `.env` (values in `common/common.env` are loaded first and can be reused across hosts):

| Variable | Description |
| --- | --- |
| `HOST_ID` | Identifier used to group NAS paths (e.g. `ha-pi-01`) |
| `DOCKER_USER_ID` / `DOCKER_GROUP_ID` | UID/GID for file ownership on the NAS |
| `NAS_IP`, `NAS_SHARE_NAME`, `NAS_USERNAME`, `NAS_PASSWORD`, `NAS_MOUNT_DIR` | SMB/CIFS share details |
| `BASE_DIR`, `DOCKER_COMPOSE_DIR`, `HA_DATA_DIR`, `PORTAINER_DATA_DIR` | NAS directories for compose files, Home Assistant config, and Portainer data |
| `HA_PORT`, `PORTAINER_PORT`, `IP`, `TZ` | Listener ports, advertised IP (`auto` uses the first interface), timezone |
| `PORTAINER_PASS` | Portainer admin password (written to `portainer_password.txt`) |
| `MARIADB_HOST`, `MARIADB_PORT`, `MARIADB_DATABASE`, `MARIADB_USER`, `MARIADB_PASSWORD`, `MARIADB_CONTAINER_NAME` | Recorder database connection and optional container name |

## Compose Services
- `homeassistant`: `ghcr.io/home-assistant/home-assistant:stable`, host networking, configuration mounted from `${HA_DATA_DIR}`.
- `portainer`: `portainer/portainer-ce:latest`, local Docker socket mounted read/write, data stored in `${PORTAINER_DATA_DIR}`.

## Recorder (MariaDB only)
- Recorder always targets the NAS-hosted MariaDB instance.
- The installer validates reachability and credentials, manages the `recorder` block in `configuration.yaml`, and ensures `secrets.yaml` contains `recorder_db_url`.
- Requirements:
  - MariaDB accessible on the configured host/port
  - `PyMySQL` added to `requirements.txt` (handled automatically)
  - MariaDB data stored on a local NAS filesystem (not a remote SMB mount)

Manual configuration snippet (if you prefer to manage it yourself):
```yaml
# secrets.yaml
recorder_db_url: mysql+pymysql://homeassistant:changeMe@<nas-ip>:3306/homeassistant?charset=utf8mb4

# configuration.yaml
recorder:
  db_url: !secret recorder_db_url
  purge_keep_days: 14
  commit_interval: 30
```
Restart Home Assistant after manual changes: `docker compose -f "${BASE_DIR}/docker-compose.yml" restart homeassistant`.

## Troubleshooting
- Docker/Compose status: `docker ps`, `docker compose ps`
- NAS mount: `mountpoint -q "${NAS_MOUNT_DIR}"`
- MariaDB reachability: `nc -vz ${MARIADB_HOST} ${MARIADB_PORT}`
- Container logs: `docker logs homeassistant`, `docker logs portainer`

## Security Notes
- Keep `.env` and `common/common.env` at permission `600`; they contain NAS and database credentials.
- Escape `$` in passwords as `\$` in `.env`.
- Use strong credentials for Portainer and MariaDB.

## Automation Tips
- Generate `.env` programmatically and reuse `common/common.env` to standardise NAS credentials.
- The installer pauses for `NAS_COOLDOWN_SECONDS` (default 5s) after writing to the NAS; adjust if your NAS requires longer commit times.
- Uninstaller flags make it easy to script clean re-deployments (`--force --purge-local --purge-images`).

For MariaDB bootstrap instructions and maintenance (backups, health checks), see `infrastructure/mariadb/README.md`.
