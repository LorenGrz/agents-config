---
name: typescript-project-starter
description: Scaffold or upgrade small JavaScript and TypeScript learning projects with pnpm, strict scripts, README guidance, tests, linting, formatting, and verification. Use when creating a new JS/TS project, adding project structure, adding package.json scripts, moving from JavaScript to TypeScript, or standardizing a roadmap project.
---

# TypeScript Project Starter

Create minimal, reproducible JS/TS projects that match the roadmap and do not over-engineer.

## Defaults

- Use `pnpm` for package management.
- Keep tooling project-local: install TypeScript, Vitest, ESLint, Prettier, tsx, Playwright, Nest CLI, or Supabase CLI as dev dependencies only when the project needs them.
- Prefer `type: "module"` unless the project already uses CommonJS.
- Add scripts before adding complex tooling.

## Starter Scripts

Use only scripts that are supported by installed dependencies:

```json
{
  "scripts": {
    "dev": "tsx src/index.ts",
    "test": "vitest",
    "typecheck": "tsc --noEmit",
    "lint": "eslint .",
    "format": "prettier --write ."
  }
}
```

For plain JavaScript fundamentals, keep it lighter:

```json
{
  "type": "module",
  "scripts": {
    "test": "node --test"
  }
}
```

## Workflow

1. Inspect the existing project before choosing tooling.
2. Select the smallest setup that supports the task.
3. Add or update `README.md` with purpose, commands, stack, and next steps.
4. Add tests when there is reusable logic or expected behavior.
5. Run the relevant verification command and report failures clearly.

## Avoid

- Do not install global npm packages for project tooling.
- Do not create monorepos before there are multiple real packages/apps.
- Do not add React, NestJS, Next.js, or React Native unless the roadmap stage or user request explicitly calls for it.
