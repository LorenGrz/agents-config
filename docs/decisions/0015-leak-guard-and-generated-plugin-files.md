# 0015 — Leak guard and generated plugin files

Status: accepted (2026-11-04)

## Context
Organization data must not reach this public repo, and `plugin.json`/`hooks.json` had drifted from their sources (project-scoped skills exported globally).

## Decision
- `scripts/leak-guard.sh` fails on tracked files under `organizations/` (except README and `_template`), on terms from a **local** blocklist (`~/.config/agents-config/blocklist`, built by `orgs.sh` from each `org.json` name, terms and GitHub owners; a `LEAK_BLOCKLIST` secret in CI) and on obvious secrets. It checks file names, content (binaries included), renames and commit messages: hooks `pre-commit` (staged), `commit-msg`, `pre-push` (tree plus the commits being pushed) and CI (tree plus the pushed range). It never prints a term: a path that contains one is redacted, and in CI every path is.
- `scripts/gen-plugin.sh` derives `plugin.json` skills (everything not project-scoped) and `hooks/hooks.json` (from `settings.base.json`, minus machine-specific hooks); `--check` runs in pre-commit and CI.

## Consequences
The blocklist protects only what is listed (renamed or abbreviated names pass; already-pushed history is out of reach); `org-creator` asks for the terms. Without a blocklist the guard warns locally and fails in CI. The pre-commit hook needs `git config core.hooksPath .githooks`.
