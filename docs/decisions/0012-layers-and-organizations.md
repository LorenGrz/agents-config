# 0012 — Layers: base, organizations, projects

Status: accepted (2026-11-04)

## Context
One person works for several companies or clients. Company rules, skills and domain knowledge were mixed with personal practices, and this repo is public.

## Decision
Three layers: the public **base** (this repo, with `config/baseline.md` as the floor no one can lower), **organizations** (`organizations/<name>/`, each its own private git repo, cloned but ignored here), and the **project** (`.agents/project.json`, `POLICIES.md`, `skills.lock`). An org overrides conventions and adds skills, commands and questions through `org.json` (contract in `organizations/README.md`); it cannot weaken the baseline. `scripts/orgs.sh` manages them. Nested ignored repos, not submodules: a submodule would record the private URL and SHA in this public repo. The per-org identifying terms go to a local blocklist (ADR 0015).

## Consequences
- Pushes are per repo; the public repo never sees org commits. Versions are independent, frozen per project in `.agents/skills.lock`; updating is explicit.
- Recognition by GitHub owner via the local, untracked `organizations/INDEX.md` (imported by `install.sh`); `project-init` proposes the org and always asks.
- A policy that replaces a base practice is recorded as an ADR in the project.
- `meta/org-creator` is the entry point for a new company or client.
