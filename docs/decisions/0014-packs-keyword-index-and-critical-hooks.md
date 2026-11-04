# 0014 — Packs, keyword index and critical hooks

Status: accepted (2026-11-04)

## Context
Skills triggered only by their `description`, which is probabilistic, and stack skills ignored the chosen architecture.

## Decision
- **Packs** (`packs/<name>/`: `pack.json`, `skills/`, `commands/`) bundle skills and slash commands by architecture. `project-agents.sh` installs the `always` packs plus those whose `when` matches the manifest (stack AND decisions), then an org on top (`--org`).
- **Index, not enforcement**: a keyword table in the project's `AGENTS.md` (14 rows max), bilingual triggers in each `description`. Detail is read on demand, so context stays small.
- **Hooks only at critical points**: `.agents/critical.json` (keyword or path -> skill) is read by `config/hooks/critical-reasoning.sh`, which hints the skill (never blocks) and combines with the existing `reasoner` nudge.
- Model routing moved out of the base into the profile; the base names roles (scout, reasoner, worker) and says to recommend subagents and ask when planning.

## Consequences
Packs that only list `when.stacks` (frontend-ui, spring-testing, python-testing) also install without a manifest. `react-scalable-frontend` was removed (its rules live in `ui-builder`, `ui-review` and `feature-architecture`); `react-component-validator` stays because the `useEffect` doctrine exists nowhere else. Skill content is written from scratch (inspired by real projects, no domain). Org skills replace pack skills through `replaces`, and pack commands are rewritten to point at the replacement.
