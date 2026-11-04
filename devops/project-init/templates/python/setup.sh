#!/usr/bin/env bash
# Python stack setup: dev tools + ruff/mypy/pytest config in pyproject.toml.
# Env: DIR (project), INSTALL (1 = actually run). Idempotent.
set -euo pipefail
PY="$DIR/pyproject.toml"
[ -f "$PY" ] || { echo "no pyproject.toml in $DIR: run 'uv init --package --vcs none <dir>' first" >&2; exit 1; }

if [ "$INSTALL" = 1 ]; then
  (cd "$DIR" && uv add --dev ruff mypy pytest)
else
  echo "Run this to install the dev tools: (cd $DIR && uv add --dev ruff mypy pytest)"
fi

add_table() { # add_table <table-name> <body>: append only if the table is missing
  grep -q "^\[$1\]" "$PY" && return 0
  printf '\n[%s]\n%s\n' "$1" "$2" >> "$PY"
  echo "pyproject.toml: added [$1]"
}
add_table tool.ruff 'line-length = 100'
add_table tool.ruff.lint 'select = ["E", "F", "I", "UP", "B", "SIM", "C4", "RUF"]'
add_table tool.mypy 'strict = true'
add_table tool.pytest.ini_options 'testpaths = ["tests"]'
