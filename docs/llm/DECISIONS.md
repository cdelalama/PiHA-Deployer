# Decisions

## D-001 - Preserve component versioning during DocKit adoption

PiHA-Deployer versions its component scripts independently, as specified in
`docs/VERSIONING_RULES.md`. The 2026-09-23 DocKit rollout adds source tooling
without changing any deployment component or introducing a shared product version.
The local `scripts/check-version-sync.sh` (tool version 1.0.0) reads the declared
Current Versions in HANDOFF and compares script headers without executing them.
Deployment, runtime and infrastructure authority remain unchanged.
