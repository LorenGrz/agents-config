---
description: Scaffold a new feature following the frontend-ports-adapters skill. $ARGUMENTS - feature name and one line of purpose.
argument-hint: <feature-name> <purpose>
---

Create the feature: `$ARGUMENTS`

1. Read `.claude/skills/frontend-ports-adapters/SKILL.md` (and `.claude/skills/ui-builder/SKILL.md` for the UI part).
2. Ask the user (one block at a time, never assume): the domain concepts and rules, what the feature needs from the backend or storage, and anything the ADRs in `docs/decisions/` leave open.
3. Implement per the skill, then run the project's checks from `AGENTS.md`.
