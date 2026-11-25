---
name: org-creator
description: Use when starting at a new company or client, when an org's rules change, or to promote a skill from a project repo to the org - create or adapt an organization (employer or client) for agents-config by extracting its policies, skills and commands from its repos into a private organizations/<name> repo that plugs into project-init. Triggers: "nueva organización", "nuevo cliente", "empiezo en una empresa", "armá la config de la empresa", "adapt to this company's policies", "new client setup", "pasá esta skill a la org", "promote this skill to the org". Reads the org's repos, asks, never invents policies.
---

# Org creator

## Objective

Create or adapt an organization as its own private repo under `organizations/<name>`; nothing about it goes into this public repo.

## Prerequisites

Read `organizations/README.md` (the contract) first.

## Workflow

1. **Ask**: org name (lowercase, dashes), GitHub owner(s) or remote pattern to recognize it, where its repos are on disk, and whether the remote private repo exists. Offer a `reasoner` pass for the structure when the org has many repos, and ask before using it.
2. **Start it**: `scripts/orgs.sh add <name> --init` (new) or `scripts/orgs.sh add <name> <git-url>` (existing, then adapt).
3. **Extract, do not invent.** From each repo read `AGENTS.md`/`CLAUDE.md`, `.claude/` (skills, commands, hooks), CI, PR/issue templates, `docs/`. Write what is stated there; mark anything inferred as a question for the user.
   - `POLICIES.md`: a summary of about 10 lines (validation fails above 15), then sections for workflow and git, architecture standards, UI and accessibility, integrations and data. Never put secrets, credentials or tokens in it.
   - Move domain-specific skills and commands into `skills/` and `commands/`. Generic ones are already in the base packs: replace a pack item with the org's own variant through `replaces` (and `assets` stack filters when it only applies to some stacks) instead of keeping both.
   - `org.json`: `match`, `defaults`, `blocklist_terms` (every name, product or system that must never reach the public repo), `index` and `critical` rows for the org's skills.
   - `interview.md`: only questions the base interview does not already ask.
4. **Check against the baseline**: an org may override conventions, never `config/baseline.md` (secrets, verification, least privilege, safe git, critical decisions asked, confirmation for outward actions). If a policy conflicts, say so and keep the baseline.
5. **Validate**: `scripts/orgs.sh validate <name>`, then apply it to a throwaway project with `scripts/project-agents.sh --org <name>` and check the result.
6. **Commit inside the org repo only.** Creating the private remote and pushing (`scripts/orgs.sh push <name>`) need the user's explicit confirmation.

## Promote a project skill to the org

A skill in a repo's `.claude/skills` that more than that repo uses (git, tracker, PR cycle, chat, a UI library
shared by several fronts) belongs to the org. Each skill keeps exactly one carrier.

1. **Place it by who uses it**: every product → the `shared` folder (`org.json`, a plugin installed per user,
   ADR 0062); one product → `<product>/skills`; one repo → it stays in that repo. Read the skill's copies
   across the org's repos first: a skill qualifies for a level only when every user at that level would run
   it unchanged.
2. **Name it** `<org>-<topic>`. When it replaces a hub skill, add the pair to `replaces` and keep only the
   org's.
3. **Keep what is true at that level.** Repo facts (check commands, merge method, module names) go to that
   repo's `AGENTS.md` «Proyecto» section, and the skill points there.
4. **Scripts** are called as `${CLAUDE_SKILL_DIR}/scripts/<name>`: a plugin skill lives in a cache, never
   in `~/.claude/skills`.
5. **Validate**: `scripts/orgs.sh validate <name>`, the leak-guard blocklist, and no other folder of the org
   ships a skill with the same name.
6. **Retire the repo copy** in a PR to that repo, with the user's OK: the repo belongs to the team.
