# NAS Configuration Guide

## Overview

This document describes NAS-specific configurations for PiHA-Deployer. Different NAS vendors have different directory structures and Docker implementations, requiring adaptation of deployment scripts.

## Current Setup: QNAP NAS

### Hardware
- Model: QNAP NAS with ZFS storage pools
- Storage pools: ZFS1_DATA through ZFS530_DATA
- Container Station: Installed for Docker support

### Directory Structure

```
/share/
├── Container/                    # User container deployments (target for MariaDB)
│   ├── compose/                 # Docker compose projects
│   ├── n8n/                     # Individual containers
│   ├── syncthing/               # Syncthing data
│   └── container-station-data/  # Container Station system data
├── piha/                        # -> ZFS26_DATA/piha/ (Pi data storage)
│   └── hosts/                   # Group-by-host data
│       ├── ha-pi-01/
│       └── z2m-pi-01/
├── docker/                      # Docker system directory
└── ZFS530_DATA/                 # System storage pool
    └── .qpkg/
        └── container-station/   # Container Station installation
            ├── bin/docker       # Docker binary location
            └── docker/          # Docker root dir
```

### Docker Configuration
- **Docker Binary**: `/share/ZFS530_DATA/.qpkg/container-station/bin/docker`
- **Docker Root Dir**: `/share/ZFS530_DATA/.qpkg/container-station/docker`
- **User Containers**: `/share/Container/`
- **Container Station Data**: `/share/ZFS19_DATA/Container/container-station-data/`

### Recommended Paths for Container Deployments
- **User Containers**: `/share/Container/compose/`
- **Individual Services**: `/share/Container/compose/{service-name}/`
- **Data Storage**: Service-specific data directories under compose folders

### Pi Data Mount Points
- **Pi Mount Target**: `/mnt/piha` (on Pi devices)
- **NAS Share Path**: `/share/piha/` (CIFS/SMB exported)
- **Actual Storage**: `/share/ZFS26_DATA/piha/`

## Common Script Adaptation Issues

### QNAP-Specific Considerations
1. **Path differences**: Generic Linux paths like `/opt/` don't exist, use `/share/Container/` instead
2. **Container Station**: Docker binaries and data are in `.qpkg/container-station/`
3. **Environment setup**: Scripts may need adaptation for QNAP directory structure
4. **Permission handling**: QNAP may have different user/group requirements

### General Adaptation Guidelines
- Update default deployment directories to match NAS vendor conventions
- Ensure scripts can detect NAS type and adjust paths accordingly
- Test one-liner curl commands with proper working directory setup
- Verify Docker and compose command availability

## Adaptation for Other NAS Vendors

### Synology
- Container Manager path: `/volume1/docker/`
- User data: `/volume1/homes/`
- Recommended container path: `/volume1/docker/{service-name}/`

### TrueNAS
- Datasets path: `/mnt/pool-name/`
- Apps path: `/mnt/pool-name/ix-applications/`
- Recommended container path: `/mnt/pool-name/docker/{service-name}/`

### Generic Linux
- System Docker: `/var/lib/docker/`
- User data: `/home/user/docker/`
- Recommended container path: `/opt/{service-name}/`

## Configuration Variables

Different NAS vendors require different base paths in deployment scripts. Common variables to adapt:

### QNAP Example
```bash
# QNAP-specific paths
NAS_DEPLOY_DIR=/share/Container/compose/{service-name}
DATA_DIR=/share/Container/compose/{service-name}/data
NAS_SSH_HOST=192.168.1.100
NAS_SSH_USER=your-nas-user
NAS_SSH_PORT=22
```

### Synology Example
```bash
# Synology-specific paths
NAS_DEPLOY_DIR=/volume1/docker/{service-name}
DATA_DIR=/volume1/docker/{service-name}/data
```

### TrueNAS Example
```bash
# TrueNAS-specific paths
NAS_DEPLOY_DIR=/mnt/pool-name/docker/{service-name}
DATA_DIR=/mnt/pool-name/docker/{service-name}/data
```

---

*This configuration is specific to the current deployment. Update paths and variables according to your NAS setup.*