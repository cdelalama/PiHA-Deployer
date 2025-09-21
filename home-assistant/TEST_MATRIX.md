# Home Assistant + MariaDB Test Matrix

This checklist covers the scenarios we expect to exercise when validating the Home Assistant installer (`home-assistant/install-home-assistant.sh`) and the NAS helper (`home-assistant/mariadb/setup-nas-mariadb.sh`). Run the ones that match the change you want to verify.

## 1. Home Assistant Installer (v1.1.10)

### 1A. Fresh install without MariaDB
- **Prep**: Create a clean working dir (`mkdir -p ~/piha-home-assistant && cd ~/piha-home-assistant`). Populate `.env` *without* `ENABLE_MARIADB_CHECK` (or set it to `false`). Ensure `${HA_DATA_DIR}`, `${BASE_DIR}`, and `${PORTAINER_DATA_DIR}` do not exist or are empty.
- **Run**: `curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/install-home-assistant.sh | sudo bash`
- **Expect**: Installer completes, Home Assistant and Portainer containers running, recorder remains on SQLite.

### 1B. Fresh install with MariaDB
- **Prep**: Same as 1A but set `ENABLE_MARIADB_CHECK=true` and provide `MARIADB_*` values that point to a running MariaDB instance (see Section 2). Directories on NAS must be empty.
- **Run**: `curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/install-home-assistant.sh | sudo bash`
- **Expect**: Installer verifies MariaDB, writes recorder config, and starts both containers.

### 1C. Existing data - interactive run
- **Prep**: Download the script locally (`curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/install-home-assistant.sh -o install-home-assistant.sh`). Leave content in `${HA_DATA_DIR}`, `${BASE_DIR}`, `${PORTAINER_DATA_DIR}`.
- **Run**: `sudo bash install-home-assistant.sh`
- **Expect**: Prompt `Continue and reuse these directories? [y/N]`.
  - Reply `y`: installer reuses directories and proceeds.
  - Reply `n` (or press Enter): installer aborts and lists directories to remove.

### 1D. Existing data - non-interactive, reuse not declared
- **Prep**: Same data setup as 1C. `.env` must **not** contain `HA_ALLOW_EXISTING_DATA=true`.
- **Run**: `curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/install-home-assistant.sh | sudo bash`
- **Expect**: Installer aborts, prints the list of directories, and instructs to set `HA_ALLOW_EXISTING_DATA=true` or remove them.

### 1E. Existing data - non-interactive with reuse flag
- **Prep**: Same as 1D, but add `HA_ALLOW_EXISTING_DATA=true` to `.env`.
- **Run**: `curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/install-home-assistant.sh | sudo bash`
- **Expect**: Warning about existing data, then installer proceeds without prompting.
- **Note**: Inline comments after the flag are ignored (e.g., `HA_ALLOW_EXISTING_DATA=true  # reuse NAS data`).

### 1F. Failure checks (optional)
- Missing MariaDB credentials (`ENABLE_MARIADB_CHECK=true` but incomplete `MARIADB_*`): expect abort with guidance.
- NAS unreachable (`NAS_IP` incorrect): expect abort after `Checking NAS connectivity...`.

### 1G. Cleanup / reset script
- **Prep**: Ensure `.env` is present with the NAS SSH credentials (if you want MariaDB cleaned remotely). Leave existing data in place to observe deletions.
- **Run (interactive, recommended)**:
  - `curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/uninstall-home-assistant.sh -o uninstall-home-assistant.sh`
  - `sudo bash uninstall-home-assistant.sh`
- **Run (automation)**: `curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/uninstall-home-assistant.sh | sudo bash -s -- --force` (add `--skip-nas-ssh` when you do *not* want to clean MariaDB remotely; add `--purge-local` if you want the working directory removed as well).
- **Expect**: The script stops the stack, removes `${HA_DATA_DIR}`, `${PORTAINER_DATA_DIR}`, `${DOCKER_COMPOSE_DIR}` and, unless you pass `--skip-nas-ssh`, deletes `${NAS_DEPLOY_DIR}` via SSH. Afterwards scenarios 1A/1B behave like a fresh install; on the NAS run `docker ps -a | grep ${MARIADB_CONTAINER_NAME:-mariadb}` to confirm no project MariaDB container remains.
## 2. MariaDB Helper (v1.0.7)

### 2A. Manual bootstrap directly on the NAS (recommended)
- **Prep**: `ssh <nas-user>@<NAS_IP>`, then `mkdir -p /share/Container/compose/mariadb && cd /share/Container/compose/mariadb`. Provide `.env` with SSH + DB variables.
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
- **NAS data**: `${HA_DATA_DIR}` contains Home Assistant configuration; `${NAS_DEPLOY_DIR}/data` holds MariaDB data files.



