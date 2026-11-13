# agents-config - Repository Context

Public hub of personal agent config, skills and project scaffolding. Detail: `README.md`, ADRs in `docs/decisions/`.

## Layers

- Base (this repo): `config/` (AGENTS.md, CLAUDE.md, baseline.md, profiles, hooks, rules, agents), skills by category under `skills/`, `packs/`, `skills/devops/project-init`.
- Organizations: `organizations/<name>/`, each a private repo cloned here and ignored by git (`scripts/orgs.sh`). Never commit them or their terms here.
- Project: `.agents/project.json`, `POLICIES.md`, `stack.env`, `critical.json`, `skills.lock` written by `project-init` and `project-agents.sh`.

## Commands

- Install/repair: `./install.sh [--profile p] [--org name url] [--with-integrations] [--with-cli-baselines]`; skills mirror: `./sync.sh`.
- Integrations (ADR 0016): plugins in `config/settings.base.json`, user-scope MCP in `config/mcp.user.json`, paste-preview patch in `config/patches/`, Obsidian docs via `scripts/export-obsidian.sh` (vault from `$OBSIDIAN_VAULT`).
- AGENTS.md first (ADR 0019): project-init writes `AGENTS.md` with the baseline block and no `CLAUDE.md` (`--claude-shim` optional); `scripts/gen-cli-baselines.sh` writes the baseline for agy/Copilot/OpenCode; `scout` skips the memory chain (`omitClaudeMd`).
- CAO mode (ADR 0020): the three hooks are quiet inside CAO panes (`CAO_TERMINAL_ID`), except `intent-router.sh` still routes `mcp__*` tools; `critical-reasoning.sh` is once per session and silent in plan mode. Statusline caches are a contract for caolg (ADR 0021).
- Workflow lanes (ADR 0022, 0025): punctual change direct; otherwise one question Continuar / Plan S / Plan L, always in that order (`config/AGENTS.md`, Claude mechanics in `config/CLAUDE.md`); every plan starts with a `mattpocock-skills:grilling` interview. `config/hooks/lane-guard.sh` enforces both. PonyTail (ADR 0023) is installed but off (`PONYTAIL_DEFAULT_MODE=off`, ledger and band off); Plan S loads `ponytail:ponytail`. `install.sh` merges `env` and `pluginConfigs` from `settings.base.json`.
- Main session: Opus at high effort (ADR 0024, supersedes the medium of 0018). `CLAUDE_CODE_FORCE_TERMINAL_IMAGES=1` in settings `env` so caolg panes (tmux) show pasted-image thumbnails; CAO unsets `CLAUDE*` shell vars, so it must live in settings.
- Derived files: `scripts/gen-plugin.sh` and `scripts/gen-intents.sh` (`--check` in CI; `sync.sh` runs the latter).
- Layout and templates (ADR 0026): skills in `skills/<category>/<skill>/` (+ `integrations/`, gitignored `external/`); one skill per tool (git and GitHub = `github-usage`, `git-workflow` is gone); fixed template per markdown type, enforced by `scripts/lint-docs.sh --strict` in CI. Org repos are self-sufficient (plugin + `install.sh`) and their `replaces` map hub integration skills to the org's; `intent-router.sh` names the org skill inside an org repo. An org can split into products (ADR 0027): `products` in `org.json`, one folder per product, `project-agents.sh --product` or detection by remote.
- Intent router (ADR 0017): `## Shortcuts` in each integration skill + `config/intents.plugins.md` -> `config/intents.json` -> `config/hooks/intent-router.sh`; project checks in `config/hooks/session-start.sh` + `scripts/detect-stack.sh`; plugins per stack in `config/scopes.json`; workspace mode `skills/devops/project-init/scripts/workspace.sh`.
- Tests: `scripts/test-lane-guard.sh`, `scripts/test-leak-guard.sh`, `scripts/test-packs.sh`, `scripts/test-orgs.sh`, `scripts/test-intents.sh`, `scripts/test-cli-baselines.sh`, `skills/devops/project-init/scripts/test-manifest.sh`, `skills/devops/project-init/scripts/test-docs-check.sh`, `skills/devops/project-init/scripts/e2e.sh --stack <name|all>` (network).
- Guard: `scripts/leak-guard.sh --staged|--all|--log`; `--log` only counts added patch lines. Hooks via `git config core.hooksPath .githooks` (enabled in Loren's clone since 2026-11-13).

## Known issues

- `~/.agents/skills` is a symlink to `<hub>/skills` (install.sh links it; skipped when the hub itself was cloned there). The profile calls `~/.agents/skills/meta/roadmap-coach/scripts/update-stage.sh` through that path.
- `workspace.sh` still writes a `CLAUDE.md` with `@AGENTS.md` in workspace folders (a CLAUDE.md above a repo disables the native AGENTS.md read; revisit).
- Not verified: agy reading `~/.gemini/GEMINI.md` under CAO; whether SessionStart/UserPromptSubmit output reaches subagents.
- `kotlin.md` rule (layered reference) is not attached to `kotlin-spring`.
- Untested in a real session: `.claude` symlinked into a workspace folder (org mode) and plugin enable/disable at project scope.
- Generated Gradle Java projects with a Kotlin DSL build were not exercised in e2e.

Last validated: 2026-11-13
