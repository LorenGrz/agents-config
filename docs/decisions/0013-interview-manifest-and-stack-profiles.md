# 0013 — project-init interview, manifest and stack profiles

Status: accepted (2026-11-04)

## Context
`project-init` assumed TypeScript, asked nothing about architecture and could not scaffold Java, Kotlin or Python.

## Decision
- **Interview first** (`devops/project-init/references/interview.md`): org, stack, backend and frontend style, data, auth, testing, deploy, SDD. Critical answers are never defaulted; "no sé" becomes `pending`.
- **Manifest** `.agents/project.json` (schema v1) holds the answers; `manifest.sh` validates it (required keys), writes one ADR per decision and lists pending ones in `.agents/CONTEXT.md`. `init.sh --manifest` consumes it.
- **Stack profiles**: `templates/<stack>/stack.env` (commands, lint text, allowed commands), optional `@maven`/`@gradle` variants detected from the generated project, per-stack `setup.sh` (Spotless, ruff/mypy/pytest). Stack files win over `templates/common`, which uses placeholders; non-node stacks write `.agents/stack.env` for `gh-flow.sh pr` and `verify-ci.sh`.
- The `sdd` answer (`required|light|off`, validated) rewrites step 2 of the generated `AGENTS.md` (`references/sdd/`); `required` keeps the template text. The generated `docs-check.sh` reads dependency changes in package.json, pom.xml, Gradle files and catalog, pyproject.toml and requirements*.txt.
- New stacks: `python`, `java-spring` (Maven and Gradle), `kotlin-spring` (Gradle). `kotlin.md` is not attached to `kotlin-spring`: it prescribes a layered architecture that the interview decides.

## Consequences
For the TS stacks the generated files are unchanged except `scripts/gh-flow.sh` (a `stack.env` branch) and what packs add on purpose: the keyword table in `AGENTS.md`, the `workflow` commands and the `run-app` skill (checked by diffing against a baseline). Every stack has an e2e (`e2e.sh`); `test-manifest.sh` covers the manifest offline.
