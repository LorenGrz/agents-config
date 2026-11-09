#!/usr/bin/env bash
# test-packs.sh - offline checks for packs (project-agents.sh) and the critical-reasoning hook.
set -uo pipefail
HUB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
export XDG_RUNTIME_DIR="$W/run"; mkdir -p "$XDG_RUNTIME_DIR"  # once-per-session markers go to a temp dir
unset CAO_TERMINAL_ID  # the hooks stay silent inside CAO panes; tests must not depend on where they run
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
check "reasoner reminder names the high-effort reasoner (ADR 0018)" 'grep -q "effort high" <<<"$out" && ! grep -q "Sonnet" <<<"$out"'

# --- hook: once per session, plan mode, notifications, CAO panes
crit='{"hook_event_name":"UserPromptSubmit","session_id":"sess1","prompt":"necesito una migración de la base"}'
out1="$(hook "$P" "$crit")"; out2="$(hook "$P" "$crit")"
check "reasoner reminder is sent once per session" 'grep -q "reasoner" <<<"$out1" && [ -z "$out2" ]'
out="$(hook "$P" '{"hook_event_name":"UserPromptSubmit","session_id":"sess2","prompt":"hay una migración"}')"; out2="$(hook "$P" '{"hook_event_name":"PreToolUse","session_id":"sess2","tool_input":{"file_path":"/x/db/migrations/1.sql"}}')"
check "the cap covers prompts and sensitive edits of the same session" 'grep -q "reasoner" <<<"$out" && [ -z "$out2" ]'
n="$crit"; out1="$(hook "$P" "${n/sess1/}")"; out2="$(hook "$P" "${n/sess1/}")"
check "without a session id the reminder is not capped" 'grep -q "reasoner" <<<"$out1" && grep -q "reasoner" <<<"$out2"'
out="$(hook "$P" '{"hook_event_name":"UserPromptSubmit","session_id":"s3","permission_mode":"plan","prompt":"necesito una migración de la base"}')"
check "plan mode: no reasoner reminder" '[ -z "$out" ]'
out="$(hook "$P" '{"hook_event_name":"UserPromptSubmit","session_id":"s4","permission_mode":"plan","prompt":"migración y un nuevo bounded context"}')"
check "plan mode keeps the skill hint" 'grep -q "new-bounded-context" <<<"$out" && ! grep -q "reasoner" <<<"$out"'
out="$(hook "$P" '{"hook_event_name":"UserPromptSubmit","session_id":"s5","prompt":"<task-notification><summary>la migración terminó</summary></task-notification>"}')"
check "task notifications are ignored" '[ -z "$out" ]'
out="$(CAO_TERMINAL_ID=abc123 hook "$P" '{"hook_event_name":"UserPromptSubmit","session_id":"s6","prompt":"migración y nuevo bounded context"}')"
check "silent inside CAO panes" '[ -z "$out" ]'


# --- all packs: structure
for d in "$HUB"/packs/*/; do
  n="$(basename "$d")"
  check "pack $n: pack.json valid with description and index" 'jq -e ".description and (.index | length > 0)" "$d/pack.json" >/dev/null'
  check "pack $n: skills have matching name and a description" '(for s in "$d"/skills/*/; do [ -d "$s" ] || continue; [ "$(sed -n "s/^name: //p" "$s/SKILL.md" | head -1)" = "$(basename "$s")" ] && grep -q "^description: " "$s/SKILL.md" || exit 1; done)'
  check "pack $n: commands have a description" '(for c in "$d"/commands/*.md; do [ -f "$c" ] || continue; grep -q "^description: " "$c" || exit 1; done)'
  check "pack $n: critical entries point to a skill of the pack" '(for sk in $(jq -r ".critical[]?.skill" "$d/pack.json"); do [ -f "$d/skills/$sk/SKILL.md" ] || exit 1; done)'
done

# --- selection per stack/decision
sel() { jq -n --argjson st "$1" --argjson dec "$2" '{version:1,name:"x",org:null,stacks:$st,decisions:$dec,pending:[]}' > "$W/sel.json"
        d="$W/sel"; rm -rf "$d"; mkp "$d"; bash "$HUB/scripts/project-agents.sh" --stack "$(jq -r '.[0]' <<<"$1")" --manifest "$W/sel.json" --dir "$d" >/dev/null 2>&1; }
sel '["python"]' '[{"key":"backend-style","value":"hexagonal"}]'
check "python hexagonal: python packs, no spring packs" '[ -d "$d/.claude/skills/hexagonal-architecture-py" ] && [ -d "$d/.claude/skills/pytest-conventions" ] && [ ! -d "$d/.claude/skills/spring-testing" ]'
sel '["java-spring"]' '[{"key":"backend-style","value":"modular"}]'
check "spring modular: feature-module and spring-testing" '[ -d "$d/.claude/skills/feature-module" ] && [ -d "$d/.claude/skills/spring-testing" ] && [ -f "$d/.claude/commands/new-module.md" ]'
sel '["react-vite"]' '[{"key":"frontend-style","value":"feature-sliced"}]'
check "react feature-sliced: ui skills plus feature-architecture" '[ -d "$d/.claude/skills/ui-builder" ] && [ -d "$d/.claude/skills/vitest-rtl" ] && [ -d "$d/.claude/skills/feature-architecture" ] && [ ! -d "$d/.claude/skills/frontend-ports-adapters" ]'
sel '["next"]' '[{"key":"frontend-style","value":"hexagonal"}]'
check "next hexagonal: frontend-ports-adapters and /new-feature" '[ -d "$d/.claude/skills/frontend-ports-adapters" ] && [ -f "$d/.claude/commands/new-feature.md" ] && [ ! -d "$d/.claude/skills/feature-architecture" ]'
sel '["react-vite"]' '[{"key":"frontend-style","value":"simple"},{"key":"project-kind","value":"ui-library"}]'
check "ui-library is opt-in via project-kind" '[ -d "$d/.claude/skills/component-a11y-guard" ]'
sel '["react-vite"]' '[{"key":"frontend-style","value":"simple"}]'
check "ui-library absent without project-kind; run-app always present" '[ ! -d "$d/.claude/skills/component-a11y-guard" ] && [ -d "$d/.claude/skills/run-app" ]'
sel '["java-spring"]' '[{"key":"backend-style","value":"hexagonal"}]'
check "AGENTS.md keyword table stays within 14 rows" '[ "$(sed -n "/agents-index:start/,/agents-index:end/p" "$d/AGENTS.md" | grep -c "^| .* | .* |$")" -le 15 ]'

# --- re-running with other decisions: stale pack items go, user items stay
P5="$W/stale"; mkp "$P5"; man "$W/st.json" hexagonal
bash "$HUB/scripts/project-agents.sh" --stack java-spring --manifest "$W/st.json" --dir "$P5" >/dev/null 2>&1
mkdir -p "$P5/.claude/skills/mine" "$P5/.claude/commands"; echo x > "$P5/.claude/skills/mine/SKILL.md"; echo x > "$P5/.claude/commands/mine.md"
man "$W/st.json" modular
out="$(bash "$HUB/scripts/project-agents.sh" --stack java-spring --manifest "$W/st.json" --dir "$P5" 2>&1)"
check "stale pack skills and commands are removed on a new selection" '[ ! -d "$P5/.claude/skills/hexagonal-architecture" ] && [ ! -f "$P5/.claude/commands/new-bc.md" ] && [ -d "$P5/.claude/skills/feature-module" ] && grep -q "removed stale" <<<"$out"'
check "stale critical entries are dropped, user files stay" '! jq -e "map(.skill) | index(\"new-bounded-context\") != null" "$P5/.agents/critical.json" >/dev/null 2>&1 && [ -f "$P5/.claude/skills/mine/SKILL.md" ] && [ -f "$P5/.claude/commands/mine.md" ]'
check "skills.lock lists what was installed" 'jq -e ".installed.skills | index(\"feature-module\") != null" "$P5/.agents/skills.lock" >/dev/null'

# --- an architecture decision with no pack is announced
jq -n '{version:1,name:"x",org:null,stacks:["java-spring"],decisions:[{key:"backend-style",value:"hexagonal + DDD"}],pending:[]}' > "$W/free.json"
P6="$W/free"; mkp "$P6"
out="$(bash "$HUB/scripts/project-agents.sh" --stack java-spring --manifest "$W/free.json" --dir "$P6" 2>&1)"
check "free-text style gets a note that no pack matched" 'grep -q "note: no pack matches backend-style" <<<"$out"'

# --- hook: an invalid regex in critical.json must not silence the other entries
jq '. = [{"skill":"hexagonal-architecture","keywords":"(unclosed"}] + .' "$P/.agents/critical.json" > "$W/crit.json" && cp "$W/crit.json" "$P/.agents/critical.json"
out="$(hook "$P" '{"hook_event_name":"UserPromptSubmit","prompt":"nuevo bounded context"}')"
check "an invalid regex entry does not silence valid ones" 'grep -q "new-bounded-context/SKILL.md" <<<"$out"'

# --- without a manifest, packs that only depend on the stack still install (decision packs do not)
nm() { d="$W/nm-$1"; rm -rf "$d"; mkp "$d"; bash "$HUB/scripts/project-agents.sh" --stack "$1" --dir "$d" >/dev/null 2>&1; }
nm react-vite
check "react-vite without a manifest gets the frontend-ui pack but no architecture pack" '[ -d "$d/.claude/skills/ui-builder" ] && [ -d "$d/.claude/skills/vitest-rtl" ] && [ ! -d "$d/.claude/skills/feature-architecture" ] && [ ! -d "$d/.claude/skills/react-scalable-frontend" ]'
nm python
check "python without a manifest gets pytest-conventions only" '[ -d "$d/.claude/skills/pytest-conventions" ] && [ ! -d "$d/.claude/skills/hexagonal-architecture-py" ]'
nm java-spring
check "java-spring without a manifest gets spring-testing only" '[ -d "$d/.claude/skills/spring-testing" ] && [ ! -d "$d/.claude/skills/hexagonal-architecture" ]'
check "react-component-validator stays a stack skill" 'nm react-vite; [ -d "$d/.claude/skills/react-component-validator" ]'

echo; echo "$pass passed, $failn failed"
[ "$failn" -eq 0 ]
