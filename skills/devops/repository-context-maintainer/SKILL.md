---
name: repository-context-maintainer
description: Use this skill when entering a repository, preserving project-specific context, creating or updating a .agents/CONTEXT.md file, or deciding whether local repository context is missing, stale, or inaccurate.
metadata:
  version: "0.1.0"
  owner: "typescript-fullstack"
  focus:
    - repository context
    - onboarding
    - agent memory
    - project documentation
  context_file: ".agents/CONTEXT.md"
  triggers:
    - repository context
    - project context
    - CONTEXT.md
    - onboarding
    - first time in repository
---

# Repository Context Maintainer

## Objective

Keep one concise, repo-local context file that helps agents understand the project before editing code. The default file is `.agents/CONTEXT.md`.

## Entry Workflow

When starting work in a repository:

1. Check whether `.agents/CONTEXT.md` exists.
2. If it exists, read it before making architecture or implementation decisions.
3. Verify that it still matches the repository by inspecting current manifests, source layout, scripts, and recent conventions.
4. If it is missing or stale, create or update it by analyzing the actual project.
5. Do not treat the context file as more authoritative than current code.

## Staleness Signals

Refresh `.agents/CONTEXT.md` when any of these are true:

- The file is missing.
- The package manager, framework, or primary scripts changed.
- Source directories no longer match the documented architecture.
- The documented test/build commands fail because the commands no longer exist.
- New apps, packages, modules, or services were added.
- The user says the context is outdated.

## Context Discovery

Use non-destructive inspection commands before writing:

```bash
pwd
find . -maxdepth 3 -type f \( -name package.json -o -name pnpm-lock.yaml -o -name package-lock.json -o -name tsconfig.json -o -name nest-cli.json -o -name next.config.* -o -name app.json -o -name app.config.* -o -name docker-compose.yml -o -name compose.yaml \)
find . -maxdepth 3 -type d \( -name src -o -name app -o -name pages -o -name packages -o -name apps \)
```

Prefer `rg` for targeted searches:

```bash
rg -n "\"scripts\"|next|nestjs|react-native|expo|typeorm|prisma|vitest|jest|playwright" package.json .
```

## Required File Shape

Create or update `.agents/CONTEXT.md` with these sections:

```markdown
# Repository Context

## Purpose

## Stack

## Project Structure

## Package Manager And Scripts

## Architecture Rules

## Testing And Verification

## Local Development Services

## Agent Notes

## Last Reviewed
```

## Writing Rules

- Keep the file concise and factual.
- Prefer bullets over long explanations.
- Record only information discovered from the repository or explicitly provided by the user.
- Mark uncertainty as `Unknown` instead of guessing.
- Include exact commands for install, dev, test, lint, typecheck, build, and Docker only when they exist.
- Update `Last Reviewed` with the current date and a short note about what was inspected.
- Do not include secrets, credentials, tokens, private keys, or machine-specific absolute paths.

## Agent Behavior

- Before editing code, use this context file to choose relevant skills.
- If the file is stale, update it as a small preparatory change before larger implementation work.
- If a task is urgent and context refresh is not necessary, read the file and continue without rewriting it.
- If multiple repositories exist, each repository owns its own `.agents/CONTEXT.md`.
