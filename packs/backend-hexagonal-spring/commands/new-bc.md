---
description: Scaffold a new bounded context following the new-bounded-context skill. $ARGUMENTS - context name and one line of purpose.
argument-hint: <context-name> <purpose>
---

Create the bounded context: `$ARGUMENTS`

1. Read `.claude/skills/hexagonal-architecture/SKILL.md` and `.claude/skills/new-bounded-context/SKILL.md`.
2. Before writing code, ask the user (one block at a time, never assume): the aggregate root and its states, what it needs from other contexts, and anything the architecture/data/auth ADRs in `docs/decisions/` leave open.
3. Implement per the skill, then apply `.claude/skills/pre-delivery-review/SKILL.md` and run the project's test command from `AGENTS.md`.
