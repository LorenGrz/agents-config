---
name: hexagonal-architecture
description: Layer rules and design guidance for hexagonal (ports and adapters) + DDD backends on Spring (Java/Kotlin). Use when deciding where logic goes, modelling a domain, naming ports or refactoring layers - "arquitectura hexagonal", "dónde va la lógica", "qué capa", "cómo modelar", "invariantes", "puertos y adaptadores", "SOLID", "where does this logic go", "domain model", "ports and adapters". Auto-triggers when design, structure or layering comes up.
---

# Hexagonal architecture (Spring)

The package layout comes from the project's architecture ADR (`docs/decisions/`); this skill is the layer discipline. Below, `{bc}` is a bounded context.

## Layers

| Layer | May depend on | Forbidden |
|---|---|---|
| `domain/` | plain Java/Kotlin only | Spring, JPA, Jackson, any framework |
| `application/` | `domain/` | JPA, SQL, web types (only `@Component`/`@Transactional` allowed) |
| `infrastructure/` | `application/`, `domain/`, Spring, JPA | business rules |

## Domain model

- All business rules and invariants live in the model, not in services or controllers.
- Rich model: behavior on the object, named in business language (`formalize()`, `cancel()`), never `setStatus()`. No public setters.
- Every mutating method checks its precondition first (`ensureStatus`, `ensureEditable`).
- Two factories: `create()` enforces invariants; `restore()` rebuilds from storage and tests without re-checking.
- Expose collections unmodifiable. Use value objects (`Money`, `Quantity`, enums) instead of raw `BigDecimal`/`String` for validated concepts; validate in the constructor.
- No framework annotations in the model.

## Application services

One class per use case; it only orchestrates: load aggregate, call the domain method, trigger side effects through a port, save, return. No rules, no input re-validation that records/DTOs already guarantee, no calls to other application services (use a shared port or a domain event).

## Ports

```
domain/repository/XRepository          read+write of the aggregate
application/port/out/XLookup           read-only, for other contexts
application/port/out/XGateway          side effects (email, payments, messaging)
application/port/out/XSnapshot         immutable record crossing a context boundary
application/port/in/CreateXUseCase     only when needed for tests or several implementations
```

Other contexts depend on `XLookup`/`XSnapshot`, never on another context's repository or entities.

## SOLID here

SRP: one service per use case, one domain method per business operation. OCP: new behavior = new command + service, not edits to existing ones. ISP: read-only `Lookup` split from `Repository`. DIP: `application/` depends on ports; `infrastructure/` implements them.

## Anti-patterns

| Anti-pattern | Instead |
|---|---|
| Business logic in controllers or JPA entities | Controller translates HTTP; entity is persistence only |
| `@Transactional` in the domain model | Transactions are an application/infrastructure concern |
| A service calling another service | Shared port or domain event |
| `Optional` returned from the domain model | The service throws a not-found exception |
| Long `if/else` on state in a service | Push into the model (`ensureX()`, polymorphism) |
