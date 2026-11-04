---
name: feature-module
description: Modular monolith by feature on Spring - one package per business capability with a small public API, hidden internals, and events or facades between modules. Use for "nuevo módulo", "nueva feature", "límites entre módulos", "cómo se comunican los módulos", "new module", "module boundaries", "cross-module call". Auto-triggers when a module is added or modules start talking to each other.
---

# Feature module (modular monolith)

The structure is decided in the architecture ADR (`docs/decisions/`); this skill is the discipline inside it. One package per business capability: `{base-package}.{module}`.

## Shape

```
{module}/
  {Module}Api.java           public facade or interface other modules may call (the only public entry)
  {Module}Events.java        public event records this module publishes
  internal/                  everything else, package-private: controller, service, repository, entities, mappers
```

## Rules

- Other modules touch only the public API and the published events, never `internal/`, never another module's repository or entities.
- Pass data across modules as immutable records, not as another module's entity.
- Prefer events for "something happened" (notify, react later) and a facade call for "I need an answer now". No cyclic module dependencies: if two modules need each other, extract a third or turn one direction into an event.
- Each module owns its tables; no cross-module joins or foreign keys. If data is needed elsewhere, expose a query on the API.
- Enforce the boundaries with a test (Spring Modulith `ApplicationModules.verify()` or ArchUnit), not with convention alone.
- Layering inside a module stays simple (controller -> service -> repository). Add ports and adapters only where a module talks to something external.

## Adding a module

1. Ask the user what the module owns and which other modules it must talk to.
2. Create the package with `internal/` and the public API; start with the smallest API.
3. Put its REST controller, service, repository and migration inside the module.
4. Publish events instead of calling a module you would otherwise depend on cyclically.
5. Add or extend the boundary test, then run the project's checks.
