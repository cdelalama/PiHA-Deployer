# Home Assistant + MariaDB Test Matrix

This checklist covers the scenarios we expect to exercise when validating the Home Assistant installer (`home-assistant/install-home-assistant.sh`) and the NAS helper (`infrastructure/mariadb/setup-nas-mariadb.sh`). Run the ones that match the change you want to verify.

## 1. Home Assistant Installer (v1.3.0)

### 1A. Fresh install without MariaDB

**Prep**

```bash

```

```bash
mkdir -p ~/piha-home-assistant
cd ~/piha-home-assistant
mkdir -p common

# Create configuration files with secure permissions
touch .env
chmod 600 .env
touch common/common.env
chmod 600 common/common.env

```

- Populate `common/common.env` and `.env` with NAS credentials and host overrides (keep `RECORDER_BACKEND=sqlite`).
- Optionally set `SQLITE_DATA_DIR`; ensure the local recorder path (default `/var/lib/piha/home-assistant/sqlite`) is empty (`sudo rm -rf ${SQLITE_DATA_DIR:-/var/lib/piha/home-assistant/sqlite}/*`).
- Ensure `${BASE_DIR}` and `${PORTAINER_DATA_DIR}` are absent on the NAS.

**Run**

```bash
curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/install-home-assistant.sh | sudo bash

```

**Expect**

- Installer prints `Waiting 5s for NAS writes to settle... (SQLite on CIFS guard)` before `Launching stack...`.
- Containers `homeassistant` and `portainer` reach `running` state.

**Checks**

```bash
sudo docker compose ps
sudo docker logs homeassistant --tail 50
sudo docker logs portainer --tail 20
mount | grep /mnt/piha

```

**Notes**

- Override the cooldown with `NAS_COOLDOWN_SECONDS=<seconds>` (use `0` only when data lives on local storage).
- Confirm `${HA_DATA_DIR}` is created on the NAS and `${SQLITE_DATA_DIR}` now contains `home-assistant_v2.db*` (the installer logs the paths when it runs).

### 1B. Fresh install with MariaDB

**Prep**

- Reuse the **Prep** steps from 1A.
- Set `.env` with `RECORDER_BACKEND=mariadb` plus valid `MARIADB_*` credentials for the target MariaDB instance.
- Ensure `${HA_DATA_DIR}`, `${BASE_DIR}`, and `${PORTAINER_DATA_DIR}` are empty on the NAS.
- Confirm `${SQLITE_DATA_DIR:-/var/lib/piha/home-assistant/sqlite}` is reachable from the Pi (the installer creates it automatically if missing).

**Run**

```bash
curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/install-home-assistant.sh | sudo bash

```

**Expect**

- MariaDB check succeeds and the installer prints `[OK] Restarting homeassistant to apply requirements.txt`.
- Recorder uses `PyMySQL==1.1.0` and containers remain `running`.

**Checks**

```bash
sudo docker compose ps
sudo docker logs homeassistant --tail 80 | grep -E 'MariaDB|Recorder'

```

### 1C. Existing data - interactive run

**Prep**

```bash
curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/install-home-assistant.sh -o install-home-assistant.sh

```

- Leave `common/common.env` and `.env` populated with their existing values.
- Keep existing data inside `${HA_DATA_DIR}`, `${BASE_DIR}`, and `${PORTAINER_DATA_DIR}`.

**Run**

```bash
sudo bash install-home-assistant.sh

```

**Expect**

- Prompt `Continue and reuse these directories? [y/N]`.
   - Reply `y` to reuse the data and proceed.
   - Reply `n` (or press Enter) to abort and list the directories to clean.

### 1D. Existing data - non-interactive, reuse not declared

**Prep**

- Keep the data directories populated (same as 1C).
- Ensure `.env` does not include `HA_ALLOW_EXISTING_DATA=true`.

**Run**

```bash
curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/install-home-assistant.sh | sudo bash

```

**Expect**

- Installer aborts and lists the directories to remove or advises adding `HA_ALLOW_EXISTING_DATA=true`.

### 1E. Existing data - non-interactive with reuse flag

**Prep**

- Keep the data directories populated.
- Set `.env` with `HA_ALLOW_EXISTING_DATA=true` (inline comments remain supported).

**Run**

```bash
curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/install-home-assistant.sh | sudo bash

```

**Expect**

- Installer warns about existing data and continues without prompting.

### 1F. Failure checks (optional)

**Suggested scenarios**

- `RECORDER_BACKEND=mariadb` with incomplete `MARIADB_*` credentials.
- `NAS_IP` set to an unreachable host.

**Expected result**

- Installer aborts with clear remediation guidance.

### 1G. Cleanup / reset script

**Prep**

- `.env` present with NAS and SSH credentials.
- Leave existing data in place to observe deletions.

**Interactive download**

```bash
curl -fSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/uninstall-home-assistant.sh -o uninstall-home-assistant.sh
printf '\033[0;34mDownloaded uninstall-home-assistant.sh; run sudo bash uninstall-home-assistant.sh next\033[0m\n'

```

**Interactive run**

```bash
sudo bash uninstall-home-assistant.sh

```

- Answer the prompts (purge working dir/images), choose whether to keep the NAS configuration, and decide whether to retain the recorder data when prompted.
- Capture both branches during testing (keep configuration + keep recorder, keep configuration + wipe recorder) to ensure the prompts behave as expected for SQLite and MariaDB.
- Non-interactive or `--force` runs skip the prompts and perform a full wipe (configuration and recorder).

**Automation**

```bash
curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/uninstall-home-assistant.sh | sudo bash -s -- --force [--skip-nas-ssh] [--purge-local] [--purge-images] [--keep-env]

```

**Checks**

```bash
sudo docker ps -a | grep -E 'homeassistant|portainer'
sudo ls ${HA_DATA_DIR}

```

- On the NAS, confirm `${NAS_DEPLOY_DIR}` and any MariaDB containers are removed; on the Pi, verify `${SQLITE_DATA_DIR:-/var/lib/piha/home-assistant/sqlite}` is empty when purge flags are used.
- When the configuration is wiped, `${NAS_MOUNT_DIR}/hosts/${HOST_ID}` should no longer be present unless other stacks recreated it (empty host directories are pruned automatically).

### 1H. End-to-end reset regression

**Flow**

1. Run 1G with the desired options.
2. Run 1A (without MariaDB).
3. Run 1B (with MariaDB) if required.

**Checks**

- After 1G: `.env` absent unless `--keep-env` was used; directories removed unless you opted to keep the NAS configuration (in which case `${HA_DATA_DIR}`/`${SQLITE_DATA_DIR}` remain); `docker ps` shows no `homeassistant`/`portainer`.
- After 1A/1B: installer output shows `Waiting 5s for NAS writes to settle...` and, when MariaDB is enabled, `[OK] Restarting homeassistant to apply requirements.txt`.
- Home Assistant reachable at `http://<pi>:8123` and Portainer at `http://<pi>:9000`.

**Artifacts**

- Collect timestamps/logs for HANDOFF and HISTORY.

## 2. MariaDB Helper (v1.0.9)

### 2A. Manual bootstrap directly on the NAS (recommended)

- __Prep__: `ssh <nas-user>@<NAS_IP>`, then `mkdir -p /share/Container/compose/piha-homeassistant-mariadb && cd /share/Container/compose/piha-homeassistant-mariadb`. Provide `.env` with SSH + DB variables.
- **Run**: `curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/infrastructure/mariadb/.env.example -o .env\nchmod 600 .env\nvi .env\ncurl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/infrastructure/mariadb/setup-nas-mariadb.sh | bash`
- **Expect**: Script detects local execution, preserves `.env` in `.env.bootstrap`, downloads compose if missing, starts container.

### 2B. Remote bootstrap from a Pi/PC clone

- **Prep**: In the repo clone, configure `infrastructure/mariadb/.env` with NAS SSH credentials.
- **Run**: `bash infrastructure/mariadb/setup-nas-mariadb.sh`
- **Expect**: SSH session creates directories, copies compose/.env, and runs `docker compose up` remotely.

### 2C. Re-run helper on existing deployment

- **Prep**: Execute 2A or 2B first. Ensure `.env.bootstrap` exists in the target directory.
- **Run**: Repeat 2A or 2B.
- **Expect**: Handles existing files gracefully, refreshes `.env`, leaves `.env.bootstrap` untouched, restarts container if needed.

### 2D. Manual fallback

- **Prep**: On the NAS, place `docker-compose.yml` and `.env` manually in the target directory.
- **Run**: `docker compose up -d`
- **Expect**: Container starts; useful for verifying the compose file independent of the helper.

## 3. Verification steps

After each scenario, confirm:

- **Home Assistant**: `docker ps` shows `homeassistant` + `portainer`. `docker logs homeassistant | grep Recorder` reveals whether MariaDB is in use.
- **MariaDB**: `docker ps` includes `mariadb`. From the NAS run `docker exec -it mariadb mysql -u homeassistant -p` and check `SHOW TABLES;` or `SELECT COUNT(*) FROM events;`.
- __NAS data__: `${HA_DATA_DIR}` contains Home Assistant configuration; `${NAS_DEPLOY_DIR}/data` holds MariaDB data files; `${SQLITE_DATA_DIR:-/var/lib/piha/home-assistant/sqlite}` stores the SQLite recorder when `RECORDER_BACKEND=sqlite`.


