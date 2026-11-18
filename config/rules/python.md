---
paths:
  - "**/*.py"
---

# Python

## Tooling

- **uv** for envs and dependencies (`uv init`, `uv add`, `uv run`, `uv sync`). Not pip/poetry/virtualenv unless the project already uses them.
- **ruff** for lint + format, instead of black, isort, flake8, pyupgrade: `ruff check --fix` and `ruff format`.
- **mypy --strict** (or pyright) for type checks; type errors are build failures.
- One config file: `pyproject.toml`. No `setup.py`, `setup.cfg`, `.flake8`, `mypy.ini`.
- `src/` layout for packages.

## Code

- Type-annotate every function signature and module-level name.
- Validate external data (HTTP, env, files, CLI, queues) with **Pydantic v2** models; use `pydantic-settings` for config. Never trust raw dicts across a boundary.
- `pathlib.Path`, not `os.path`. `logging`, not `print`. f-strings, not `%`/`.format`.
- Context managers for files, connections, locks. No bare `except:` - catch specific types, preserve `__cause__`.
- No mutable default arguments. Prefer pure functions and small modules.
- `async`/`await` for I/O-bound concurrency; don't mix blocking calls into an event loop.

## Automation & agent scripts

- Every network/tool/LLM call gets a timeout and bounded retries with exponential backoff (`tenacity`), then a deterministic fallback after N attempts, never an infinite loop.
- Make side-effecting operations idempotent (idempotency key, "check then act", or safe re-run).
- Structured LLM output: define a Pydantic schema, parse into it, retry on validation failure, fail closed if it never validates.
- Least-privilege credentials scoped to the task. Never `eval`/`exec`/shell-interpolate model or external output. See the `prompt-injection-defense` skill for LLM-facing code.
- Guard cost/tokens/rate; log each external call with inputs and outcome.
- Make runs observable and resumable: checkpoint progress, log start/end, exit non-zero on failure so schedulers notice.

For AWS Lambda specifics, use the `lambda-patterns` skill.
