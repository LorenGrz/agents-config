---
name: pytest-conventions
description: pytest conventions for Python projects - layout, naming, fixtures, parametrization, fakes over mocks, coverage gap analysis. Use for "escribir tests", "agregar tests", "cobertura", "fixtures", "write tests", "add tests", "pytest", "what tests are missing".
---

# pytest conventions

## Objective

One consistent way to lay out, name and isolate pytest tests.

## Rules

- Tests live in `tests/`, mirroring `src/<package>/`; files `test_<module>.py`; functions `test_<behavior>_when_<condition>`.
- Test observable behavior through the public API, not private functions or attributes. One behavior per test.
- Arrange-act-assert with plain `assert`; use `pytest.raises(Type, match=...)` for errors.
- `@pytest.mark.parametrize` for the same rule over several inputs; give the cases ids.
- Fixtures: small, explicit, in `conftest.py` only when shared by several files; prefer factory fixtures over big shared objects. Keep them function-scoped unless setup is genuinely expensive.
- Prefer in-memory fakes of ports (a dict-backed repository) over `unittest.mock`; mock only at the process boundary (HTTP, clock, queues). Do not mock the unit under test.
- Time and randomness are injected or frozen; never sleep.
- No network, shared database or wall-clock dependence in unit tests; integration tests are marked (`@pytest.mark.integration`) and kept separate.
- Everything stays type-hinted: `mypy --strict` also covers tests.

### Coverage gap analysis

- [ ] happy path, with the final state asserted
- [ ] every raised domain error, each invalid transition
- [ ] empty, None, boundary and invalid inputs where they apply
- [ ] side effects through ports receive what the use case actually saved

## Verification

Run `uv run pytest` and `uv run mypy .` before finishing; do not change production code just to make a test pass unless the analysis shows a real defect.
