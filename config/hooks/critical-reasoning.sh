#!/usr/bin/env bash
# UserPromptSubmit + PreToolUse(Edit|Write|MultiEdit): when the work looks costly to get
# wrong (architecture, unknown-cause bugs, security, migrations, prod/IAM), remind the main
# session to ask the one question Continuar / Plan S / Plan L before editing, and that in Plan L the
# decision goes to the `reasoner` subagent (Opus, effort high; ADRs 0018, 0022). Guidance only
# (additionalContext); never blocks, always exits 0.
# Silent: inside subagents, inside CAO panes (ADR 0020), in plan mode, and on task notifications.
# The reasoner reminder is sent once per session (needs a session_id); the skill hint is not capped.
#
# Also reads the project's .agents/critical.json (written by scripts/project-agents.sh from the
# installed packs): entries {skill, keywords (regex on the prompt), paths (regexes on the edited
# file)}. A match adds "read .claude/skills/<skill>/SKILL.md first" for that skill (max 2), only if
# the skill is installed in the project.
set -uo pipefail

input="$(cat 2>/dev/null || true)"
agent_type="$(jq -r '.agent_type // empty' <<<"$input" 2>/dev/null || true)"
[ -z "$agent_type" ] || exit 0  # already inside worker/scout/reasoner
[ -z "${CAO_TERMINAL_ID:-}" ] || exit 0  # caolg leader or worker: its profile and role decide

event="$(jq -r '.hook_event_name // empty' <<<"$input" 2>/dev/null || true)"
perm_mode="$(jq -r '.permission_mode // empty' <<<"$input" 2>/dev/null || true)"
sid="$(jq -r '.session_id // empty' <<<"$input" 2>/dev/null | tr -c 'A-Za-z0-9_\n-' '_')"
seen="${XDG_RUNTIME_DIR:-/tmp}/agents-intents/${sid:-nosession}/critical-reasoning"
reason=""
skills=""
proj="${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)}"
map="$proj/.agents/critical.json"

case "$event" in
  UserPromptSubmit)
    prompt="$(jq -r '.prompt // empty' <<<"$input" 2>/dev/null | tr '[:upper:]' '[:lower:]')"
    # Background-task notifications reach this hook as prompts (heuristic: no documented field).
    ! grep -Eq '<task-notification>|^\[system notification' <<<"$prompt" || exit 0
    re='arquitectur|architecture|dise(ñ|n)o de (api|base|schema|sistema)|api contract|contrato de api|migraci(ó|o)n|migration|seguridad|security|autenticaci|authenticat|authoriz|autorizaci|\biam\b|permisos|root cause|causa ra(í|i)z|no s(é|e) por qu(é|e)|race condition|deadlock|memory leak|producci(ó|o)n|\bprod\b|borrar (datos|la base)|drop table|rotar (credenciales|secretos)|breaking change|trade-?off'
    if grep -Eq "$re" <<<"$prompt"; then
      reason="el pedido toca una decisión crítica (arquitectura, seguridad, migración, causa desconocida o prod)"
    fi
    [ -f "$map" ] && skills="$(jq -r --arg p "$prompt" '[.[] | . as $e | select($e.keywords != null and (try ($p | test($e.keywords; "i")) catch false)) | $e.skill] | unique | .[]' "$map" 2>/dev/null || true)"
    ;;
  PreToolUse)
    f="$(jq -r '.tool_input.file_path // .tool_input.path // empty' <<<"$input" 2>/dev/null)"
    case "$f" in
      */migrations/*|*.sql|*/template.y*ml|*/samconfig.toml|*/auth/*|*auth*.ts|*guard*.ts|*/iam/*|*policy*.json|*.env|*.env.*|*/.github/workflows/*|*/prisma/schema.prisma)
        reason="se edita un archivo sensible ($f): migración, auth, IAM, infra o CI"
        ;;
    esac
    [ -f "$map" ] && [ -n "$f" ] && skills="$(jq -r --arg f "$f" '[.[] | select(any(.paths[]?; . as $r | try ($f | test($r)) catch false)) | .skill] | unique | .[]' "$map" 2>/dev/null || true)"
    ;;
esac

# Keep only skills actually installed in the project, at most two.
hint=""
n=0
while IFS= read -r sk; do
  [ -n "$sk" ] && [ -f "$proj/.claude/skills/$sk/SKILL.md" ] || continue
  n=$((n + 1)); [ "$n" -le 2 ] || break
  hint="$hint \`.claude/skills/$sk/SKILL.md\`"
done <<<"$skills"

# Plan mode already decides; and the reminder is sent once per session when there is a session id.
[ "$perm_mode" != "plan" ] || reason=""
if [ -n "$reason" ] && [ -n "$sid" ]; then
  if [ -e "$seen" ]; then reason=""; else mkdir -p "$(dirname "$seen")" 2>/dev/null && : >"$seen" 2>/dev/null; fi
fi

[ -n "$reason" ] || [ -n "$hint" ] || exit 0

msg=""
if [ -n "$reason" ]; then
  msg="Razonamiento crítico (agents-config): $reason. Esto parece Plan L: antes de editar, hacé una sola pregunta con las opciones Continuar / Plan S / Plan L, siempre en ese orden (marcá la que recomendás con \"(Recomendado)\" sin moverla). En Plan S y Plan L, la entrevista con `mattpocock-skills:grilling` es obligatoria antes del plan. En Plan L, la decisión de fondo va al subagente \`reasoner\` (Opus, effort high) con el contexto y la pregunta concreta. Si ya hay un plan aprobado para esto, ignorá este aviso."
fi
if [ -n "$hint" ]; then
  msg="${msg:+$msg }Skill del proyecto para esto: leé$hint antes de implementar."
fi
jq -n --arg c "$msg" --arg e "${event:-UserPromptSubmit}" \
  '{hookSpecificOutput:{hookEventName:$e,additionalContext:$c}}'
exit 0
