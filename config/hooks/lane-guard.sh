#!/usr/bin/env bash
# PreToolUse(AskUserQuestion|ExitPlanMode) hook: enforces the workflow-lane rules of config/CLAUDE.md
# (ADR 0022, ADR 0025) instead of leaving them as prompt text.
#  - AskUserQuestion: a question offering the lanes must list them in the fixed order
#    Continuar -> Plan S -> Plan L. The recommended one is marked in its label, never moved first
#    (the tool's own "recommended first" guidance loses here).
#  - ExitPlanMode: a plan (Plan S or Plan L) is presented only after a grilling interview: the
#    `mattpocock-skills:grilling` skill must have been loaded since the session last entered plan mode.
# Denies with exit 2; stderr goes back to the agent. Subagents are not checked.
set -uo pipefail

input=$(cat)
[ -n "$(jq -r '.agent_type // empty' <<<"$input")" ] && exit 0
tool=$(jq -r '.tool_name // empty' <<<"$input")

case "$tool" in
  AskUserQuestion)
    # For every question whose options mention a lane, the lane options (in the order given)
    # must be exactly: Continuar, Plan S, Plan L.
    bad=$(jq -r '
      [.tool_input.questions[]?
        | [.options[]?.label
           | ascii_downcase
           | if startswith("continuar") then "C"
             elif startswith("plan s") then "S"
             elif startswith("plan l") then "L"
             else empty end]
        | select(length > 0 and . != ["C","S","L"])] | length' <<<"$input")
    if [ "${bad:-0}" != 0 ]; then
      echo "lane-guard: las opciones de carril van siempre en este orden: Continuar, Plan S, Plan L (las tres). Marcá la recomendada con \"(Recomendado)\" en su label sin moverla de lugar; esto pisa la guía de AskUserQuestion de poner la recomendada primero." >&2
      exit 2
    fi ;;
  ExitPlanMode)
    tp=$(jq -r '.transcript_path // empty' <<<"$input")
    [ -n "$tp" ] && [ -r "$tp" ] || exit 0
    # One letter per relevant event, in transcript order: E = EnterPlanMode, G = grilling loaded
    # (Skill tool call or the user typing the slash command).
    seq=$(jq -r '
      if .type == "assistant" then
        .message.content[]? | select(.type == "tool_use")
        | if .name == "EnterPlanMode" then "E"
          elif .name == "Skill" and ((.input.skill // "") | test("grill")) then "G"
          else empty end
      elif .type == "user" then
        (.message.content | if type == "string" then . else ([.[]? | .text? // empty] | join(" ")) end)
        | select(test("<command-name>/?[^<]*grill")) | "G"
      else empty end' "$tp" 2>/dev/null | tr -d '\n')
    # Plan mode entered with EnterPlanMode: the interview must come after the last entry.
    # Entered by hand (shift+tab, no EnterPlanMode call): any interview in the session counts.
    after=${seq##*E}
    if [[ "$after" != *G* ]]; then
      echo "lane-guard: antes de presentar el plan (Plan S o Plan L) hace falta la entrevista: cargá la skill \`mattpocock-skills:grilling\` y entrevistá al usuario con AskUserQuestion, una pregunta por vez, hasta que no quede nada por suponer. Recién después llamá a ExitPlanMode." >&2
      exit 2
    fi ;;
esac
exit 0
