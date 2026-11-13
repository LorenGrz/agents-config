---
name: new-use-case
description: Workflow to add a new use case or module to a hexagonal Python backend - entity, command, ports, use case, adapters, tests. Use for "nuevo caso de uso", "nuevo módulo", "crear el modelo de", "new use case", "new module", "new aggregate".
---

# New use case / module

## Objective

Add a new use case or module to a hexagonal Python backend: entity, command, ports, use case, adapters, tests.

## Workflow

Read `hexagonal-architecture-py` first. Ask the user (never assume) for the entity and its states, what it needs from other parts of the system, and the data and auth decisions in `docs/decisions/`.

```
src/<package>/<module>/
  domain/        entities.py, errors.py
  application/   commands.py, ports.py, use_cases.py
  adapters/      http.py (routes), repository.py (implements the port), mappers.py
tests/<module>/ test_entities.py, test_use_cases.py, test_http.py
```

### Steps

1. **Entity**: dataclass with `create()` enforcing invariants and `restore()` without; mutators check preconditions first and raise domain errors.
2. **Command**: a frozen dataclass per use case.
3. **Ports**: a `Protocol` for the repository and one per external dependency (lookup for reads from another module, gateway for side effects).
4. **Use case**: load, call the domain method, side effects through ports, save. No rules, no re-validation of what the command already guarantees.
5. **Adapters**: the repository maps entity <-> storage model; the route validates input at the boundary, calls one use case and maps domain errors to status codes in one place.
6. **Tests**: entity rules, use case with fake ports (happy path, not found, each invalid transition), route test with the app's test client. Run the project's checks from `AGENTS.md`.

```python
@dataclass(frozen=True)
class CreateXCommand:
    owner_id: UUID
    name: str

class CreateX:
    def __init__(self, repository: XRepository, owners: OwnerLookup) -> None:
        self._repository, self._owners = repository, owners

    def __call__(self, command: CreateXCommand) -> X:
        if self._owners.find(command.owner_id) is None:
            raise NotFoundError(f"owner {command.owner_id}")
        return self._repository.save(X.create(uuid4(), command.owner_id, command.name))
```
