# Application Layer

This area covers the automation applications that consume the shared infrastructure and implement leadership/failover behaviour.

## Scope
- **home-assistant/haos/**: guidance and tooling for the primary HAOS appliance (snapshots, restore drills, connection to infrastructure contracts).
- **home-assistant/docker-standby/**: managed Docker deployment that stays in observer mode until promoted.
- **home-assistant/leadership/**: MQTT contract, promotion workflow, health heartbeat definitions, and associated tests.
- **control-plane/**: NAS-resident orchestrators that monitor health, publish leadership markers, and trigger PoE power cycles when required.

> Migration is incremental. Until each component lands here, the legacy scripts under the repository root continue to function. Refer to `docs/RESTRUCTURE_PLAN.md` for live status.
