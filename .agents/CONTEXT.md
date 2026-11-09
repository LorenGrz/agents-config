# agents-config - Repository Context

Public hub of personal agent config, skills and project scaffolding. Detail: `README.md`, ADRs in `docs/decisions/`.

## Layers

- Base (this repo): `config/` (AGENTS.md, CLAUDE.md, baseline.md, profiles, hooks, rules, agents), skills by category, `packs/`, `devops/project-init`.
- Organizations: `organizations/<name>/`, each a private repo cloned here and ignored by git (`scripts/orgs.sh`). Never commit them or their terms here.
- Project: `.agents/project.json`, `POLICIES.md`, `stack.env`, `critical.json`, `skills.lock` written by `project-init` and `project-agents.sh`.

## Commands

- Install/repair: `./install.sh [--profile p] [--org name url] [--with-integrations] [--with-cli-baselines]`; skills mirror: `./sync.sh`.
- Integrations (ADR 0016): plugins in `config/settings.base.json`, user-scope MCP in `config/mcp.user.json`, paste-preview patch in `config/patches/`, Obsidian docs via `scripts/export-obsidian.sh` (vault from `$OBSIDIAN_VAULT`).
- AGENTS.md first (ADR 0019): project-init writes `AGENTS.md` with the baseline block and no `CLAUDE.md` (`--claude-shim` optional); `scripts/gen-cli-baselines.sh` writes the baseline for agy/Copilot/OpenCode; `scout` skips the memory chain (`omitClaudeMd`).
- CAO mode (ADR 0020): the three hooks are quiet inside CAO panes (`CAO_TERMINAL_ID`); `critical-reasoning.sh` is once per session and silent in plan mode; lanes S/L in `config/CLAUDE.md`. Statusline caches are a contract for caolg (ADR 0021).
- Derived files: `scripts/gen-plugin.sh` and `scripts/gen-intents.sh` (`--check` in CI; `sync.sh` runs the latter).
- Intent router (ADR 0017): `## Shortcuts` in each integration skill + `config/intents.plugins.md` -> `config/intents.json` -> `config/hooks/intent-router.sh`; project checks in `config/hooks/session-start.sh` + `scripts/detect-stack.sh`; plugins per stack in `config/scopes.json`; workspace mode `devops/project-init/scripts/workspace.sh`.
- Tests: `scripts/test-packs.sh`, `scripts/test-orgs.sh`, `scripts/test-intents.sh`, `scripts/test-cli-baselines.sh`, `devops/project-init/scripts/test-manifest.sh`, `devops/project-init/scripts/test-docs-check.sh`, `devops/project-init/scripts/e2e.sh --stack <name|all>` (network).
- Guard: `scripts/leak-guard.sh --staged|--all`; hooks via `git config core.hooksPath .githooks`.

## Known issues

- `~/.agents/skills` is a symlink to the whole hub (Codex may list every skill, packs and org ones included); the profile calls a script through that path, so curating it needs its own change.
- `workspace.sh` still writes a `CLAUDE.md` with `@AGENTS.md` in workspace folders (a CLAUDE.md above a repo disables the native AGENTS.md read; revisit).
- Not verified: agy reading `~/.gemini/GEMINI.md` under CAO; whether SessionStart/UserPromptSubmit output reaches subagents.
- `kotlin.md` rule (layered reference) is not attached to `kotlin-spring`.
- Untested in a real session: `.claude` symlinked into a workspace folder (org mode) and plugin enable/disable at project scope.
- Generated Gradle Java projects with a Kotlin DSL build were not exercised in e2e.

Last validated: 2026-11-09
