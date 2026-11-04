#!/usr/bin/env bash
# gen-plugin.sh - regenerate the derived plugin files from their sources.
#   .claude-plugin/plugin.json "skills" <- every skill NOT listed in config/scopes.json
#   hooks/hooks.json                    <- config/settings.base.json hooks, minus machine-specific ones
#
# Usage: gen-plugin.sh [--check]   (--check: exit 1 if a file is out of date, write nothing)
set -euo pipefail

HUB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN="$HUB/.claude-plugin/plugin.json"
HOOKS="$HUB/hooks/hooks.json"
SCOPES="$HUB/config/scopes.json"
BASE="$HUB/config/settings.base.json"
# Hooks that only make sense on the author's machine (desktop/tooling specific).
LOCAL_ONLY='guard-omarchy|rtk\.sh'
CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1
command -v jq >/dev/null || { echo "Error: jq is required" >&2; exit 1; }

project_skills="$(jq -r '[.stacks[].skills[]] | unique[]' "$SCOPES")"
skills="$(
  find "$HUB" -mindepth 3 -maxdepth 3 -name SKILL.md -not -path "$HUB/config/*" -not -path "$HUB/.git/*" \
    | while read -r f; do
        d="$(dirname "$f")"
        grep -qxF -- "$(basename "$d")" <<<"$project_skills" && continue
        printf './%s\n' "${d#"$HUB"/}"
      done | sort | jq -R . | jq -s .
)"

new_plugin="$(jq --argjson s "$skills" '.skills = $s' "$PLUGIN")"
new_hooks="$(jq --arg skip "$LOCAL_ONLY" '
  {hooks: (.hooks | map_values(
    map(.hooks |= map(select(.command | test($skip) | not)) | select(.hooks | length > 0))
    | map(.hooks |= map(.command |= sub("bash ~/\\.claude/hooks/(?<f>\\S+)"; "bash \"${CLAUDE_PLUGIN_ROOT}/config/hooks/" + .f + "\""))))
  )}' "$BASE")"

drift=0
write_or_check() { # <path> <content>
  if [ "$CHECK" -eq 1 ]; then
    [ "$(cat "$1")" = "$2" ] || { echo "out of date: ${1#"$HUB"/} (run scripts/gen-plugin.sh)" >&2; drift=1; }
  else
    printf '%s\n' "$2" > "$1"; echo "wrote ${1#"$HUB"/}"
  fi
}
write_or_check "$PLUGIN" "$new_plugin"
write_or_check "$HOOKS" "$new_hooks"
exit "$drift"
