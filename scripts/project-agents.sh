#!/usr/bin/env bash
# project-agents.sh - install the stack-specific skills, rules and MCP servers
# of one or more stacks into a project's .claude/ and .mcp.json.
#
# Usage: project-agents.sh --stack <name>[,<name>...] [--pack <name>[,...]] [--manifest <file>]
#                           [--dir <path>] [--dry-run]
#
# Packs (packs/<name>/: pack.json, skills/, commands/) bundle skills and slash commands by
# architecture. "always" packs are installed with any run; others when the project manifest
# (.agents/project.json schema) matches pack.json "when" (stack AND decisions), or via --pack.
# Packs also write .agents/critical.json (keyword/path -> skill, read by the critical-reasoning
# hook), a keyword table in AGENTS.md (between agents-index markers) and .agents/skills.lock.
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
STACKS="" PACKS="" MANIFEST="" DIR="$(pwd)" DRY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --stack) STACKS="$2"; shift 2 ;;
    --pack) PACKS="$2"; shift 2 ;;
    --manifest) MANIFEST="$2"; shift 2 ;;
    --dir) DIR="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done
[ -n "$STACKS$PACKS$MANIFEST" ] || { echo "Error: --stack, --pack or --manifest is required" >&2; exit 1; }
command -v jq >/dev/null || { echo "Error: jq is required" >&2; exit 1; }

run() { if [ "$DRY" -eq 1 ]; then echo "  [dry-run] $*"; else "$@"; fi; }

find_skill() {
  local name="$1" d
  d="$(find "$HUB" -mindepth 2 -maxdepth 2 -name "$name" \( -type d -o -type l \) -not -path "$HUB/config/*" -not -path "$HUB/.git/*" | head -1)"
  [ -n "$d" ] || { [ -e "$HUB/$name/SKILL.md" ] && d="$HUB/$name"; }
  printf '%s' "$d"
}

IFS=',' read -r -a LIST <<<"$STACKS"
[ -n "$STACKS" ] || LIST=()
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


# ---------------------------------------------------------------- packs
# select_packs: "always" packs, packs named with --pack, and packs whose "when" matches the manifest.
select_packs() {
  local d name
  for d in "$HUB"/packs/*/; do
    [ -f "$d/pack.json" ] || continue
    name="$(basename "$d")"
    if jq -e '.always == true' "$d/pack.json" >/dev/null; then echo "$name"; continue; fi
    if [ -n "$PACKS" ] && grep -qxF "$name" < <(tr ',' '\n' <<<"$PACKS"); then echo "$name"; continue; fi
    if [ -n "$MANIFEST" ] && jq -e --slurpfile m "$MANIFEST" '
        (.when // null) as $w
        | $w != null
        and (($w.stacks // null) == null or any($w.stacks[]; . as $s | ($m[0].stacks // []) | index($s) != null))
        and (($w.decisions // {}) | to_entries | all(.[]; . as $e | any($m[0].decisions[]?; .key == $e.key and .value == $e.value)))
      ' "$d/pack.json" >/dev/null; then echo "$name"; fi
  done
}

mapfile -t SELECTED < <(select_packs | sort -u)
CRITICAL="[]" ROWS=""
for pack in "${SELECTED[@]}"; do
  src="$HUB/packs/$pack"
  echo "== pack: $pack =="
  for sk in "$src"/skills/*/; do
    [ -f "$sk/SKILL.md" ] || continue
    echo "skill:   .claude/skills/$(basename "$sk")"
    run mkdir -p "$DIR/.claude/skills"
    run rm -rf "$DIR/.claude/skills/$(basename "$sk")"
    run cp -rL "${sk%/}" "$DIR/.claude/skills/$(basename "$sk")"
  done
  for cmd in "$src"/commands/*.md; do
    [ -f "$cmd" ] || continue
    echo "command: .claude/commands/$(basename "$cmd")"
    run mkdir -p "$DIR/.claude/commands"
    run cp "$cmd" "$DIR/.claude/commands/$(basename "$cmd")"
  done
  CRITICAL="$(jq -c --slurpfile c "$src/pack.json" '. + ($c[0].critical // [])' <<<"$CRITICAL")"
  ROWS+="$(jq -r '.index[]? | "| \(.when) | `\(.use)` |"' "$src/pack.json")"$'\n'
done

if [ "${#SELECTED[@]}" -gt 0 ] && [ "$DRY" -eq 0 ]; then
  mkdir -p "$DIR/.agents"
  # critical.json: read by the critical-reasoning hook (keywords/paths -> skill hint).
  if [ "$CRITICAL" != "[]" ]; then jq . <<<"$CRITICAL" > "$DIR/.agents/critical.json"; echo "wrote .agents/critical.json"; fi
  # AGENTS.md keyword table: replace the marked block, else insert it before "## How we work", else append.
  if [ -f "$DIR/AGENTS.md" ] && [ -n "${ROWS//[$'\n']/}" ]; then
    block="$(printf '<!-- agents-index:start -->\n## Skills and commands by keyword\n\nBefore implementing, read the skill for what you are touching.\n\n| When | Use |\n|---|---|\n%s<!-- agents-index:end -->\n' "$(head -n 10 <<<"$ROWS")"$'\n')"
    tmp="$(mktemp)"
    if grep -q 'agents-index:start' "$DIR/AGENTS.md"; then
      B="$block" awk '/agents-index:start/ {print ENVIRON["B"]; skip=1} !skip {print} /agents-index:end/ {skip=0}' "$DIR/AGENTS.md" > "$tmp"
    elif grep -q '^## How we work' "$DIR/AGENTS.md"; then
      B="$block" awk '/^## How we work/ && !d {print ENVIRON["B"]; print ""; d=1} {print}' "$DIR/AGENTS.md" > "$tmp"
    else
      { cat "$DIR/AGENTS.md"; printf '\n%s\n' "$block"; } > "$tmp"
    fi
    mv "$tmp" "$DIR/AGENTS.md"; echo "updated AGENTS.md keyword table"
  fi
  # skills.lock: what was installed from which hub revision (updates are always explicit).
  jq -n --arg hub "$(git -C "$HUB" rev-parse --short HEAD 2>/dev/null || echo unknown)" \
        --arg packs "$(IFS=,; echo "${SELECTED[*]}")" --arg stacks "$STACKS" \
    '{hub: $hub, stacks: ($stacks | split(",") | map(select(. != ""))), packs: ($packs | split(",") | map(select(. != "")))}' > "$DIR/.agents/skills.lock"
  echo "wrote .agents/skills.lock"
fi
echo "done. Commit .claude/, .agents/ and .mcp.json; MCP servers still need /mcp auth on first use."
