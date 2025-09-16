# LLM Start Guide - PiHA-Deployer Project

## READ THIS FIRST (MANDATORY)

You are working on PiHA-Deployer: automated deployment scripts for Raspberry Pi home automation services.

Critical reading order:
1) This file (understand rules and current state)
2) docs/PROJECT_CONTEXT.md (project vision and architecture)
3) docs/VERSIONING_RULES.md (version management rules)
4) docs/llm/HANDOFF.md (current work state and priorities)

## CRITICAL RULES (NON-NEGOTIABLE)

Language policy
- All code and documentation: English only
- Conversation with the user: Spanish only
- Comments in code: English only
- File names: English only

Documentation update rules
- Mandatory: every code change requires updating docs/llm/HANDOFF.md
- Mandatory: every session must append an entry to docs/llm/HISTORY.md
- HISTORY format: YYYY-MM-DD - [LLM_NAME] - [Brief summary] - Files: [list] - Version impact: [yes/no + which]

Version management
- Always check VERSION lines in scripts before modifying
- Never increment versions without reading docs/VERSIONING_RULES.md
- Sync versions across all scripts in the same component when bumping

Environment files
- Do not edit `.env.example`; it is generated automatically from `.env` by a plugin.
- Never change or remove existing credentials in `.env`. If a new variable is required, document it and ask the user to add it to `.env`.

## CURRENT FOCUS (synced from HANDOFF.md)

Source of truth: docs/llm/HANDOFF.md. Snapshot at last update:
- Last Updated: 2025-09-06 - ChatGPT
- Working on: Home Assistant scaffolding and documentation alignment
- Status: HA installer and compose added; docs updated; env policy emphasized

Top priorities (see HANDOFF for details):
1) Validate Home Assistant installer on a Raspberry Pi
2) Keep documentation current (HANDOFF/HISTORY, env policy)
3) Decide Portainer topology later (local now; central server later)

Do not touch (without explicit request):
- Node-RED script logic (stable)
- Working docker-compose configuration

## QUICK NAVIGATION

- Project Overview: docs/PROJECT_CONTEXT.md
- Version Rules: docs/VERSIONING_RULES.md
- Current Work State: docs/llm/HANDOFF.md
- Change History: docs/llm/HISTORY.md

## LLM-TO-LLM COMMUNICATION

When handing off to another LLM:
1) Update docs/llm/HANDOFF.md with the current state
2) Add an entry to docs/llm/HISTORY.md with your changes
3) Ensure the Current Focus snapshot above matches HANDOFF

Communication files:
- docs/llm/HANDOFF.md: operational state for next LLM (keep under 2 screens)
- docs/llm/HISTORY.md: chronological log of changes and decisions

## GETTING STARTED CHECKLIST

- [ ] Read this entire file
- [ ] Read PROJECT_CONTEXT.md
- [ ] Read VERSIONING_RULES.md
- [ ] Read current HANDOFF.md
- [ ] Confirm what you need to work on
- [ ] Start coding/documenting
- [ ] Update HANDOFF.md when done
- [ ] Add an entry to HISTORY.md before ending your session

---

IMPORTANT: If you modify any code, you MUST update the documentation files mentioned above. This is not optional.

Next step: read docs/PROJECT_CONTEXT.md

