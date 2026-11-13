---
description: Create a new feature module following the feature-module skill. $ARGUMENTS - module name and one line of purpose.
argument-hint: <module-name> <purpose>
---

Create the module: `$ARGUMENTS`

1. Read `.claude/skills/feature-module/SKILL.md`.
2. Ask the user what `feature-module` Workflow step 1 lists (one block at a time, never assume), plus how it talks to each module (facade call or event) and anything the ADRs in `docs/decisions/` leave open.
3. Implement per the skill, extend the boundary test, then run the project's checks from `AGENTS.md`.
