# skills

## Purpose

The skill library: one folder per skill, each with a `SKILL.md` that an agent loads on demand when its
`description` matches the task. Skills are grouped by category here and mirrored flat into
`~/.claude/skills` by `sync.sh` (Claude Code only reads direct children). `install.sh` also links
`~/.agents/skills` to this folder, so other agents share the same root.

Each skill follows one template, so any model reads them the same way. The history of the decision is in
`docs/decisions/0026-skills-folder-and-templates.md`.

## Layout

| Category | What goes there | Skills |
|---|---|---|
| `aws/` | AWS serverless work. Project-scoped (stack `aws`), see `aws/README.md` | `sam-deploy`, `lambda-patterns`, `iam-least-privilege`, `cost-optimizer`, `serverless-scanner` |
| `development/` | Building features and code quality | `api-contract-design`, `code-documenter`, `database-persistence-patterns`, `debug-assistant`, `frontend-design`, `nest-module-generator`, `nextjs-ssr-frontend`, `react-native-mobile`, `regex-builder-explainer`, `typescript-code-quality`, `typescript-project-starter` |
| `devops/` | Repo and release lifecycle, containers | `conventional-commit-generator`, `project-init`, `repository-context-maintainer`, `run-docker-environment` |
| `integrations/` | One skill per outside tool, with its `## Shortcuts` | `github-usage` (git and GitHub), `jira-usage`, `slack-usage`, `google-workspace-usage`, `obsidian-vault`, `notebooklm-obsidian-sync`, `codex-review` |
| `meta/` | How agents work: setup, workflow, delegation, org creation | `agents-config-setup`, `codex-workflows`, `english-prompt-coach`, `gemini-delegate`, `orca-cli`, `orchestration`, `org-creator`, `roadmap-coach`, `team-architect-agent`, `team-implementer-agent`, `team-reviewer-agent` |
| `productivity/` | Non-code deliverables (stack `office` for all but `image-annotations`) | `ats-resume-formatting`, `cv-linkedin-optimizer`, `image-annotations`, `meeting-notes-organizer`, `presentation-prep`, `professional-email-drafter` |
| `quality/` | Review and tests | `code-review-safety`, `execute-test-suite`, `react-component-validator`, `unit-test-generator` |
| `security/` | Auth and prompt-injection defense | `auth-security-basics`, `prompt-injection-defense` |
| `external/` | Symlinks to skills shipped by other tools. Gitignored, recreated per machine | `omarchy`, `omarchy-app`, `diagnose-crash`, `superwhisper` |

Which skills are global and which belong to a stack is decided by `config/scopes.json` (ADR 0011): a skill
listed under a stack is installed per project by `scripts/project-agents.sh`, any other skill is global.
Skills bundled with an architecture live in `packs/<name>/skills/`, not here.

## How to add a skill

1. Create `skills/<category>/<skill>/SKILL.md`. The folder name is the skill name. Pick the category by the
   table above; a tool with its own API or CLI goes in `integrations/`, one skill per tool.
2. Write it with this template (a skill may not repeat what another skill owns, link to it by name):
   - Frontmatter: `name` (equal to the folder) and `description` ("Use when ..."); optional keys stay as is.
   - `##` sections, only from this list and in this order: `Objective`, `When to use`, `Prerequisites`,
     `Workflow`, `Rules` (topics as `###`), `Reference`, `Output`, `Verification`, `Claude Code`
     (the only place for ToolSearch, subagents and hooks), `Shortcuts` (always last).
   - At least one of `Workflow` or `Rules`.
   - Long detail goes in `references/<topic>.md` next to the SKILL.md, starting with `# Title` and a
     `Read when: ...` line, and does not repeat the SKILL.md.
3. Run what the change touches:
   - `./sync.sh` to refresh the `~/.claude/skills` mirror.
   - `scripts/gen-plugin.sh` when the skill is global (it lists the plugin's skills; `--check` verifies).
   - `scripts/gen-intents.sh` when the skill has `## Shortcuts` (regenerates `config/intents.json` and the
     table in `config/AGENTS.md`; `--check` verifies).
   - If the skill belongs to a stack, add it to that stack in `config/scopes.json`.
4. Check it with `bash scripts/lint-docs.sh --files skills/<category>/<skill>/SKILL.md`.

`orca-cli`, `orchestration` and `frontend-design` are free-form skills and exempt from the section template:
only their frontmatter is checked.

## Checks

```bash
bash scripts/lint-docs.sh             # warn mode: prints violations, exits 0
bash scripts/lint-docs.sh --strict    # exits 1 on any violation
bash scripts/lint-docs.sh --files skills/meta/roadmap-coach/SKILL.md
scripts/gen-plugin.sh --check         # plugin skill list matches the global skills
scripts/gen-intents.sh --check        # Shortcuts table is up to date
bash scripts/test-intents.sh
```
