---
name: org-creator
description: Create or adapt an organization (employer or client) for agents-config - extract its policies, skills and commands from its repos into a private organizations/<name> repo that plugs into project-init. Use when starting at a new company or client, or when an org's rules change - "nueva organización", "nuevo cliente", "empiezo en una empresa", "armá la config de la empresa", "adapt to this company's policies", "new client setup". Reads the org's repos, asks, never invents policies.
---

# Org creator

## Objective

Read `organizations/README.md` (the contract) first. The org lives in its own private repo; nothing about it goes into this public repo.

## Workflow

1. **Ask**: org name (lowercase, dashes), GitHub owner(s) or remote pattern to recognize it, where its repos are on disk, and whether the remote private repo exists. Offer a `reasoner` pass for the structure when the org has many repos, and ask before using it.
2. **Start it**: `scripts/orgs.sh add <name> --init` (new) or `scripts/orgs.sh add <name> <git-url>` (existing, then adapt).
3. **Extract, do not invent.** From each repo read `AGENTS.md`/`CLAUDE.md`, `.claude/` (skills, commands, hooks), CI, PR/issue templates, `docs/`. Write what is stated there; mark anything inferred as a question for the user.
   - `POLICIES.md`: a summary of about 10 lines, then sections for workflow and git, architecture standards, UI and accessibility, integrations and data. Never put secrets, credentials or tokens in it.
   - Move domain-specific skills and commands into `skills/` and `commands/`. Generic ones are already in the base packs: replace a pack item with the org's own variant through `replaces` (and `assets` stack filters when it only applies to some stacks) instead of keeping both.
   - `org.json`: `match`, `defaults`, `blocklist_terms` (every name, product or system that must never reach the public repo), `index` and `critical` rows for the org's skills.
   - `interview.md`: only questions the base interview does not already ask.
4. **Check against the baseline**: an org may override conventions, never `config/baseline.md` (secrets, verification, least privilege, safe git, critical decisions asked, confirmation for outward actions). If a policy conflicts, say so and keep the baseline.
5. **Validate**: `scripts/orgs.sh validate <name>`, then apply it to a throwaway project with `project-agents.sh --org <name>` and check the result.
6. **Commit inside the org repo only.** Creating the private remote and pushing (`scripts/orgs.sh push <name>`) need the user's explicit confirmation.
