# Home Assistant Dual-Node Validation Runbook

This runbook verifies that Home Assistant OS (primary) and the Docker standby can coexist with the shared infrastructure (MariaDB, Mosquitto) before migrating other services.

## 0. Infrastructure Preparation (NAS)

Complete these steps once so both Raspberry Pi hosts can rely on the shared services. The idea is to edit the `.env` files from your workstation and then run the curl installer on the NAS.

### 0.1 Deploy MariaDB (Recorder backend)

1. **On your workstation (Windows/Mac/Linux)**
   - Download <https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/infrastructure/mariadb/.env.example> and save it as `.env`.
   - Edit the file locally (Notepad/VSCode/etc.) filling in `MARIADB_ROOT_PASSWORD`, `MARIADB_PASSWORD`, and the remaining values.
   - Copy the final `.env` to the NAS share (e.g. `\\<NAS>\Container\compose\piha-homeassistant-mariadb`).

2. **On the NAS via SSH**

```bash
ssh <nas-user>@<NAS_IP>
mkdir -p /share/Container/compose/piha-homeassistant-mariadb
cd /share/Container/compose/piha-homeassistant-mariadb
curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/infrastructure/mariadb/setup-nas-mariadb.sh | bash
docker compose ps
```

(If you do not want to use SMB, you can run `curl -fsSL .../.env.example -o .env`, edit it with your preferred editor, and then execute the script.)

### 0.2 Deploy Mosquitto (Shared MQTT broker)

1. **On your workstation**
   - Download <https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/infrastructure/mqtt/.env.example>, save it as `.env`, and update the credentials.
   - Copy the `.env` to `\\<NAS>\Container\compose\piha-homeassistant-mqtt` (create the folder if it does not exist).

2. **On the NAS via SSH**

```bash
ssh <nas-user>@<NAS_IP>
mkdir -p /share/Container/compose/piha-homeassistant-mqtt
cd /share/Container/compose/piha-homeassistant-mqtt
curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/infrastructure/mqtt/docker-compose.yml -o docker-compose.yml
curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/infrastructure/mqtt/setup-mosquitto.sh -o setup-mosquitto.sh
chmod +x setup-mosquitto.sh
./setup-mosquitto.sh
docker compose ps
```

After these steps both containers (`mariadb`, `mosquitto`) should appear as `running`.\n## Goals

- Confirm both Raspberry Pi hosts start clean (no residual containers or volumes).
- Install/refresh HAOS on the primary Pi and the Docker standby stack on the secondary Pi.
- Validate connectivity to shared MariaDB and Mosquitto.
- Check leadership heartbeats and basic health monitoring prior to automating PoE failover.

## Step 1 ? Baseline Verification

Perform these checks before installing or resetting any Pi.

### On the NAS

```bash
# Verify MariaDB container
ssh <nas-user>@<NAS_IP>
cd /share/Container/compose/piha-homeassistant-mariadb
docker compose ps

# Verify Mosquitto container
cd /share/Container/compose/mqtt
docker compose ps

```

Expect both services in `running` status.

### On each Raspberry Pi

```bash
ssh <pi-user>@<pi-ip>
# Stop any leftover containers
sudo docker ps
sudo docker stop $(sudo docker ps -aq) 2>/dev/null || true
sudo docker rm $(sudo docker ps -aq) 2>/dev/null || true

# Remove old compose directories
sudo rm -rf ~/piha-home-assistant ~/piha-*

# Check CIFS mount
mount | grep /mnt/piha || true

```

Reflash HAOS on the primary Pi if necessary.

## Step 2 ? Install Home Assistant OS (Primary)

1. Flash HAOS to the primary Pi and power it via PoE.
2. Complete the onboarding wizard (`http://<haos-ip>:8123`).
3. Configure the recorder to use MariaDB (`infrastructure/mariadb/README.md`).
4. Configure MQTT integration to point at the shared broker (`infrastructure/mqtt/README.md`).
5. Create a snapshot once the basic configuration is set (Settings ? System ? Backups ? Create Backup).

### Quick Checks

```bash
ha core logs --tail=50
ha backups list
mosquitto_sub -h <nas-ip> -t piha/leader/home-assistant/state -v

```

Ensure HAOS publishes `state=leader` (via automation/script) and connects to MariaDB/Mosquitto without errors.

## Step 3 ? Install Docker Standby (Secondary Pi)

1. Prepare working directory:

```bash
ssh <pi-user>@<standby-ip>
mkdir -p ~/piha-home-assistant
cd ~/piha-home-assistant
mkdir -p common

```

2. Populate `common/common.env` and `.env` with NAS credentials, recorder DSN, and leadership variables (see `home-assistant/README.md`).
3. Run the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/home-assistant/install-home-assistant.sh | sudo bash

```

4. Disable automations on the standby to keep observer mode:

```bash
sudo docker exec -it homeassistant bash -c "ha automation turn_off --all"

```

5. Confirm the standby sees the primary heartbeat without publishing `state=leader`.

### Quick Checks

```bash
sudo docker compose ps
sudo docker logs homeassistant --tail 50
mosquitto_sub -h <nas-ip> -t piha/leader/home-assistant/heartbeat -v

```

## Step 4 ? Control Plane Smoke Test

Manual checks until automation is in place:

```bash
mosquitto_sub -h <nas-ip> -C 1 -t piha/leader/home-assistant/heartbeat -v
curl -sf http://<haos-ip>:4357/supervisor/ping
curl -sf http://<standby-ip>:8123/api/ | head -n 5 || echo "Standby API requires token"

```

Record timestamps and confirm both hosts respond.

## Step 5 ? Promotion Drill (Manual)

1. Stop HAOS core:

```bash
ha core stop

```

2. Wait >90 seconds (detect missing heartbeat).
3. Promote the standby:

```bash
mosquitto_pub -h <nas-ip> -t piha/leader/home-assistant/cmd -m promote

```

4. Verify standby publishes `state=leader` and automations run.
5. Restore HAOS snapshot, publish `cmd=demote`, standby returns to observer mode.

## Step 6 ? Documentation & Handoff

- Capture logs/outputs in this runbook after each drill.
- Update `docs/llm/HANDOFF.md` with any anomalies.
- Once this validation succeeds, proceed with PoE automation and Zigbee2MQTT migration.


