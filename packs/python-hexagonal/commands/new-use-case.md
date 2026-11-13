---
description: Scaffold a new use case or module following the new-use-case skill. $ARGUMENTS - name and one line of purpose.
argument-hint: <name> <purpose>
---

Create: `$ARGUMENTS`

1. Read `.claude/skills/hexagonal-architecture-py/SKILL.md` and `.claude/skills/new-use-case/SKILL.md`.
2. Before writing code, ask the user what `new-use-case` lists under Prerequisites (one block at a time, never assume), plus anything the ADRs in `docs/decisions/` leave open.
3. Implement per the skill, then run the project's checks from `AGENTS.md`.
