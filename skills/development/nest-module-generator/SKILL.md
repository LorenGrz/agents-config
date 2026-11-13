---
name: nest-module-generator
description: Use this skill when an agent must generate NestJS modules, controllers, and services with the Nest CLI while preserving clean architecture, domain-centered business logic, and strict separation between domain, application, infrastructure, and presentation layers.
paths:
  - "**/*.module.ts"
  - "**/*.controller.ts"
  - "**/*.service.ts"
  - "**/*.resolver.ts"
metadata:
  version: "0.1.0"
  owner: "platform-automation"
  framework: "nestjs"
  architecture:
    - clean architecture
    - domain-driven design
  tools:
    - nest
    - npx
    - npm
    - pnpm
  triggers:
    - nest module
    - nest controller
    - nest service
    - clean architecture
---

# Nest Module Generator

## Objective

Generate NestJS modules using CLI-supported conventions while keeping business behavior in the domain model and infrastructure concerns out of application logic.

## Workflow

1. Inspect `package.json`, existing `src/` modules, and naming conventions.
2. Generate the Nest module, controller, and service with the local CLI.
3. Move generated artifacts into the repository's established layer structure when needed.
4. Add interfaces or ports for repositories before adding infrastructure implementations.
5. Keep domain behavior framework-agnostic; domain files must not depend on Nest decorators.
6. Add tests near the layer being changed: domain tests for rules, use-case tests for orchestration, controller tests for API behavior, and repository/integration tests for persistence when needed.

## Rules

### CLI Selection

Prefer the project's local CLI:

```bash
npx nest generate module <feature>
npx nest generate controller <feature>
npx nest generate service <feature>
```

If the repository uses pnpm:

```bash
pnpm exec nest generate module <feature>
pnpm exec nest generate controller <feature>
pnpm exec nest generate service <feature>
```

Use the global `nest` command only when the project has no local executable and the environment already provides it. Do not hand-create Nest boilerplate when the CLI can generate it consistently.

### Architecture Rules

- Keep complex business rules inside domain objects, domain services, value objects, or use cases. Do not implement business validation exclusively with DTO decorators when the invariant belongs to the domain.
- Controllers translate HTTP input and output only: do not inject ORM repositories into them, call persistence adapters from them, return ORM entities, or bypass use cases to make controller code shorter.
- Application services orchestrate use cases and transactions, but do not become procedural domain models.
- Infrastructure adapters implement persistence, messaging, HTTP clients, and external integrations behind interfaces.
- Validate DTOs at the presentation/API boundary, then map them into application commands or domain-friendly input. DTOs must not leak into domain objects.
- Repository, migration, and transaction rules: `database-persistence-patterns` (same `nestjs` stack). Do not create a generic repository abstraction unless the project already uses that pattern.

## Reference

### Recommended Structure

For a feature named `<feature>`, use this shape unless the repository already has its own clean architecture layout (then follow that one; do not introduce a parallel style):

```text
src/<feature>/
  domain/
    entities/
    value-objects/
    services/
    repositories/
  application/
    use-cases/
    ports/
  infrastructure/
    persistence/
  presentation/
    controllers/
    dto/
  <feature>.module.ts
```
