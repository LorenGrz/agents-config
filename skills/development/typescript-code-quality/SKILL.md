---
name: typescript-code-quality
description: Use this skill when writing or reviewing TypeScript across Next.js, React, React Native, and NestJS to enforce strict typing, safe error modeling, validation boundaries, and maintainable production code.
metadata:
  version: "0.1.0"
  owner: "typescript-fullstack"
  stack:
    - typescript
  focus:
    - type safety
    - maintainability
    - validation
    - errors
  triggers:
    - TypeScript
    - type safety
    - strict mode
    - DTO
    - validation
---

# TypeScript Code Quality

## Objective

Use TypeScript to prevent invalid states, make contracts explicit, and keep application code refactorable.

## Type Rules

- Prefer precise domain types over loose objects.
- Avoid `any`; use `unknown` at untrusted boundaries and narrow it.
- Avoid non-null assertions unless the invariant is obvious and already enforced.
- Use discriminated unions for state machines, async states, and result variants.
- Keep DTOs, API response types, and domain types separate when they represent different concerns.
- Use `readonly` and immutable data shapes where mutation is not required.

## Boundary Validation

- Validate external input at boundaries: HTTP requests, environment variables, storage, files, and third-party APIs.
- Convert validated input into domain-friendly types before it enters business logic.
- Do not trust generated or shared types as runtime validation.

## Error Modeling

- Prefer typed result objects or domain-specific errors where callers need to branch.
- Preserve cause/context when wrapping errors.
- Do not swallow errors silently.
- Do not expose internal errors or stack traces through public APIs.

## Validation

- Run typecheck and tests after type-heavy changes.
- Treat type errors as design feedback, not noise to bypass.
