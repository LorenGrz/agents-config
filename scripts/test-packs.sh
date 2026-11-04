#!/usr/bin/env bash
# test-packs.sh - offline checks for packs (project-agents.sh) and the critical-reasoning hook.
set -uo pipefail
HUB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
pass=0; failn=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"; else failn=$((failn + 1)); echo "FAIL $1"; fi; }

mkp() { mkdir -p "$1"; printf '# P\n\n## Commands\n\n## How we work\n\nx\n' > "$1/AGENTS.md"; }
man() { jq -n --arg style "$2" '{version:1,name:"x",org:null,stacks:["java-spring"],decisions:[{key:"backend-style",value:$style}],pending:[]}' > "$1"; }

# --- hexagonal manifest: hexagonal pack + workflow
P="$W/hex"; mkp "$P"; man "$W/hex.json" hexagonal
bash "$HUB/scripts/project-agents.sh" --stack java-spring --manifest "$W/hex.json" --dir "$P" >/dev/null 2>&1
check "hexagonal pack skills installed" '[ -f "$P/.claude/skills/hexagonal-architecture/SKILL.md" ] && [ -f "$P/.claude/skills/new-bounded-context/SKILL.md" ]'
check "pack command installed" '[ -f "$P/.claude/commands/new-bc.md" ]'
check "workflow pack always installed" '[ -f "$P/.claude/commands/smart-commit.md" ] && [ -f "$P/.claude/commands/ship-pr.md" ]'
check "critical.json has the pack entries" '[ "$(jq length "$P/.agents/critical.json")" -ge 2 ]'
check "AGENTS.md keyword table inserted before How we work" '[ "$(grep -n "agents-index:start" "$P/AGENTS.md" | cut -d: -f1)" -lt "$(grep -n "^## How we work" "$P/AGENTS.md" | cut -d: -f1)" ] && grep -q "new-bounded-context" "$P/AGENTS.md"'
check "skills.lock records packs" 'jq -e ".packs | index(\"workflow\") != null and index(\"backend-hexagonal-spring\") != null" "$P/.agents/skills.lock" >/dev/null'
before="$(find "$P" -type f -exec sha1sum {} + | grep -v skills.lock | sort)"
bash "$HUB/scripts/project-agents.sh" --stack java-spring --manifest "$W/hex.json" --dir "$P" >/dev/null 2>&1
check "second run changes nothing" '[ "$before" = "$(find "$P" -type f -exec sha1sum {} + | grep -v skills.lock | sort)" ] && [ "$(grep -c agents-index:start "$P/AGENTS.md")" -eq 1 ]'

# --- modular manifest: no hexagonal pack
P2="$W/mod"; mkp "$P2"; man "$W/mod.json" modular
bash "$HUB/scripts/project-agents.sh" --stack java-spring --manifest "$W/mod.json" --dir "$P2" >/dev/null 2>&1
check "non-matching decision skips the architecture pack" '[ ! -d "$P2/.claude/skills/hexagonal-architecture" ] && [ -f "$P2/.claude/commands/smart-commit.md" ]'

# --- hook
hook() { CLAUDE_PROJECT_DIR="$1" bash "$HUB/config/hooks/critical-reasoning.sh" <<<"$2"; }
out="$(hook "$P" '{"hook_event_name":"UserPromptSubmit","prompt":"agregá un nuevo bounded context de pagos"}')"
check "keyword prompt hints the skill" 'grep -q "new-bounded-context/SKILL.md" <<<"$out"'
out="$(hook "$P" '{"hook_event_name":"UserPromptSubmit","prompt":"arreglá el README"}')"
check "unrelated prompt stays silent" '[ -z "$out" ]'
out="$(hook "$P" '{"hook_event_name":"PreToolUse","tool_input":{"file_path":"/x/src/main/java/a/domain/model/X.java"}}')"
check "edit under domain/ hints hexagonal-architecture" 'grep -q "hexagonal-architecture/SKILL.md" <<<"$out"'
out="$(hook "$P" '{"hook_event_name":"UserPromptSubmit","agent_type":"worker","prompt":"nuevo bounded context"}')"
check "silent inside subagents" '[ -z "$out" ]'
out="$(hook "$P2" '{"hook_event_name":"UserPromptSubmit","prompt":"nuevo bounded context"}')"
check "no hint when the skill is not installed" '[ -z "$out" ]'
out="$(hook "$P" '{"hook_event_name":"UserPromptSubmit","prompt":"necesito una migración de la base y un nuevo bounded context"}')"
check "critical reasoning and skill hint combine" 'grep -q "reasoner" <<<"$out" && grep -q "new-bounded-context" <<<"$out"'

echo; echo "$pass passed, $failn failed"
[ "$failn" -eq 0 ]
