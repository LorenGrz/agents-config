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

## CLI Selection

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

Use the global `nest` command only when the project has no local executable and the environment already provides it.

## Architecture Rules

- Keep complex business rules inside domain objects, domain services, value objects, or use cases.
- Do not put business decisions in repositories.
- Repositories persist and retrieve data; they do not decide domain behavior.
- Controllers translate HTTP input and output only.
- Application services orchestrate use cases and transactions, but do not become procedural domain models.
- Infrastructure adapters implement persistence, messaging, HTTP clients, and external integrations behind interfaces.
- DTOs must not leak into domain objects.
- Validate DTOs at the presentation/API boundary, then map them into application commands or domain-friendly input.
- Keep repository ports separate from ORM-specific implementations.

## Recommended Structure

For a feature named `<feature>`, prefer this shape when the project does not already define a stronger convention:

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

If the existing repository uses a different clean architecture layout, follow the existing layout instead of introducing a parallel style.

## Generation Workflow

1. Inspect `package.json`, existing `src/` modules, and naming conventions.
2. Generate the Nest module, controller, and service with the local CLI.
3. Move generated artifacts into the repository's established layer structure when needed.
4. Add interfaces or ports for repositories before adding infrastructure implementations.
5. Keep domain behavior framework-agnostic; domain files must not depend on Nest decorators.
6. Add tests near the layer being changed: domain tests for rules, use-case tests for orchestration, controller tests for API behavior, and repository/integration tests for persistence when needed.

## Guardrails

- Do not hand-create Nest boilerplate when the CLI can generate it consistently.
- Do not inject ORM repositories directly into controllers.
- Do not allow controllers to call persistence adapters directly.
- Do not implement business validation exclusively with DTO decorators when the invariant belongs to the domain.
- Do not create a generic repository abstraction unless the project already uses that pattern.
- Do not return ORM entities directly from controllers.
- Do not bypass use cases to make controller code shorter.
