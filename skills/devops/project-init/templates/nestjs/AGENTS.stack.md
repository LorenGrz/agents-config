## NestJS conventions

Clean architecture layers, reviewed against `nest-module-generator`; type-safety rules enforced by `eslint.config.mjs`:

- Layers run one direction: domain (entities, business rules) <- application (use cases) <- infrastructure (DB, HTTP clients) <- presentation (controllers, DTOs).
- Controllers stay thin: validate input, call a use case/service, map the result. No business logic in controllers; never inject an ORM repository directly into a controller.
- Business logic lives in the domain/application layer, not in a service that also talks to the ORM directly; repositories persist/retrieve, they don't decide behavior.
- Validate request bodies with DTOs + `class-validator` at the edge, then map into domain-friendly input. DTOs never leak into domain objects; domain entities never leak out through a controller response - map through a DTO.
- A `@Catch`/exception-filter layer maps domain errors to consistent HTTP status codes; never let internals or stack traces reach the client.
- Inject dependencies through the constructor; no service locators.
- Migrations for schema changes; keep transaction boundaries in application services, not controllers. Deeper: `database-persistence-patterns`.

Tests: match the scaffold's runner (Vitest by default in current `nest new`, Jest in older projects); colocated as `*.spec.ts`, one per use case/service.
