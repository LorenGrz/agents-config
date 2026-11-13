---
name: code-review-safety
description: Use this skill when reviewing TypeScript full-stack changes for correctness, security, maintainability, architecture drift, missing tests, regressions, and unsafe implementation shortcuts.
metadata:
  version: "0.1.0"
  owner: "typescript-fullstack"
  stack:
    - typescript
    - nextjs
    - react
    - react-native
    - nestjs
  focus:
    - code review
    - safety
    - tests
    - architecture
  triggers:
    - review
    - code review
    - regression
    - missing tests
---

# Code Review Safety

## Objective

Review changes like a senior engineer: prioritize bugs, regressions, security risks, missing tests, and architecture violations before style comments.

## Workflow

1. Correctness and behavioral regressions.
2. Security and data exposure.
3. API contract compatibility.
4. Architecture and ownership boundaries.
5. Test coverage for changed behavior.
6. Accessibility and UX issues for frontend changes.
7. Maintainability, naming, and local consistency.

## Rules

- Ground each finding in a file and line when available.
- Explain impact and the concrete failure mode.
- Do not report speculative issues without a plausible path to failure.
- Do not focus on formatting if automated tools handle it.
- Identify missing tests when behavior changed without coverage.

### TypeScript Full-Stack Checks

Hard rule per line; the named skill has the full checks, if installed in the project.

- Types and auth: no bypass of typing, validation or server-side authorization (`typescript-code-quality`, `auth-security-basics`).
- Next.js: no secrets or server-only code in client paths (`nextjs-ssr-frontend`).
- React: no unnecessary effects or missing cleanup (`react-component-validator`); accessible controls.
- React Native: no secrets in plain async storage (`react-native-mobile`).
- NestJS: controller thinness, validation, use-case boundaries, repository misuse.
- API contracts: response stability, error shape consistency, client compatibility.

## Output

Lead with findings ordered by severity. If no issues are found, say so clearly and mention residual test risk.
