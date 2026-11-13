#!/usr/bin/env bash
# test-lane-guard.sh - offline checks for config/hooks/lane-guard.sh (ADR 0025): lane order in
# AskUserQuestion and the mandatory grilling interview before ExitPlanMode.
set -uo pipefail
HUB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$HUB/config/hooks/lane-guard.sh"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
pass=0; failn=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"; else failn=$((failn + 1)); echo "FAIL $1"; fi; }

# ask <label>...  -> hook exit code for one question with those option labels
ask() { jq -n --args '{tool_name:"AskUserQuestion",tool_input:{questions:[{question:"q",header:"h",multiSelect:false,
  options:[$ARGS.positional[] | {label:., description:"d"}]}]}}' "$@" | bash "$HOOK" 2>/dev/null; echo $?; }
# transcript line helpers
use() { jq -cn --arg n "$1" --argjson i "${2:-{\}}" '{type:"assistant",message:{content:[{type:"tool_use",name:$n,input:$i}]}}'; }
cmd() { jq -cn --arg t "<command-name>/$1</command-name>" '{type:"user",message:{content:$t}}'; }
# exitplan <transcript-file> [agent_type] -> hook exit code
exitplan() { jq -n --arg t "$1" --arg a "${2:-}" '{tool_name:"ExitPlanMode",tool_input:{},transcript_path:$t}
  + (if $a == "" then {} else {agent_type:$a} end)' | bash "$HOOK" 2>/dev/null; echo $?; }

# --- lane order
check "Continuar, Plan S, Plan L passes" '[ "$(ask Continuar "Plan S" "Plan L")" = 0 ]'
check "recommended marker without moving passes" '[ "$(ask Continuar "Plan S (Recomendado)" "Plan L")" = 0 ]'
check "recommended moved first is denied" '[ "$(ask "Plan S (Recomendado)" Continuar "Plan L")" = 2 ]'
check "missing a lane is denied" '[ "$(ask Continuar "Plan L")" = 2 ]'
check "question without lanes passes" '[ "$(ask "Jira Automation" "GitHub Action")" = 0 ]'
check "subagent is not checked" '[ "$(jq -n "{agent_type:\"worker\",tool_name:\"AskUserQuestion\",tool_input:{questions:[{options:[{label:\"Plan L\"},{label:\"Continuar\"}]}]}}" | bash "$HOOK" 2>/dev/null; echo $?)" = 0 ]'

# --- grilling before ExitPlanMode
{ use EnterPlanMode; } >"$W/none.jsonl"
{ use EnterPlanMode; use Skill '{"skill":"mattpocock-skills:grilling"}'; } >"$W/skill.jsonl"
{ use EnterPlanMode; cmd mattpocock-skills:grilling; } >"$W/slash.jsonl"
{ use Skill '{"skill":"mattpocock-skills:grilling"}'; use EnterPlanMode; } >"$W/stale.jsonl"
{ use Skill '{"skill":"mattpocock-skills:grilling"}'; } >"$W/manual.jsonl"
{ use Skill '{"skill":"jira-usage"}'; } >"$W/manual-none.jsonl"
check "no grilling after EnterPlanMode is denied" '[ "$(exitplan "$W/none.jsonl")" = 2 ]'
check "grilling via Skill passes" '[ "$(exitplan "$W/skill.jsonl")" = 0 ]'
check "grilling via slash command passes" '[ "$(exitplan "$W/slash.jsonl")" = 0 ]'
check "grilling only before the last EnterPlanMode is denied" '[ "$(exitplan "$W/stale.jsonl")" = 2 ]'
check "manual plan mode with grilling in session passes" '[ "$(exitplan "$W/manual.jsonl")" = 0 ]'
check "manual plan mode without grilling is denied" '[ "$(exitplan "$W/manual-none.jsonl")" = 2 ]'
check "missing transcript passes (nothing to check)" '[ "$(exitplan "$W/missing.jsonl")" = 0 ]'
check "subagent ExitPlanMode is not checked" '[ "$(exitplan "$W/none.jsonl" Plan)" = 0 ]'
check "settings.base.json wires the hook" 'jq -e ".hooks.PreToolUse[] | select(.matcher == \"AskUserQuestion|ExitPlanMode\") | .hooks[].command | test(\"lane-guard.sh\")" "$HUB/config/settings.base.json" >/dev/null'

echo "$pass passed, $failn failed"
[ "$failn" -eq 0 ]
