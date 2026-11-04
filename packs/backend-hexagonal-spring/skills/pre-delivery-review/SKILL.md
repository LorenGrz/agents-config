---
name: pre-delivery-review
description: Silent architecture checklist to run before handing over any backend code on a hexagonal Spring project - business logic in the wrong layer, redundant validation, primitives instead of value objects, wrong exception type, over-engineering. Use before delivering code and when asked "revisá esto", "está bien esto", "cumple la arquitectura", "review this", "is this correct". Auto-triggers on every code generation or review in such a project.
---

# Pre-delivery review

Run this mentally before showing code. Fix what fails, then deliver.

- **Controllers**: only parse -> one service call -> map to DTO. No state `if/else`, no repository calls, no multi-service orchestration, no rules.
- **Services**: only orchestrate. No re-validation of what records or `@Valid` DTOs guarantee (`requireNonNull` on a record, blank checks already on the DTO). No direct persistence, no calls to other services, no business rules.
- **Domain**: mutators check preconditions first; collections unmodifiable; `create()` enforces, `restore()` does not; no framework annotations; no public setters (business-named methods).
- **Persistence**: adapters only persist; mapping lives in the mapper; paginated collections with children use two steps (ids first, then fetch join).
- **Value objects**: no raw `BigDecimal`/`String` where the project has a value object or enum; validate in its constructor.
- **Exceptions**: not found -> not-found exception (404); rule violated -> business exception (409); invalid state transition in the model -> illegal state; invalid argument -> illegal argument (400).
- **KISS**: no premature abstractions (extract at 3+ similar uses), no single-implementation interfaces, no pattern where a method does, no handling of impossible errors, no flags or shims "just in case", no one-line delegating helpers.
- **General**: no commented-out code or TODOs, no needless null checks, no unused imports, comments explain WHY only.
