#!/usr/bin/env bash
# PostToolUse(AskUserQuestion) hook (ADR 0039): when the user picks «Orquestar», inject the fixed
# orchestration procedure, so every run is handled the same way instead of being improvised.
# Only reacts to a real answer that starts with "Orquestar"; anything else is a no-op.
# Subagents are not checked (they never orchestrate).
set -uo pipefail

input=$(cat)
[ -n "$(jq -r '.agent_type // empty' <<<"$input")" ] && exit 0
[ "$(jq -r '.tool_name // empty' <<<"$input")" = "AskUserQuestion" ] || exit 0

# The answer can come as an object ({answers: {question: label}}) or as the text Claude Code writes
# back ("…"="Orquestar (Recomendado)"…). Both are read; only the picked labels count, never the options.
picked=$(jq -r '
  .tool_response
  | if type == "object" then [(.answers // {})[]?]
    elif type == "string" then [scan("=\"([^\"]*)\"")[0]]
    else [] end
  | map(select(type == "string") | ascii_downcase | select(startswith("orquestar")))
  | length' <<<"$input" 2>/dev/null)
[ "${picked:-0}" != 0 ] || exit 0

read -r -d '' context <<'EOF'
Orquestar elegido (ADR 0036, 0039). Procedimiento fijo, sin variantes:
1. Esta sesión coordina y no escribe el código de los tickets. Antes de repartir: lee cada ticket y lo pasa a «In Progress», fija el contrato si el trabajo cruza back y front (el back lo define), y crea una rama + worktree por ticket y repo, desde la base que no genere conflictos (`origin/dev`, o apilada sobre el PR abierto que comparte archivos). Si el repo tiene una skill de orquestación (en CX, `cx-orquestar`), la sigue.
2. Un líder por worktree, como sesión aparte y no como subagente de esta sesión: Opus (el modelo de líder del perfil), con el contexto de su repo, que puede lanzar sus propios `worker`, `scout` y su reviewer. Transporte: en Orca, `orchestration worker-start --spec-file <brief> --worktree branch:<rama> --agent claude --model <modelo de líder> --keep-open` (skill `orchestration`); en T3 Code, `t3_thread_launch` en el proyecto del repo; sin ninguno de los dos, avisar al usuario antes de usar un subagente.
3. Los independientes arrancan en paralelo. Lo que depende de un contrato (el front de un ticket cuyo back lo define) arranca cuando ese contrato está commiteado.
4. Brief por líder: el ticket textual, el contrato, los archivos a tocar, las reglas y skills del repo con su ruta, los checks con su comando exacto, y «commit en la rama con su reviewer; sin push, sin PR, sin Jira». Entrega: hash del commit, archivos, salida real de los checks, hallazgos del reviewer, lo que quedó abierto.
5. Lanzados los líderes, terminar el turno: el harness despierta a esta sesión. Nunca pollear.
6. Al volver cada líder: revisar su diff y su evidencia, y recién ahí mostrar push y PR al usuario para su OK, ticket por ticket.
Antes de lanzar cada líder, aprobar los imports externos de su worktree con `bash __HUB__/scripts/approve-claude-imports.sh <worktree>` (el usuario lo autorizó para todo worktree nuevo, 2026-11-19): sin eso la sesión frena en «Allow external CLAUDE.md file imports?», que el bypass de permisos no saltea. Nunca se contesta ese aviso por la terminal del líder.
EOF

# The approval script lives in the hub; ~/.claude/hooks is a symlink to its config/hooks.
hub=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)
context=${context//__HUB__/$hub}

jq -n --arg c "$context" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $c}}'
exit 0
