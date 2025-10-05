# NAS Configuration Guide

## Overview
This guide captures the NAS conventions PiHA-Deployer expects today and highlights QNAP specifics. Adjust the paths to match your NAS vendor before running any automation scripts.

## Current Reference: QNAP NAS

### Hardware
- Model: QNAP NAS with ZFS storage pools
- Container runtime: Container Station (Docker + Docker Compose)

### Directory Layout Snapshot
```
/share/
|-- Container/                     # User container deployments (target for MariaDB)
|   |-- compose/                   # Docker Compose projects live here
|   |   |-- mariadb/               # MariaDB deployment folder (default target)
|   |   `-- ...
|   |-- n8n/
|   `-- syncthing/
|-- piha/                          # NAS share exported to Raspberry Pi hosts
|   `-- hosts/                     # Group-by-host data managed by PiHA
|       |-- ha-pi-01/
|       `-- z2m-pi-01/
|-- ZFS530_DATA/
    `-- .qpkg/
        `-- container-station/     # Container Station installation (docker binaries)
```

### Key Paths
- Docker binary: `/share/ZFS530_DATA/.qpkg/container-station/bin/docker`
- Docker root dir: `/share/ZFS530_DATA/.qpkg/container-station/docker`
- User container projects: `/share/Container/compose/`

### Recommended Defaults for MariaDB Script
- `NAS_DEPLOY_DIR=/share/Container/compose/mariadb`
- `MARIADB_DATA_DIR=/share/Container/compose/mariadb/data`

These defaults are now baked into `infrastructure/mariadb/setup-nas-mariadb.sh`. Override them in `.env` if your NAS uses a different layout.

When bootstrapping directly on the NAS, create the directory and move into it before downloading files:
```
ssh <nas-user>@<NAS_IP>
mkdir -p /share/Container/compose/mariadb
cd /share/Container/compose/mariadb
```
Then copy or create `.env` in that folder and either run the one-liner shown in the component README (download `setup-nas-mariadb.sh` and execute it) or use `docker compose up -d` manually. If you keep `infrastructure/mariadb/.env` in your PiHA-Deployer clone, you can still run `bash infrastructure/mariadb/setup-nas-mariadb.sh` from there to perform the same actions over SSH.

## Common Script Adaptation Issues
1. **Path differences** - avoid `/opt/` style paths on QNAP; use `/share/Container/` instead.
2. **Docker availability** - ensure Container Station is running so `docker` and `docker compose` work over SSH.
3. **Permissions** - some NAS models require `NAS_SSH_USE_SUDO=true` so the script can create directories and run Docker.
4. **Firewall** - allow inbound TCP/3306 from the Raspberry Pi that hosts Home Assistant.

## Other Vendors (Examples)

| Vendor    | Suggested Compose Path                | Data Path Example                                |
|----------|----------------------------------------|--------------------------------------------------|
| Synology | `/volume1/docker/{service-name}`       | `/volume1/docker/{service-name}/data`            |
| TrueNAS  | `/mnt/<pool>/docker/{service-name}`    | `/mnt/<pool>/docker/{service-name}/data`         |
| Generic  | `/opt/{service-name}`                  | `/opt/{service-name}/data`                       |

Always verify that the target filesystem is local (ext4, ZFS, Btrfs, etc.). Avoid SMB/NFS paths for MariaDB data.

---
Update this document when the deployment targets or defaults change so future automation runs stay aligned with the environment.

