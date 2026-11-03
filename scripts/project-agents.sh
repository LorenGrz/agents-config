#!/usr/bin/env bash
# project-agents.sh - install the stack-specific skills, rules and MCP servers
# of one or more stacks into a project's .claude/ and .mcp.json.
#
# Usage: project-agents.sh --stack <name>[,<name>...] [--dir <path>] [--dry-run]
#
# Stacks come from config/scopes.json (react-vite, next, nestjs, node-ts, rn,
# aws, python, kotlin, apex, docker, llm, supabase, jira). Everything not listed
# there is global and already installed by install.sh.
#
# Files are copied (not symlinked) so the repo stays portable for CI and other
# clones. Re-running refreshes the managed copies. .mcp.json is merged, never
# overwritten; no secrets are written.
set -euo pipefail

HUB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCOPES="$HUB/config/scopes.json"
STACKS="" DIR="$(pwd)" DRY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --stack) STACKS="$2"; shift 2 ;;
    --dir) DIR="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done
[ -n "$STACKS" ] || { echo "Error: --stack is required" >&2; exit 1; }
command -v jq >/dev/null || { echo "Error: jq is required" >&2; exit 1; }

run() { if [ "$DRY" -eq 1 ]; then echo "  [dry-run] $*"; else "$@"; fi; }

find_skill() {
  local name="$1" d
  d="$(find "$HUB" -mindepth 2 -maxdepth 2 -name "$name" \( -type d -o -type l \) -not -path "$HUB/config/*" -not -path "$HUB/.git/*" | head -1)"
  [ -n "$d" ] || { [ -e "$HUB/$name/SKILL.md" ] && d="$HUB/$name"; }
  printf '%s' "$d"
}

IFS=',' read -r -a LIST <<<"$STACKS"
for stack in "${LIST[@]}"; do
  jq -e --arg s "$stack" '.stacks[$s]' "$SCOPES" >/dev/null \
    || { echo "unknown stack '$stack' (see $SCOPES)" >&2; exit 1; }
  echo "== stack: $stack =="

  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    src="$(find_skill "$skill")"
    if [ -z "$src" ]; then echo "skip skill $skill (not found in hub)" >&2; continue; fi
    echo "skill:   .claude/skills/$skill"
    run mkdir -p "$DIR/.claude/skills"
    run rm -rf "$DIR/.claude/skills/$skill"
    run cp -rL "$src" "$DIR/.claude/skills/$skill"
  done < <(jq -r --arg s "$stack" '.stacks[$s].skills[]?' "$SCOPES")

  while IFS= read -r rule; do
    [ -n "$rule" ] || continue
    echo "rule:    .claude/rules/$rule.md"
    run mkdir -p "$DIR/.claude/rules"
    run cp "$HUB/config/rules/$rule.md" "$DIR/.claude/rules/$rule.md"
  done < <(jq -r --arg s "$stack" '.stacks[$s].rules[]?' "$SCOPES")

  mcp="$(jq -c --arg s "$stack" '.stacks[$s].mcp // empty' "$SCOPES")"
  if [ -n "$mcp" ]; then
    echo "mcp:     .mcp.json <- $(jq -r 'keys|join(",")' <<<"$mcp")"
    if [ "$DRY" -eq 0 ]; then
      cur='{"mcpServers":{}}'
      [ -f "$DIR/.mcp.json" ] && cur="$(cat "$DIR/.mcp.json")"
      jq --argjson add "$mcp" '.mcpServers = ((.mcpServers // {}) + $add)' <<<"$cur" >"$DIR/.mcp.json.tmp"
      mv "$DIR/.mcp.json.tmp" "$DIR/.mcp.json"
    fi
  fi
done
echo "done. Commit .claude/ and .mcp.json; MCP servers still need /mcp auth on first use."
