---
name: frontend-ports-adapters
description: Hexagonal frontend architecture - pure domain, use cases over ports (API, storage, clock), adapters, UI as an inbound adapter, composition root, tests with fake adapters. Use for "nueva feature", "puertos y adaptadores", "dónde va la lógica", "new feature", "ports and adapters", "where does this logic go".
---

# Hexagonal frontend

The structure is decided in the architecture ADR (`docs/decisions/`). Typical shape per feature:

```
src/features/<feature>/
  domain/        pure TypeScript: types, rules, value objects; no React, no fetch
  application/   use cases (plain functions or classes) and ports (interfaces)
  adapters/      http/ (implements the API port), storage/, mappers
  ui/            components and hooks: inbound adapter that calls use cases
  index.ts       public contract of the feature
src/app/         composition root: builds adapters, wires them to use cases, provides them to the UI (context)
```

## Rules

- `domain/` imports nothing from React, the router or the network. Business rules (calculations, state machines, validation that is a rule) live here and are unit-tested as plain functions.
- `application/` defines ports (`OrderApi`, `Clock`, `Storage`) and use cases that take ports as arguments. No framework, no JSX.
- `adapters/` implement ports (HTTP client, local storage) and map transport shapes to domain types. Parse and validate external data here (schema validation at the boundary).
- `ui/` renders and calls use cases through hooks; data-fetching libraries wrap use cases rather than replacing them. Components do not call `fetch` or know URLs.
- Dependencies point inward: ui -> application -> domain; adapters -> application/domain. The composition root is the only place that knows concrete adapters.
- Cross-feature access only through a feature's barrel.

## Tests

Domain: plain unit tests. Use cases: fake adapters (in-memory implementations of the ports). Adapters: tests against recorded or mocked HTTP. UI: component tests with fake adapters provided through the context, not mocked modules.
