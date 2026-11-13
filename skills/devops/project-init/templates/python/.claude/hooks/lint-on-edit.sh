#!/usr/bin/env bash
# PostToolUse(Edit|Write|MultiEdit) hook: auto-fix, format and lint the edited
# .py file with the project's ruff. Blocks (exit 2) only when errors remain after
# --fix, so the agent sees them immediately instead of at PR time.
set -uo pipefail

payload="$(cat)"
f="$(jq -r '.tool_input.file_path // .tool_response.filePath // empty' <<<"$payload" 2>/dev/null)"
[ -n "$f" ] && [ -f "$f" ] || exit 0
[ "${f##*.}" = "py" ] || exit 0
command -v uv >/dev/null 2>&1 || exit 0

root="$(dirname "$f")"
while [ "$root" != "/" ] && [ ! -f "$root/pyproject.toml" ]; do root="$(dirname "$root")"; done
[ -f "$root/pyproject.toml" ] || exit 0
cd "$root" || exit 0

uv run --quiet ruff check --fix --quiet "$f" >/dev/null 2>&1 || true
uv run --quiet ruff format --quiet "$f" >/dev/null 2>&1 || true

if output="$(uv run --quiet ruff check "$f" 2>&1)"; then
  exit 0
else
  printf '%s\n' "$output" >&2
  exit 2
fi
