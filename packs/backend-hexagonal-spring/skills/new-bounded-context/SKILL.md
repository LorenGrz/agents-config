---
name: new-bounded-context
description: Workflow to add a new bounded context (module/aggregate) to a hexagonal Spring backend - folder structure, domain model with create()/restore(), commands, snapshots, repository port and adapter, mapper, REST controller, exceptions. Use for "nuevo bounded context", "nuevo dominio", "nuevo módulo", "crear el modelo de", "new bounded context", "new module", "new aggregate".
---

# New bounded context

## Objective

Add a new bounded context (module/aggregate) to a hexagonal Spring backend: structure, domain model, ports, services, persistence, REST and tests.

## Prerequisites

Read `hexagonal-architecture` first. Ask the user (never assume) for: the aggregate and its states, what it needs from other contexts, and the persistence/auth decisions already recorded in `docs/decisions/`.

## Workflow

### Structure

```
{base-package}/{bc}/
  domain/model/            Aggregate, Status enum, child entities / value objects
  domain/repository/       XRepository (port, no Spring)
  application/command/     CreateXCommand, UpdateXCommand (records)
  application/port/out/    XSnapshot, XLookup, <Dep>Snapshot, <Dep>Lookup
  application/             CreateXService, UpdateXService, QueryXService
  infrastructure/persistence/  entity/, repository/ (JPA repo + RepositoryAdapter), mapper/
  infrastructure/rest/     XController, dto/request, dto/response
```

### Steps

1. **Domain model**: private constructor; `create(...)` enforces invariants, `restore(...)` does not; mutating methods start with `ensureStatus`/`ensureEditable`; unmodifiable collections.
2. **Commands**: one immutable record per use case.
3. **Ports**: `XRepository` in domain; `XSnapshot` + `XLookup` (read-only) for other contexts; a snapshot + lookup per dependency on another context.
4. **Services**: one per use case; load, call the domain method, side effects via ports, save.
5. **Persistence**: JPA entity separate from the domain model, `MapStruct`-style or hand-written mapper, `RepositoryAdapter` implements the port and delegates mapping to the mapper.
6. **REST**: thin controller (authorize, bind a `@Valid` request DTO, call one service, map to a response DTO). Authorize with the project's authorization mechanism.
7. **Errors**: use the project's exception types, mapped to HTTP status in one `@RestControllerAdvice`: not found -> 404, business rule/conflict -> 409, invalid argument -> 400, bean validation -> 400 with a consistent body.
8. **Tests**: domain unit tests per rule, service tests with mocked ports, `@WebMvcTest` for the controller. Then run `pre-delivery-review`.

```java
public record CreateXCommand(UUID ownerId, String name) {}

public class X {
  private UUID id; private XStatus status; private String name;
  private X() {}
  public static X create(UUID id, String name) { X x = new X(); x.id = id; x.name = name; x.status = XStatus.DRAFT; return x; }
  public static X restore(UUID id, String name, XStatus status) { /* no invariants */ }
  public void activate() { ensureStatus(XStatus.DRAFT); this.status = XStatus.ACTIVE; }
}
```
