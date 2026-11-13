## Python conventions

- Managed with `uv` (`uv sync`, `uv add`, `uv run`); the lockfile `uv.lock` is committed and CI uses `--frozen`.
- Source in `src/<package>/`, tests in `tests/`. Lint and format with ruff, type-check with `mypy --strict`, test with pytest; all configured in `pyproject.toml`.
- Validate external input (env, files, HTTP, CLI args) at the boundary, e.g. with Pydantic, before it reaches the rest of the code.
- Prefer small pure functions and explicit dependencies over module-level state.
