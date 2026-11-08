# agents-config - Repository Context

Public hub of personal agent config, skills and project scaffolding. Detail: `README.md`, ADRs in `docs/decisions/`.

## Layers

- Base (this repo): `config/` (AGENTS.md, CLAUDE.md, baseline.md, profiles, hooks, rules, agents), skills by category, `packs/`, `devops/project-init`.
- Organizations: `organizations/<name>/`, each a private repo cloned here and ignored by git (`scripts/orgs.sh`). Never commit them or their terms here.
- Project: `.agents/project.json`, `POLICIES.md`, `stack.env`, `critical.json`, `skills.lock` written by `project-init` and `project-agents.sh`.

## Commands

- Install/repair: `./install.sh [--profile p] [--org name url] [--with-integrations]`; skills mirror: `./sync.sh`.
- Integrations (ADR 0016): plugins in `config/settings.base.json`, user-scope MCP in `config/mcp.user.json`, paste-preview patch in `config/patches/`, Obsidian docs via `scripts/export-obsidian.sh` (vault from `$OBSIDIAN_VAULT`).
- Derived files: `scripts/gen-plugin.sh` (`--check` in pre-commit/CI).
- Tests: `scripts/test-packs.sh`, `scripts/test-orgs.sh`, `devops/project-init/scripts/test-manifest.sh`, `devops/project-init/scripts/test-docs-check.sh`, `devops/project-init/scripts/e2e.sh --stack <name|all>` (network).
- Guard: `scripts/leak-guard.sh --staged|--all`; hooks via `git config core.hooksPath .githooks`.

## Known issues

- `kotlin.md` rule (layered reference) is not attached to `kotlin-spring`.
- Generated Gradle Java projects with a Kotlin DSL build were not exercised in e2e.

Last validated: 2026-11-08
