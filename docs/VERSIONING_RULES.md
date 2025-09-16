# Versioning Rules - PiHA-Deployer

## Version Format

Standard: Semantic Versioning (SemVer) — MAJOR.MINOR.PATCH

## Version Location

Where versions live: in `VERSION="x.y.z"` lines at the top of each script file.

Current versions
- node-red/install-node-red.sh: 1.0.67
- node-red/PiHA-Deployer-NodeRED.sh: 1.0.34
- node-red/configure-syncthing.sh: 1.1.5
- node-red/load_env_vars.sh: 1.0.4

## Version Bump Rules

PATCH (x.y.Z) — Small fixes
- Log or error message improvements
- Bug fixes that don't change interface
- Documentation updates
- Code cleanup without functional changes

MINOR (x.Y.z) — New features, non-breaking
- New optional configuration variables
- New non-breaking options or services in docker-compose.yml
- Feature additions that can be disabled

MAJOR (X.y.z) — Breaking changes
- New required .env variables or changed required semantics
- Structural folder changes that affect usage
- docker-compose.yml changes requiring manual intervention
- Removals or incompatible behavior changes

## Version Synchronization Rule

If a change affects multiple scripts in the same component, bump the version on ALL affected scripts to keep them aligned.

## Quick Reference Examples

- Fix typo in a log message: 1.0.67 -> 1.0.68 (PATCH)
- Standardize error prefixes: 1.1.5 -> 1.1.6 (PATCH)
- Add optional backup feature: 1.0.67 -> 1.1.0 (MINOR)
- Add a new Docker service: 1.0.34 -> 1.1.0 (MINOR)
- Require new .env variable: 1.1.0 -> 2.0.0 (MAJOR)

## Version Update Process

1) Identify impact level (patch/minor/major) using the rules above
2) Find all affected scripts in the component
3) Update VERSION lines in all affected files
4) Update docs/llm/HANDOFF.md with new versions
5) Append an entry to docs/llm/HISTORY.md including version impact

### Environment variables (special handling)
- Do not edit `.env.example`; it is generated automatically from `.env` by a plugin.
- Do not change or remove existing credentials in `.env`.
- If adding a new variable:
  - Propose and document the variable in README and HANDOFF (name, purpose, expected format).
  - Update scripts to read it safely.
  - Ask the user to add it to `.env`; the plugin will regenerate `.env.example`.
  - If the variable is required for existing flows, consider this a MAJOR change and document rationale in HISTORY.

Important Notes
- Never guess; consult this file when in doubt
- Be conservative; prefer the higher bump if uncertain
- Document the rationale in HISTORY.md
