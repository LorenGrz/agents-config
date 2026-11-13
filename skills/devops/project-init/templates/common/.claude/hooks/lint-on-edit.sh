#!/usr/bin/env bash
# PostToolUse(Edit|Write|MultiEdit) hook: auto-fix then lint the edited file
# with the project's own ESLint. Blocks (exit 2) only when errors remain
# after --fix, so the agent sees them immediately instead of at PR time.
set -uo pipefail

payload="$(cat)"
f="$(jq -r '.tool_input.file_path // .tool_response.filePath // empty' <<<"$payload" 2>/dev/null)"
[ -n "$f" ] && [ -f "$f" ] || exit 0

case "${f##*.}" in
  ts|tsx|js|jsx|mjs|cjs) ;;
  *) exit 0 ;;
esac

find_up() { # find_up <start-dir> <relative-path> -> prints path if found
  local d="$1"
  while [ "$d" != "/" ]; do
    [ -e "$d/$2" ] && { printf '%s' "$d/$2"; return 0; }
    d="$(dirname "$d")"
  done
  return 1
}

dir="$(dirname "$f")"
eslint="$(find_up "$dir" node_modules/.bin/eslint || true)"
[ -n "$eslint" ] || exit 0

"$eslint" --fix "$f" >/dev/null 2>&1 || true

if output="$("$eslint" "$f" 2>&1)"; then
  exit 0
else
  printf '%s\n' "$output" >&2
  exit 2
fi
