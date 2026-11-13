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

## Workflow

1. Identify all clients affected by the contract.
2. Add new fields in a backward-compatible way when possible.
3. Keep deprecated fields until consumers are migrated.
4. Update tests for both success and failure responses.

## Rules

### Contract Rules

- Define request and response DTOs at the API boundary; validate requests on the server before application or domain logic.
- Do not break a public API shape without an explicit migration.
- Use one error shape: machine-readable code plus human-readable message.
- Do not leak persistence models, ORM entities, or domain internals as API responses.
- Keep date, money, enum, pagination, and optional-field semantics explicit.

### Client Integration

- Use the project's central API client or fetch wrapper when it has one, and normalize API errors there, before they reach UI components.
- Model loading, empty, forbidden, not found, validation error, and unexpected error states separately when the UX needs them.
- Reuse the shared package or generated client for contract types; do not hand-copy them across apps.

## Verification

- Run backend tests for DTO validation and controller behavior.
- Run client tests or typecheck for affected API consumers.
