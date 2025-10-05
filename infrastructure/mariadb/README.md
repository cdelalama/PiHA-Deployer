# MariaDB Service (Infrastructure Layer)

This directory will host the NAS-managed MariaDB deployment that acts as the canonical Recorder backend for Home Assistant (HAOS + Docker standby). It replaces the legacy `home-assistant/mariadb/` path once the migration completes.

## Current State
- Deployment scripts (`setup-nas-mariadb.sh`, `docker-compose.yml`, `.env.example`) still live under `home-assistant/mariadb/` and remain operational.
- Documentation in that folder describes how to bootstrap MariaDB on the NAS via SSH and how Home Assistant should point `recorder.db_url` to it.
- Backups and restore drills are not yet formalised; add them here as part of Phase 2 of the restructure (`docs/RESTRUCTURE_PLAN.md`).

## Migration Plan
1. **Copy Assets**
   - Move `setup-nas-mariadb.sh`, `docker-compose.yml`, and `.env.example` into this directory.
   - Update scripts to point to the new location and refresh URLs in documentation.
2. **Document Operations**
   - Add a backup/restore playbook (dump schedule, retention, verification) referencing NAS tooling.
   - Note the integration points for the NAS control plane (health checks, alerts).
3. **Update References**
   - Rewrite Home Assistant documentation to reference `infrastructure/mariadb/` once scripts land here.
   - Remove the legacy folder after confirming the new path is in production.

## Immediate Tasks (Phase 2)
- Audit existing `.env` variables and align naming with the central secrets contract.
- Specify where dumps are stored on the NAS (e.g., `${NAS_BACKUP_DIR}/mariadb/`).
- Define a restore test cadence (e.g., monthly restore into a test container).

## Usage (Legacy Reference)
Until migration finishes, follow `home-assistant/mariadb/README.md` for bootstrap steps. The ledger in `docs/RESTRUCTURE_PLAN.md` tracks progress and ownership.

Keep this README updated as assets move in.
