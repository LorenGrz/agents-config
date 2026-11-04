---
name: hexagonal-architecture-py
description: Layer rules and design guidance for hexagonal (ports and adapters) backends in Python - pure domain, use cases, Protocol ports, adapters, wiring. Use when deciding where logic goes or modelling a domain - "arquitectura hexagonal", "dónde va la lógica", "puertos y adaptadores", "cómo modelar", "where does this logic go", "ports and adapters", "domain model".
---

# Hexagonal architecture (Python)

The package layout comes from the architecture ADR (`docs/decisions/`). Layers inside `src/<package>/`:

| Layer | May import | Forbidden |
|---|---|---|
| `domain/` | stdlib only | frameworks, ORMs, HTTP clients, Pydantic |
| `application/` | `domain/` | ORMs, web frameworks, concrete adapters |
| `adapters/` (or `infrastructure/`) | `application/`, `domain/`, frameworks | business rules |

## Domain

- Business rules and invariants live in the entities, named in business language (`order.confirm()`, not `order.status = "confirmed"`).
- `@dataclass` (use `frozen=True` for value objects, `slots=True` when useful). Validate in `__post_init__` or a `create()` classmethod; keep a separate `restore()` for rebuilding from storage.
- Domain errors are plain exception classes (`NotFoundError`, `ConflictError`, `RuleViolation`), mapped to transport codes by the adapter layer only.

## Application

- One use case per class or function; it orchestrates: load aggregate through a port, call the domain method, call side-effect ports, save, return. No rules.
- Ports are `typing.Protocol` classes in `application/ports.py` (repository, lookup, gateway). Use cases receive them through the constructor.

## Adapters and wiring

- Inbound adapters (HTTP, CLI, queue handlers) validate raw input at the boundary (Pydantic or similar), build a command, call one use case, map the result to a response.
- Outbound adapters implement the ports (SQLAlchemy repository, HTTP gateway) and map between ORM models and domain entities.
- Compose everything in one place (the app factory or `main`), never inside use cases or adapters.

## Tests

Domain: plain unit tests per rule. Use cases: in-memory fakes of the ports (a dict-backed repository is fine in Python) or mocks. Adapters: integration tests against the real thing.

## Anti-patterns

| Anti-pattern | Instead |
|---|---|
| ORM models used as domain entities | Separate entities plus a mapper in the adapter |
| Pydantic models inside `domain/` | Dataclasses; Pydantic stays at the edges |
| Use case importing a concrete adapter | Depend on the Protocol, inject in the composition root |
| Business rule in a route handler | Move it into the entity or the use case |
| Module-level singletons for connections | Construct in the composition root and pass down |
