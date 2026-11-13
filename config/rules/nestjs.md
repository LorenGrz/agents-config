---
paths:
  - "**/*.module.ts"
  - "**/*.controller.ts"
  - "**/*.service.ts"
  - "**/*.resolver.ts"
---

# NestJS

## Layers and boundaries

- Keep layers separate: domain (entities, business rules) ← application (use cases) ← infrastructure (DB, HTTP clients) ← presentation (controllers, DTOs).
- Controllers stay thin: validate input, call a use case, map the result. No business logic.
- Business logic lives in the domain/application layer, not in services that also touch the ORM.
- Validate request bodies with DTOs + class-validator at the edge.
- Inject dependencies through the constructor; no service locators.

For generating modules, use the `nest-module-generator` skill. For persistence, `database-persistence-patterns`.
