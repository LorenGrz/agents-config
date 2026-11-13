# 0026 — Skills folder, one skill per tool, and a fixed template per markdown type

Status: accepted (2026-11-13). Builds on ADR 0001 (single repo), 0011 (global vs project scope), 0012
(organizations) and 0017 (intent router).

## Context

The hub had grown flat: seven category folders, seven integration skills mixed in with them, external
symlinks and `packs/` all at the repo root next to `config/`, `scripts/` and `docs/`. A new reader (or a
model) could not tell skills from tooling at a glance. Git and GitHub were split across two skills
(`git-workflow`, `github-usage`), against the rule of one skill per tool. The markdown files followed
different shapes from one skill to the next, so every agent had to relearn how each file was organized.

Organization repos also depended on the hub being installed: a teammate who does not use `agents-config`
had no way to get the org's skills for GitHub, Jira, Slack or Google, only the org's product skills.

## Decision

- **`skills/` folder.** Every skill lives in `skills/<category>/<skill>/`. Categories: `aws`, `development`,
  `devops`, `meta`, `productivity`, `quality`, `security`, plus `integrations/` for the skills that own an
  outside tool (`github-usage`, `jira-usage`, `slack-usage`, `google-workspace-usage`, `obsidian-vault`,
  `notebooklm-obsidian-sync`, `codex-review`). `skills/external/` holds the per-machine symlinks (omarchy,
  omarchy-app, diagnose-crash, superwhisper); it stays gitignored. `packs/` stays at the root.
- **`~/.agents/skills` points at `<hub>/skills`** (before: the hub root). `sync.sh` searches `skills/` and
  mirrors `skills/external/*` explicitly, because `find` does not descend into symlinks.
- **One skill per tool.** `git-workflow` is merged into `github-usage` and no longer exists: git and GitHub
  are one skill, in `integrations/`. This is the only skill rename of the reorganization. ADRs and plans
  that name `git-workflow` are history and are not rewritten.
- **A fixed template per markdown type**, so any model reads each type the same way. Contents are not
  deleted to fit a template; long skills are not split.

  | Type | Shape |
  |---|---|
  | SKILL.md | Frontmatter `name` (equal to the folder) and `description` ("Use when ..."). Sections, in this order and only these: `Objective`, `When to use`, `Prerequisites`, `Workflow`, `Rules`, `Reference`, `Output`, `Verification`, `Claude Code`, `Shortcuts`. `Workflow` or `Rules` is required; `Shortcuts` is last and keeps the `gen-intents` format. `Claude Code` is the only place for ToolSearch, subagents and hooks |
  | Reference | `# Title`, a "Read when: ..." line, no repetition of the SKILL.md |
  | Command | Frontmatter `description` and `argument-hint`; sections `Source`, `Rules`, `Steps`, `Output`, `Stop when` |
  | Rule (`config/rules`) | `paths:` frontmatter and `## Topic` with imperative bullets |
  | Agent | `Before`, `Do`, `Never`, `Return` |
  | Profile | `Identity`, `GitHub`, `Stack`, `Model routing`, `Local tool paths`, `Skill routing`, `OS` |
  | POLICIES (org) | A short summary, a core section, a project section and one section per product; no personal identity; dates as "in force since" |
  | Folder README / AGENTS.md | `Purpose`, `Layout`, `How to add`, `Checks`; AGENTS.md adds `Rules` and `Pointers` |

  Existing shapes map onto it: `Operating Rules` becomes `Rules`; `Role`, `Responsibilities` and
  `Guardrails` become `Objective` plus `Rules` with `###` topics; free-form skills gain an `Objective`
  and their `##` headings drop to `###`. `orca-cli`, `orchestration` and `frontend-design` are exempt
  (frontmatter only).
- **`scripts/lint-docs.sh`** checks the SKILL.md template (frontmatter, `name` equal to the folder,
  allowed headings, their order, `Workflow` or `Rules`, `Shortcuts` last), `config/rules/*.md` (`paths:`)
  and `packs/*/commands/*.md` (`description`). It starts in CI as a warning (exit 0) and becomes an error
  (`--strict`) once the existing skills are migrated.
- **Organization repos are self-sufficient.** An org repo carries its own `.claude-plugin/`, `hooks/` (a
  SessionStart hook that shows its POLICIES summary), `install.sh`, `AGENTS.md` and `README.md`, so it
  installs as a Claude Code plugin or with its own script, without the hub. Its skills cover the same tools
  as the hub's integration skills, with the org's rules. `org.json` `replaces` maps each hub integration
  skill to the org's (for example `github-usage` to the org's GitHub skill), so only one of the two
  applies in the org's repos. The contract is documented in `organizations/README.md`, and
  `org.json` gains separate `pr_title_language` and `pr_body_language` defaults.

## Consequences

- Paths change: everything that read `<hub>/<category>/<skill>` now reads `<hub>/skills/<category>/<skill>`
  (`sync.sh`, `gen-plugin.sh`, `gen-intents.sh`, `export-obsidian.sh`, `project-agents.sh`, rulesync, the
  project-init scripts, the CI and the tests). A script with a relative `../` into the hub goes one level
  deeper.
- Each machine re-runs `install.sh` once so `~/.agents/skills` points at `<hub>/skills`.
- Anything that named `git-workflow` (hooks, `intents.json`, `config/AGENTS.md`, packs, project-init, READMEs)
  now names `github-usage`. Old ADRs and plans keep the old name as history.
- Until the skills are migrated, `lint-docs.sh` reports many violations; CI only warns. The strict mode is
  the gate for the migration batch.
- The org-side `replaces` for hub integration skills only removes copies installed in a project. For the
  global hub skills the intent router still has to translate the suggested skill with the org's `replaces`;
  that is a follow-up in `config/hooks/intent-router.sh`.
- Org repos that stop depending on the hub lose the guarantee that the hub's hooks and rules are present,
  so their `install.sh` refuses to install into a project already managed by `agents-config`.
