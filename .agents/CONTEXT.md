# agents-config — current state

## Purpose
Portable agent config + skill library for Claude Code, Codex, Cursor and Antigravity.
Generic instructions in `config/`, personal content in `config/profiles/<name>.md`,
on-demand skills in category dirs. Public repo: never commit secrets.

## Layout
- `development/ devops/ quality/ security/ productivity/ meta/ aws/` — skills (`<category>/<skill>/SKILL.md`); `aws/` came in via `git subtree` (ADR 0001).
- `apexlang`, `omarchy`, `diagnose-crash` — external symlinks (gitignored / ship with Omarchy).
- `config/` — `AGENTS.md`, `CLAUDE.md` (kept <=60 lines), `profiles/`, `settings.base.json`, `agents/` (scout/worker/reasoner), `rules/`, `hooks/` (*.sh), `rulesync/`, `scopes.json` (global vs per-stack skills/rules/MCP).
- `hooks/hooks.json` — generic plugin hooks (6 of the `config/hooks` scripts).
- `.claude-plugin/` — `plugin.json` + `marketplace.json`.
- `docs/decisions/` — ADRs 0001-0008 (index in its README).
- `evals/` — skill trigger evals (`<case>/prompt.md` + `graders/*.md`).
- `scripts/eval-skills.sh` — runs the evals; `install.sh`, `sync.sh` at root.

## How it is installed
- `install.sh` generates `~/.claude/CLAUDE.md` (@-imports config AGENTS.md + profile + CLAUDE.md) and `~/.codex/AGENTS.md` (concatenated).
- Symlinks `config/{hooks,agents}` and the global `config/rules/*.md` (per file) into `~/.claude/`; stack skills/rules/MCP go per project via `scripts/project-agents.sh`.
- Runs `sync.sh`: mirrors skills flat into `~/.claude/skills`.
- Merges `config/settings.base.json` into `~/.claude/settings.json` (backup first; idempotent).
- Alternative: plugin marketplace (skills + agents + generic hooks only).

## Git flow
Default branch `master`. Branch `feat|fix|refactor/<slug>`, verify, commit, push, merge `--no-ff`,
push, then `git -C ~/projects/claude-skills pull` (showcase mirror).

## Verification
- `bash -n install.sh sync.sh scripts/*.sh config/hooks/*.sh`
- `./install.sh --dry-run`
- `./scripts/eval-skills.sh` (paid; `--case 'trigger-*'`, `EVAL_RUNS=3`)

## Current state (2026-10-23)
- Renamed to agents-config (ADR 0007).
- ADRs 0006 (always delegate), 0007 (rename), 0008 (SessionStart hook), 0009 (opusplan + critical-reasoning hook) landed. Default model is `opusplan`.
- Branch `feat/skill-evals-and-docs`: trigger evals, eval script, worktree rule for parallel workers, doc fixes.

## Known issues
- Eval suite is not run in CI (costs money per run).
- `session-start.sh` stale/missing-CONTEXT branches are untested on a real repo.
