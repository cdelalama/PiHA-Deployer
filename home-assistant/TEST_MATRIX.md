# Home Assistant + MariaDB Test Matrix

This checklist covers the scenarios we expect to exercise when validating the Home Assistant installer (`home-assistant/install-home-assistant.sh`) and the NAS helper (`home-assistant/mariadb/setup-nas-mariadb.sh`). Run the ones that match the change you want to verify.

## 1. Home Assistant Installer (v1.1.14)

### 1A. Fresh install without MariaDB

**Prep**
```bash
mkdir -p ~/piha-home-assistant
cd ~/piha-home-assistant
```
- Ensure `common/common.env` and `.env` are populated with NAS credentials and host overrides; omit `ENABLE_MARIADB_CHECK` (or set it to `false`).
- Confirm `${HA_DATA_DIR}`, `${BASE_DIR}`, and `${PORTAINER_DATA_DIR}` do not exist on the NAS (clean slate).

**Run**
```bash
curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/install-home-assistant.sh | sudo bash
```

**Expect**
- Installer prints `Waiting 5s for NAS writes to settle... (SQLite on CIFS guard)` before `Launching stack...`.
- `homeassistant` and `portainer` containers reach `running` status.

**Checks**
```bash
sudo docker compose ps
sudo docker logs homeassistant --tail 50
sudo docker logs portainer --tail 20
mount | grep /mnt/piha
```

**Notes**
- The 5-second cooldown prevents CIFS locks from triggering `database is locked` during the recorder bootstrap; override with `NAS_COOLDOWN_SECONDS=<seconds>` (set `0` only when the data path is local storage).
- If SQLite still reports `database is locked`, stop the stack and remove `${HA_DATA_DIR}/home-assistant_v2.db*` before rerunning, as documented in `home-assistant/README.md`.
### 1B. Fresh install with MariaDB

- __Prep__: Same as 1A but set `ENABLE_MARIADB_CHECK=true` and provide `MARIADB_*` values that point to a running MariaDB instance (see Section 2). Directories on NAS must be empty.
- **Run**: `curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/install-home-assistant.sh | sudo bash`
- __Expect__: Installer verifies MariaDB, writes recorder config, starts both containers, and populates `${HA_DATA_DIR}/requirements.txt` with `PyMySQL==1.1.0` and restarts `homeassistant` when needed.

### 1C. Existing data - interactive run

- __Prep__: Download the script locally (`curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/install-home-assistant.sh -o install-home-assistant.sh`). Ensure `common/common.env` and `.env` remain populated. Leave content in `${HA_DATA_DIR}`, `${BASE_DIR}`, `${PORTAINER_DATA_DIR}`.
- **Run**: `sudo bash install-home-assistant.sh`
- **Expect**: Prompt `Continue and reuse these directories? [y/N]`.
   - Reply `y`: installer reuses directories and proceeds.
   - Reply `n` (or press Enter): installer aborts and lists directories to remove.

### 1D. Existing data - non-interactive, reuse not declared

- __Prep__: Same data setup as 1C (keep `common/common.env` + `.env` intact). `.env` must __not__ contain `HA_ALLOW_EXISTING_DATA=true`.
- **Run**: `curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/install-home-assistant.sh | sudo bash`
- __Expect__: Installer aborts, prints the list of directories, and instructs to set `HA_ALLOW_EXISTING_DATA=true` or remove them.

### 1E. Existing data - non-interactive with reuse flag

- __Prep__: Same as 1D, but add `HA_ALLOW_EXISTING_DATA=true` to `.env`.
- **Run**: `curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/install-home-assistant.sh | sudo bash`
- **Expect**: Warning about existing data, then installer proceeds without prompting.
- __Note__: Inline comments after the flag are ignored (e.g., `HA_ALLOW_EXISTING_DATA=true  # reuse NAS data`).

### 1F. Failure checks (optional)

- Missing MariaDB credentials (`ENABLE_MARIADB_CHECK=true` but incomplete `MARIADB_*`): expect abort with guidance.
- NAS unreachable (`NAS_IP` incorrect): expect abort after `Checking NAS connectivity...`.

### 1G. Cleanup / reset script

- **Prep**: Ensure `.env` is present with the NAS SSH credentials (if you want MariaDB cleaned remotely). Leave existing data in place to observe deletions.
- **Run (interactive, recommended)**:
   - `curl -fSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/uninstall-home-assistant.sh -o uninstall-home-assistant.sh && printf '\033[0;34mDownloaded uninstall-home-assistant.sh; run sudo bash uninstall-home-assistant.sh next\033[0m\n'`
   - (The curl download now prints progress; the blue message confirms success and points to the next command.)
   - `sudo bash uninstall-home-assistant.sh`

- **Run (automation)**: `curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/uninstall-home-assistant.sh | sudo bash -s -- --force` (add `--skip-nas-ssh` when you do *not* want to clean MariaDB remotely; add `--purge-local` if you want the working directory removed, `--purge-images` to delete project images, and `--keep-env` when the `.env` file must stay in place).
- __Expect__: The script stops the stack, removes `${HA_DATA_DIR}`, `${PORTAINER_DATA_DIR}`, `${DOCKER_COMPOSE_DIR}` and, unless you pass `--skip-nas-ssh`, deletes `${NAS_DEPLOY_DIR}` via SSH. By default it deletes `.env` (and `.env.bootstrap`) from the working directory once finished; verify with `ls` or set `UNINSTALL_KEEP_ENV=true` (or pass `--keep-env`) when you want to preserve it. After the main confirmation the script now prompts about purging this working directory and removing the project images when no flags/env defaults were supplied; answer `y` to enable the behaviour. If you use `--purge-local`, confirm the working directory is gone; otherwise validate that only support files remain. Afterwards scenarios 1A/1B behave like a fresh install; on the NAS run `docker ps -a | grep ${MARIADB_CONTAINER_NAME:-mariadb}` to confirm no project MariaDB container remains and ensure `${HA_DATA_DIR}/requirements.txt` is recreated with `PyMySQL==1.1.0` on the next installer run (and the script handles the restart automatically).

### 1H. End-to-end reset regression

- **Flow**: Execute 1G (uninstall with desired flags), then 1A (fresh install without MariaDB) followed by 1B (fresh install with MariaDB) if database validation is required.
- **Checks**: After 1G confirm `.env` is gone unless `--keep-env` was passed, directories listed by the uninstaller are absent, and `docker ps` no longer shows `homeassistant` nor `portainer`. After 1A/1B verify the installer output includes `Waiting 5s for NAS writes to settle...`, and when MariaDB is enabled the log prints `[OK] Restarting homeassistant to apply requirements.txt`. Confirm the UI at port 8123 and Portainer at 9000 respond.
- **Artifacts**: Capture timestamps or screenshots for each phase to attach to the session notes (HANDOFF/HISTORY).

## 2. MariaDB Helper (v1.0.9)

### 2A. Manual bootstrap directly on the NAS (recommended)

- __Prep__: `ssh <nas-user>@<NAS_IP>`, then `mkdir -p /share/Container/compose/mariadb && cd /share/Container/compose/mariadb`. Provide `.env` with SSH + DB variables.
- **Run**: `curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/mariadb/setup-nas-mariadb.sh -o setup-nas-mariadb.sh && bash setup-nas-mariadb.sh`
- **Expect**: Script detects local execution, preserves `.env` in `.env.bootstrap`, downloads compose if missing, starts container.

### 2B. Remote bootstrap from a Pi/PC clone

- **Prep**: In the repo clone, configure `home-assistant/mariadb/.env` with NAS SSH credentials.
- **Run**: `bash home-assistant/mariadb/setup-nas-mariadb.sh`
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
- __NAS data__: `${HA_DATA_DIR}` contains Home Assistant configuration; `${NAS_DEPLOY_DIR}/data` holds MariaDB data files.


