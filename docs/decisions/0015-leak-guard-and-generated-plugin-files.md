# 0015 — Leak guard and generated plugin files

Status: accepted (2026-11-04)

## Context
Organization data must not reach this public repo, and `plugin.json`/`hooks.json` had drifted from their sources (project-scoped skills exported globally).

## Decision
- `scripts/leak-guard.sh` (git pre-commit and CI): fails on tracked files under `organizations/` (except README and `_template`), on terms from a **local** blocklist (`~/.config/agents-config/blocklist`, built by `orgs.sh` from each `org.json`; a `LEAK_BLOCKLIST` secret in CI) and on obvious secrets. It never prints the matched term.
- `scripts/gen-plugin.sh` derives `plugin.json` skills (everything not project-scoped) and `hooks/hooks.json` (from `settings.base.json`, minus machine-specific hooks); `--check` runs in pre-commit and CI.

## Consequences
The blocklist protects only what is listed; `org-creator` asks for the terms. The pre-commit hook needs `git config core.hooksPath .githooks`.
