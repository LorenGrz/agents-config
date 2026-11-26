#!/usr/bin/env bash
# test-orquestar.sh - offline checks for config/hooks/orquestar.sh (ADR 0039): it injects the fixed
# orchestration procedure only when the user picked «Orquestar», and the lane guard accepts the
# Orquestar/Continuar question (Orquestar first, ADR 0067).
set -uo pipefail
HUB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$HUB/config/hooks/orquestar.sh"
LANE="$HUB/config/hooks/lane-guard.sh"
pass=0; failn=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"; else failn=$((failn + 1)); echo "FAIL $1"; fi; }

# answered <json tool_response> [agent_type] -> the hook's additionalContext ("" when it stays silent)
answered() { jq -n --argjson r "$1" --arg a "${2:-}" '{tool_name:"AskUserQuestion",tool_response:$r}
  + (if $a == "" then {} else {agent_type:$a} end)' | bash "$HOOK" | jq -r '.hookSpecificOutput.additionalContext // empty'; }
ask() { jq -n --args '{tool_name:"AskUserQuestion",tool_input:{questions:[{question:"q",header:"h",multiSelect:false,
  options:[$ARGS.positional[] | {label:., description:"d"}]}]}}' "$@" | bash "$LANE" 2>/dev/null; echo $?; }

check "Orquestar picked (answers object) injects the procedure" \
  '[[ "$(answered "{\"answers\":{\"q\":\"Orquestar (Recomendado)\"}}")" == *"Procedimiento fijo"* ]]'
check "Orquestar picked (answer text) injects the procedure" \
  '[[ "$(answered "\"Your questions have been answered: \\\"q\\\"=\\\"Orquestar\\\". You can now continue.\"")" == *"Procedimiento fijo"* ]]'
check "the procedure names the approval script with an absolute path" \
  '[[ "$(answered "{\"answers\":{\"q\":\"Orquestar\"}}")" == *"$HUB/scripts/approve-claude-imports.sh"* ]]'
check "leads close on their own: no --keep-open by default (ADR 0064)" \
  '[[ "$(answered "{\"answers\":{\"q\":\"Orquestar\"}}")" != *"<modelo de líder> --keep-open"* ]]'
check "review fixes go through send to the dispatch" \
  '[[ "$(answered "{\"answers\":{\"q\":\"Orquestar\"}}")" == *"send --to dispatch:"* ]]'
check "a dependent ticket uses an Orca task with --deps" \
  '[[ "$(answered "{\"answers\":{\"q\":\"Orquestar\"}}")" == *"--deps"* ]]'
check "Continuar picked stays silent" '[ -z "$(answered "{\"answers\":{\"q\":\"Continuar\"}}")" ]'
check "Orquestar only offered, not picked, stays silent" \
  '[ -z "$(answered "{\"questions\":[{\"options\":[{\"label\":\"Orquestar\"}]}],\"answers\":{\"q\":\"Continuar\"}}")" ]'
check "subagent is not checked" '[ -z "$(answered "{\"answers\":{\"q\":\"Orquestar\"}}" worker)" ]'

check "lane guard: Orquestar, Continuar passes (ADR 0067)" '[ "$(ask Orquestar "Continuar (Recomendado)")" = 0 ]'
check "lane guard: Continuar moved first is denied" '[ "$(ask "Continuar (Recomendado)" Orquestar)" = 2 ]'
check "lane guard: Continuar, Plan S, Plan L still passes" '[ "$(ask Continuar "Plan S" "Plan L")" = 0 ]'

echo "$pass ok, $failn failed"
[ "$failn" -eq 0 ]
