---
name: codex-workflows
description: Example personal workflow-adapter skill (Loren's own setup, kept as a reference pattern). Reuses an existing Codex/local agent setup from Claude Code. Use when work involves existing Codex skills, migration from Codex to Claude, or other skill roots listed in your profile.
---

# Codex Workflows Adapter

## Objective

Adapts Claude Code to an existing Codex setup without duplicating stale instructions. This
skill is Loren's own example, not a generic tool — if you're adapting it for your own
setup, copy it, point it at your own skill roots, and list them in your profile
(`config/profiles/<your-name>.md`) instead of hardcoding them here.

## Workflow

Identify the task category, then read only the relevant source skill files before acting.

Skill roots: this hub's `skills/` folder (`~/.agents/skills`, linked by `install.sh`) plus any
extra roots listed under "Codex workflow adapter" in your profile
(`config/profiles/<your-name>.md`) — e.g. `~/.codex/skills` or an OS-specific skill path.

### Routing

Skills in this hub:

- New JS/TS project or standard scripts: `typescript-project-starter`.
- Roadmap planning or learning project scope: `roadmap-coach`.
- React UI build/review: `ui-builder` / `ui-review` (frontend-ui pack).
- React component lifecycle review: `react-component-validator`.
- TypeScript quality: `typescript-code-quality`.
- API contracts: `api-contract-design`.
- Auth/security implementation: `auth-security-basics`.
- NestJS module generation: `nest-module-generator`.
- Persistence/database work: `database-persistence-patterns`.
- Docker-backed local environment: `run-docker-environment`.
- Test-suite execution and fix loop: `execute-test-suite`.
- Repository context maintenance: `repository-context-maintainer`.

In your profile's extra skill roots: security review by explicit request; desktop/OS config, PDFs,
browser automation.

## Rules

- Load skills progressively. Do not paste every skill into context.
- Prefer local project scripts and local dependencies.
- Preserve user changes. Do not revert unrelated files.
- For desktop/OS config, test first and ask before pushing to the settings repo named in
  your profile.
- For roadmap work, keep the next step small and aligned with the sequence in your profile
  or the `roadmap-coach` skill.
- If your profile names a roadmap repo, read, when relevant: `<roadmap-repo>/README.md`,
  `<roadmap-repo>/.agents/CONTEXT.md`, and `pnpm-workspace.yaml` if package installation or
  workspace behavior is involved. `node_modules/` must stay untracked.
