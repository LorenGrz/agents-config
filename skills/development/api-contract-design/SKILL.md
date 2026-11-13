---
name: api-contract-design
description: Use this skill when designing or changing TypeScript API contracts between NestJS backends and Next.js, React, or React Native clients, including DTOs, validation, error shapes, and backward-compatible REST JSON changes.
metadata:
  version: "0.1.0"
  owner: "typescript-fullstack"
  stack:
    - typescript
    - nestjs
    - react
    - nextjs
    - react-native
  focus:
    - api contracts
    - dto
    - validation
    - compatibility
  triggers:
    - API contract
    - REST
    - DTO
    - request shape
    - response shape
---

# API Contract Design

## Objective

Design client/server contracts that are explicit, validated, and safe to evolve across web, mobile, and backend codebases.

## Contract Rules

- Define request and response DTOs at the API boundary.
- Validate incoming requests on the server before reaching application or domain logic.
- Keep public API shapes stable; avoid breaking existing clients without an explicit migration.
- Use consistent error responses with machine-readable codes and human-readable messages.
- Do not leak persistence models, ORM entities, or domain internals directly as API responses.
- Keep date, money, enum, pagination, and optional-field semantics explicit.

## Client Integration

- Centralize API clients or fetch wrappers when the project has that pattern.
- Normalize API errors before they reach UI components.
- Model loading, empty, forbidden, not found, validation error, and unexpected error states separately when the UX needs them.
- Avoid duplicating contract types manually across apps when a shared package or generated client already exists.

## Change Process

1. Identify all clients affected by the contract.
2. Add new fields in a backward-compatible way when possible.
3. Keep deprecated fields until consumers are migrated.
4. Update tests for both success and failure responses.

## Validation

- Run backend tests for DTO validation and controller behavior.
- Run client tests or typecheck for affected API consumers.
