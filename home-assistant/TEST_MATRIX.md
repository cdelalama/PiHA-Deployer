# Home Assistant + MariaDB Test Matrix

Scenarios for validating `home-assistant/install-home-assistant.sh` (v1.4.0) and `infrastructure/mariadb/setup-nas-mariadb.sh` (v1.1.1). Pick the rows that match the change under test.

## 1. Home Assistant Installer

### 1A. Fresh install (MariaDB)
**Prep**
```bash
mkdir -p ~/piha-home-assistant/common
cd ~/piha-home-assistant
cp /path/to/common.env.template common/common.env   # or populate manually
cp /path/to/ha.env.template .env
chmod 600 common/common.env .env
```
- Ensure `.env` contains valid NAS paths and `MARIADB_*` credentials.
- `${HA_DATA_DIR}`, `${BASE_DIR}`, and `${PORTAINER_DATA_DIR}` should be absent on the NAS.
- MariaDB must be running on the NAS (`infrastructure/mariadb/setup-nas-mariadb.sh`).

**Run**
```bash
curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/install-home-assistant.sh | sudo bash
```

**Expect**
- Installer reports `Validating MariaDB availability...` followed by `[OK] MariaDB credentials verified`.
- After the stack launch, logs show `Recorder configured to use MariaDB` and the container restarts if requirements changed.

**Checks**
```bash
sudo docker compose ps
sudo docker logs homeassistant --tail 50 | grep -i recorder
mount | grep /mnt/piha
```

### 1B. Existing data (interactive)
- Leave NAS directories populated with prior deployment data.
- Run `sudo bash install-home-assistant.sh` from a downloaded copy.
- Expect prompt `Continue and reuse these directories? [y/N]`. Answer `y` to proceed, `n` (or Enter) to abort with guidance.

### 1C. Existing data (non-interactive)
- Same setup as 1B.
- Without `HA_ALLOW_EXISTING_DATA=true` the installer aborts with instructions.
- With `HA_ALLOW_EXISTING_DATA=true` the installer proceeds and logs that reuse was requested.

### 1D. Failure scenarios (negative tests)
- Remove/stop the NAS MariaDB container or use wrong credentials.
- Run the installer and confirm it exits with `[ERROR] MariaDB validation failed` and prints the bootstrap hint.
- Repeat with `NAS_IP` unreachable to confirm network failure messaging.

### 1E. Uninstaller (interactive)
- From the working directory run:
  ```bash
  curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/uninstall-home-assistant.sh -o uninstall-home-assistant.sh
  sudo bash uninstall-home-assistant.sh
  ```
- Answer prompts to (a) optionally purge the working directory/images, (b) keep or delete NAS configuration, (c) keep or remove the MariaDB deployment.
- Exercise both recorder branches (keep + keep DB, keep + remove DB).

### 1F. Uninstaller (automation)
- Run `curl -fsSL .../uninstall-home-assistant.sh | sudo bash -s -- --force [--skip-nas-ssh] [--purge-local] [--purge-images] [--keep-env]`.
- Confirm: no prompts, stack stopped, NAS directories cleaned, MariaDB deployment removed unless `--skip-nas-ssh`.

### 1G. End-to-end reset
1. Execute 1F with `--force --purge-local --purge-images` to ensure a clean slate.
2. Run 1A and verify containers/recorder.
3. Optional: rerun 1E choosing ?keep config + keep DB? to simulate preserving data.

**Post-checks**
- `docker ps` shows only ancillary containers (no `homeassistant`/`portainer`) after uninstall.
- `${NAS_MOUNT_DIR}/hosts/${HOST_ID}` removed when empty.
- After reinstall, Home Assistant reachable at `http://<pi>:8123`, Portainer at `http://<pi>:${PORTAINER_PORT}`.

## 2. NAS MariaDB Helper

### 2A. Local bootstrap on the NAS
```bash
ssh <nas-user>@<nas-ip>
mkdir -p /share/Container/compose/piha-homeassistant-mariadb
cd /share/Container/compose/piha-homeassistant-mariadb
curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/infrastructure/mariadb/.env.example -o .env
chmod 600 .env && vi .env
curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/infrastructure/mariadb/setup-nas-mariadb.sh | bash
```
Expect the script to print its version, download `docker-compose.yml` if missing, wait for the healthcheck, and show `docker compose ps` with `healthy` status.

### 2B. Remote bootstrap from a repo clone
```bash
cp infrastructure/mariadb/.env.example infrastructure/mariadb/.env
vi infrastructure/mariadb/.env
bash infrastructure/mariadb/setup-nas-mariadb.sh
```
Confirms SSH path works and that `.env.bootstrap` is preserved between runs.

### 2C. Idempotency
- Re-run 2A or 2B with existing data; ensure compose/env files refreshed and container restart succeeds without errors.

## 3. Verification Checklist
After each scenario:
- `docker ps` on the Pi shows `homeassistant` and `portainer` (running) when installed.
- Recorder logs mention `Connected to recorder db` and no SQLite warnings.
- On the NAS: `docker ps` lists the MariaDB container (if managed there) and `docker exec mariadb mysql -u <user> -p -e 'SHOW TABLES;'` succeeds.
- NAS directories:
  - `${HA_DATA_DIR}` ? Home Assistant configuration
  - `${PORTAINER_DATA_DIR}` ? Portainer data
  - `${NAS_DEPLOY_DIR}/data` ? MariaDB data files

Document any anomalies in `docs/llm/HANDOFF.md` together with timestamps and corrective actions.
