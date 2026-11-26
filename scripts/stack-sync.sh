#!/usr/bin/env bash
# stack-sync: keeps Loren's PR branches up to date, each one in its own worktree (ADR 0032, 0041, 0043-0045).
# For every open PR of mine in the repos found under the roots, bottom-up:
#   1. its base branch's PR is merged   -> merge origin/<the base that PR merged into, usually trunk>, push,
#      retarget the PR to that base
#   2. its base branch got new commits  -> merge origin/<base>, push
#   3. base is the trunk and the branch conflicts with it (GitHub says so, or the local merge does), or it is behind
#      and it is the next to merge (my oldest ready PR of that repo: lowest number, not a draft) -> merge
#      origin/<trunk>, push. Any other PR behind dev without a conflict is left alone (ADR 0049, adjusted 2026-11-24).
#   4. a merge conflicts -> abort, and open a Claude in that PR's worktree through Orca with a brief: resolve,
#      commit and push; only a real logic conflict runs the related tests, never the whole suite (ADR 0045). Once
#      per (PR, base commit); its tab stays open.
#   5. someone else left a review that asks for changes or comments, or a plain PR comment (not me, not a bot; the
#      newest of them by date), and no conflict agent is open for it -> open a Claude in that PR's
#      worktree with a brief: apply each point as new commits, keep line endings, bring the base before pushing,
#      push, and answer each comment with what changed (ADR 0047, 0049, 0058). It never resolves threads nor edits
#      the PR. Once per review or comment (by id); its tab stays open.
#      A review or comment on a PR without a local worktree is notified once.
#   6. a CI check failed on the PR head (and no conflict or review agent was opened for it in this run) -> open a
#      Claude in that PR's worktree: read the failed logs, fix, run only what is related, push (ADR 0048). Once per
#      (PR, head commit); its tab stays open.
# Every agent (4-6) goes through launch_agent (ADR 0050): one agent per worktree at a time (a busy mark the agent
# removes when it ends, stale after 60 min; it holds the worktree and its PR branch), at most 2 automatic attempts per PR and day (then Loren is notified
# once); conflicts and red CI run on Sonnet first and Opus second, review fixes always on Opus. Agents commit and
# push only through stack-sync-git.sh (ADR 0060): a work repo's `ask` rules on `git commit`/`git push` would stop
# them, and that command only works in a worktree with a live busy mark, to its PR branch, without force.
# Then, for every merged PR of mine with a linked worktree: remove the worktree and delete the branch, local and
# remote, when the worktree is clean, its HEAD is the merged head and no open PR is stacked on it.
# A clean worktree that is only behind the PR head is fast-forwarded first.
# Never: rebase, force, amend; never touches a worktree with uncommitted changes to tracked files (untracked
# ones, like a pnpm-lock.yaml, don't count) or one with commits not pushed: it skips it and says so.
# A merged worktree whose only untracked files are pnpm's (pnpm-lock.yaml, pnpm-workspace.yaml) is removed with
# --force; with any other untracked file it stays, and that is notified once, naming the file.
#
# Usage: stack-sync.sh [--dry-run] [--roots dir1:dir2] [--owner <gh-owner>] [--trunk dev]
#        stack-sync.sh --precheck   the Orca automation's precheck, every 2 min (ADR 0045): asks GitHub with an
#                                    ETag whether any PR of those repos changed (a 304 does not count against the
#                                    rate limit) and syncs only then, or every 30 min anyway. Always exits 1, so
#                                    the automation never starts an agent of its own: conflicts open their own.
# Config (not committed): ~/.config/stack-sync/config, sourced as shell, e.g.
#   STACK_SYNC_OWNER=<gh-owner>  STACK_SYNC_ROOTS=<dir>[:<dir>]  STACK_SYNC_TRUNK=dev  STACK_SYNC_ORCA=<orca cli>
# Without an owner and roots it does nothing.
# Env: STACK_SYNC_ROOTS, STACK_SYNC_OWNER, STACK_SYNC_TRUNK, STACK_SYNC_ORCA (default `orca`),
#      STACK_SYNC_STATE (default ~/.local/state/stack-sync), STACK_SYNC_NOTIFY=0 to skip notify-send.
set -uo pipefail

dry=0 precheck=0
cfg="${XDG_CONFIG_HOME:-$HOME/.config}/stack-sync/config"
# the environment wins over the config file (tests and one-off runs set it)
env_roots="${STACK_SYNC_ROOTS:-}" env_owner="${STACK_SYNC_OWNER:-}" env_trunk="${STACK_SYNC_TRUNK:-}" env_orca="${STACK_SYNC_ORCA:-}"
# shellcheck disable=SC1090
[ -r "$cfg" ] && . "$cfg"
roots="${env_roots:-${STACK_SYNC_ROOTS:-}}"
owner="${env_owner:-${STACK_SYNC_OWNER:-}}"
trunk="${env_trunk:-${STACK_SYNC_TRUNK:-dev}}"
orca="${env_orca:-${STACK_SYNC_ORCA:-orca}}"
state="${STACK_SYNC_STATE:-$HOME/.local/state/stack-sync}"
# the agents' only commit and push (ADR 0060), named by absolute path in every brief
sgit="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/stack-sync-git.sh"
SGIT_NOTE="Commit y push, **solo con \`$sgit\`**: el repo pide confirmación para \`git commit\` y \`git push\`, y esa
pregunta frena esta pestaña sin nadie que la conteste. Ese comando solo commitea con \`-m\` (o \`--no-edit\` en un
merge) y solo pushea a la rama de este PR. Si lo rechaza, no busques otra vía: escribilo en el reporte.
\`git add\` y el commit van en comandos separados, sin encadenar (tampoco \`&& git log\`)."
model1="${STACK_SYNC_MODEL1:-claude-sonnet-5-5}" model2="${STACK_SYNC_MODEL2:-claude-opus-5-5}"
max_attempts="${STACK_SYNC_MAX_ATTEMPTS:-2}" busy_minutes="${STACK_SYNC_BUSY_MINUTES:-60}"
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry=1 ;;
    --precheck) precheck=1 ;;
    --roots) roots="${2:-}"; shift ;;
    --owner) owner="${2:-}"; shift ;;
    --trunk) trunk="${2:-}"; shift ;;
  esac
  shift
done

# the precheck always says «nothing for the automation's agent» (1); a plain run says 0
done_code=0; [ "$precheck" -eq 1 ] && done_code=1
[ -n "$owner" ] && [ -n "$roots" ] || exit "$done_code"
mkdir -p "$state/failed" "$state/specs" "$state/blocked" "$state/busy" "$state/attempts"
log="$state/stack-sync.log"
exec 9>"$state/lock"
flock -n 9 || exit "$done_code" # another run is still going

summary=()
say() { summary+=("$1"); printf '%s %s\n' "$(date '+%F %T')" "$1" >>"$log"; }
# a skip is only logged (and printed on a manual run): a run every 2 min must not notify the same skip
skips=()
note() { skips+=("$1"); printf '%s %s\n' "$(date '+%F %T')" "$1" >>"$log"; }
# untracked files that never stop removing a merged worktree: pnpm leaves them in repos that use npm
regenerable='pnpm-lock\.yaml|pnpm-workspace\.yaml'
# blocked <slug> <pr> <msg>: a merged worktree that cannot be removed is notified once (say), not every 2 min;
# it is notified again only if what blocks it changes
blocked() {
  local mark="$state/blocked/${1//\//_}-$2"
  if [ "$(cat "$mark" 2>/dev/null)" = "$3" ]; then return 0; fi
  printf '%s' "$3" >"$mark"; say "$3"
}
# gh with color off: some shells force it (GH_FORCE_TTY, CLICOLOR_FORCE) and jq cannot read ANSI codes
tgh() { env -u GH_FORCE_TTY NO_COLOR=1 CLICOLOR_FORCE=0 timeout 30 gh "$@"; }

# branch -> worktree path, for every repo of $owner under the roots
declare -A wt slug_of
scan_repo() {
  local any="$1" url slug porcelain path branch line
  url="$(git -C "$any" config --get remote.origin.url 2>/dev/null)" || return 0
  slug="$(printf '%s' "$url" | sed -nE 's#^.*github\.com[:/]+([^/]+/[^/]+)$#\1#p' | sed -E 's#\.git$##')"
  case "$slug" in "$owner"/*) ;; *) return 0 ;; esac
  porcelain="$(git -C "$any" worktree list --porcelain 2>/dev/null)" || return 0
  path=""
  while IFS= read -r line; do
    case "$line" in
      "worktree "*) path="${line#worktree }" ;;
      "branch refs/heads/"*) branch="${line#branch refs/heads/}"; [ -d "$path" ] && wt["$slug|$branch"]="$path" ;;
    esac
  done <<<"$porcelain"
  slug_of["$slug"]=1
}
IFS=: read -r -a root_list <<<"$roots"
for r in "${root_list[@]}"; do
  [ -d "$r" ] || continue
  while IFS= read -r g; do scan_repo "$(dirname "$g")"; done < <(find "$r" -maxdepth 3 -name .git -type d 2>/dev/null)
done

last="$state/last-full-sync"
# --precheck: sync only when a PR of these repos changed (ETag; 304 = nothing new) or 30 min passed
if [ "$precheck" -eq 1 ]; then
  changed=0
  [ -e "$last" ] && [ -n "$(find "$last" -mmin -30 2>/dev/null)" ] || changed=1
  for slug in "${!slug_of[@]}"; do
    etag_file="$state/etag-${slug//\//_}"
    etag="$(cat "$etag_file" 2>/dev/null)"
    head="$(tgh api -i "repos/$slug/pulls?state=all&sort=updated&direction=desc&per_page=1" \
      ${etag:+-H "If-None-Match: $etag"} 2>/dev/null | sed -n '1,/^\r\{0,1\}$/p')"
    case "$head" in
      *" 304"*) ;;
      *" 200"*) changed=1
        printf '%s' "$(sed -nE 's/^[Ee][Tt][Aa][Gg]: *([^\r]*)\r?$/\1/p' <<<"$head")" >"$etag_file" ;;
      *) changed=1 ;; # no answer: sync anyway, a missed merge costs more than one run
    esac
  done
  [ "$changed" -eq 1 ] || exit 1
fi
: >"$last" # any full sync counts for the 30-min floor of --precheck

# merge_and_push <slug> <pr> <branch> <path> <ref-to-merge> <reason> [retarget]
merge_and_push() {
  local slug="$1" pr="$2" branch="$3" path="$4" ref="$5" why="$6" retarget="${7:-}"
  if [ "$dry" -eq 1 ]; then
    say "dry-run: #$pr ($slug, $branch): $why -> merge $ref${retarget:+, retarget a $retarget}"
    return 0
  fi
  if git -C "$path" merge --no-edit "$ref" >/dev/null 2>&1; then
    if git -C "$path" push -q origin "HEAD:$branch" 2>/dev/null; then
      [ -n "$retarget" ] && tgh pr edit "$pr" --repo "$slug" --base "$retarget" >/dev/null 2>&1
      say "#$pr ($slug, $branch): $why -> mergeado $ref y pusheado${retarget:+; base -> $retarget}"
    else
      say "#$pr ($slug, $branch): mergeé $ref pero el push falló; queda local en $path"
    fi
    return 0
  fi
  git -C "$path" merge --abort >/dev/null 2>&1
  launch_resolver "$slug" "$pr" "$branch" "$path" "$ref" "$why"
}

# busy_mark <slug> <pr>: the file that says an agent is working in that PR's worktree
busy_mark() { printf '%s/busy/%s-%s' "$state" "${1//\//_}" "$2"; }
# is_busy <slug> <pr>: an agent was launched there less than $busy_minutes ago and has not finished
is_busy() { local m; m="$(busy_mark "$1" "$2")"; [ -e "$m" ] && [ -n "$(find "$m" -mmin "-$busy_minutes" 2>/dev/null)" ]; }

# launch_agent <slug> <pr> <path> <spec> [kind]: 0 launched, 1 Orca failed, 2 skipped (busy or out of attempts)
launch_agent() {
  local slug="$1" pr="$2" path="$3" spec="$4" kind="${5:-}" counter n model effort lock branch
  is_busy "$slug" "$pr" && { note "#$pr ($slug): ya hay un agente en $path; espera"; return 2; }
  counter="$state/attempts/${slug//\//_}-$pr-$(date +%F)"
  n="$(wc -l <"$counter" 2>/dev/null || echo 0)"
  if [ "$n" -ge "$max_attempts" ]; then
    blocked "$slug" "$pr" "#$pr ($slug): ya hubo $n intentos automáticos hoy; lo que falta queda para vos"
    return 2
  fi
  model="$model1"; effort=""
  # una review puede tocar lógica de fondo: va siempre en Opus
  { [ "$n" -ge 1 ] || [ "$kind" = review ]; } && { model="$model2"; effort="high"; }
  lock="$(busy_mark "$slug" "$pr")"
  printf '\n\nAl terminar, salga bien o mal, borrá la marca de ocupado: `rm -f %s`.\n' "$lock" >>"$spec"
  # the mark goes before the launch: stack-sync-git.sh reads the worktree and the PR branch from it (ADR 0060)
  branch="$(git -C "$path" symbolic-ref --short HEAD 2>/dev/null)"
  printf '%s\t%s\n' "$path" "$branch" >"$lock"
  if "$orca" agent launch --agent claude --worktree "path:$path" --surface terminal --model "$model" \
      ${effort:+--effort "$effort"} --prompt "$(cat "$spec")" --json >/dev/null 2>&1; then
    echo "$model" >>"$counter"
    return 0
  fi
  rm -f "$lock"
  return 1
}

# launch_resolver: a Claude in that PR's worktree, through Orca, once per (PR, base commit)
launch_resolver() {
  local slug="$1" pr="$2" branch="$3" path="$4" ref="$5" why="$6"
  local refsha mark spec fail
  busy=1 # a conflict agent owns this worktree: no review agent on top of it in this run
  refsha="$(git -C "$path" rev-parse --short "$ref" 2>/dev/null)"
  mark="$state/launched-${slug//\//_}-$pr-$refsha"
  if [ -e "$mark" ]; then note "#$pr ($slug): conflicto con $ref ya tiene un agente; espera"; return 0; fi
  [ "$dry" -eq 1 ] && { say "dry-run: #$pr ($slug): conflicto con $ref -> abriría un Claude en $path"; return 0; }
  spec="$state/specs/${slug//\//_}-$pr.md"
  fail="$state/failed/${slug//\//_}-$pr.md"
  cat >"$spec" <<EOF
# Resolver conflictos de merge (stack-sync)

Esto es un brief: ejecutalo sin la pregunta de carril ni la de Continuar/Orquestar.

Estás en el worktree del PR #$pr de $slug (\`$path\`, rama \`$branch\`). No toques ningún otro worktree. Leé el
\`AGENTS.md\`/\`CLAUDE.md\` del repo antes.

Motivo: $why. Hay que traer \`$ref\` a esta rama y da conflictos.

1. \`git fetch origin\` y \`git merge --no-edit $ref\`.
2. Resolvé cada conflicto conservando lo de los dos lados (la rama trae su cambio; \`$ref\` trae lo ya
   mergeado). Si un conflicto pide una decisión de producto, no la tomes: \`git merge --abort\` y reportá.
3. La resolución tiene que ser rápida: **no corras lint, typecheck ni la suite entera.**
   - Conflicto trivial (doc, listas o tablas donde los dos agregaron, imports, lockfiles, archivos generados):
     resolvé y seguí al paso 4 sin correr nada.
   - Conflicto real (los dos cambiaron la misma lógica): corré solo los tests relacionados con los archivos que
     chocaron (\`npx jest --findRelatedTests <archivos>\` en el back, \`npx vitest related --run <archivos>\` en el
     front). Si el merge cambió el schema de Prisma, antes el \`prisma generate\` del CI del repo (hoy \`npx prisma generate\`; no toca la base).
4. \`git add\` de los archivos resueltos, \`$sgit commit --no-edit\` (commit del merge) y \`$sgit push\` (a
   \`$branch\`, sin force). No edites el PR: si su base cambia, stack-sync lo retargetea solo.
5. Nunca rebase, force, amend ni \`--no-verify\`.

$SGIT_NOTE

Si abortaste, fallaron los checks o el push, escribí el motivo en una línea en \`$fail\`. Al terminar, avisá con
\`notify-send "stack-sync: PR #$pr" "<resultado en una línea>"\` y dejá acá qué conflictos había, cómo los
resolviste y, si corriste tests, su salida. Esta pestaña queda abierta para que Loren lo lea.
EOF
  launch_agent "$slug" "$pr" "$path" "$spec"
  case $? in
    0) : >"$mark"; say "#$pr ($slug, $branch): conflicto con $ref -> abrí un Claude en su worktree ($path)" ;;
    1) say "#$pr ($slug, $branch): conflicto con $ref, pero no pude abrir el agente en Orca; reintento en la próxima corrida" ;;
  esac
}

# last_review <pr> <open-json>: id and author of the newest review (asking for changes or commenting) or PR comment
# by someone else, by date (ADR 0047, 0058). Bots are left out only from the comments: gh drops the [bot] suffix
# there (`vercel`), so a few known logins are listed too.
last_review() {
  jq -r --argjson n "$1" '.[] | select(.number == $n) | .author.login as $me
    | [(.reviews[]? | select(.state == "CHANGES_REQUESTED" or .state == "COMMENTED") | . + {at: .submittedAt}),
       (.comments[]? | (.author.login // "") as $l
        | select(($l | endswith("[bot]")) or ($l | IN("github-actions", "vercel", "dependabot", "renovate", "codecov")) | not)
        | . + {at: .createdAt})]
    | map(select(.author.login != $me))
    | sort_by(.at // "") | last // empty | [.id, .author.login] | @tsv' <<<"$2" 2>/dev/null
}

# fix_review <slug> <pr> <branch> <path> <review-id> <reviewer> <base>: a Claude in that PR's worktree, once per review or comment
fix_review() {
  local slug="$1" pr="$2" branch="$3" path="$4" rid="$5" who="$6" base="$7" mark spec fail
  mark="$state/review-${slug//\//_}-$pr-$rid"
  [ -e "$mark" ] && return 0
  [ "$dry" -eq 1 ] && { say "dry-run: #$pr ($slug): review de $who -> abriría un Claude en $path"; return 0; }
  spec="$state/specs/${slug//\//_}-$pr-review.md"
  fail="$state/failed/${slug//\//_}-$pr-review.md"
  cat >"$spec" <<EOF
# Corregir lo que pidió la review (stack-sync)

Esto es un brief: ejecutalo sin la pregunta de carril ni la de Continuar/Orquestar.

Estás en el worktree del PR #$pr de $slug (\`$path\`, rama \`$branch\`). No toques ningún otro worktree. Leé el
\`AGENTS.md\`/\`CLAUDE.md\` del repo (y el de la carpeta de arriba, si hay) y usá sus skills: en un front, las de UI
del repo y la librería de componentes primero.

$who dejó una review o un comentario en el PR (\`$rid\`). Leelo entero:
- \`gh pr view $pr --repo $slug --json reviews,comments\` (el cuerpo de cada review y los comentarios del PR);
- \`gh api repos/$slug/pulls/$pr/comments --paginate\` (los comentarios en líneas del código).

1. \`git fetch origin\`. Por cada punto pedido, el cambio más chico que lo resuelva, como commits nuevos en esta
   rama: \`git add\` y \`$sgit commit -m "<mensaje>"\` (Conventional Commits en español, con la clave del ticket si
   el PR la tiene; sin atribución).
2. Si un punto pide una decisión de producto o no está claro, no lo adivines: dejalo sin tocar y anotalo.
3. Si un punto pide cambiar el título o la descripción del PR, no lo edites: dejá el texto nuevo acá.
4. **Fines de línea**: cada archivo conserva los suyos (CRLF o LF). Antes de commitear,
   \`diff <(git diff --numstat HEAD) <(git diff --numstat --ignore-cr-at-eol HEAD)\` no tiene que mostrar nada;
   si muestra un archivo, devolvele sus fines de línea originales.
5. Rápido: **no corras la suite entera**. Solo lint de los archivos tocados y los tests relacionados
   (\`npx vitest related --run <archivos>\` en el front, \`npx jest --findRelatedTests <archivos>\` en el back).
6. Antes de pushear, \`git fetch origin && git merge --no-edit origin/$base\`. Si hay conflictos, resolvelos
   conservando los dos lados, \`git add\` y \`$sgit commit --no-edit\`.
7. \`$sgit push\` (a \`$branch\`, sin force). Nunca rebase, force, amend ni \`--no-verify\`.
8. Contestá cada comentario, en español y corto: qué cambiaste y en qué commit, o por qué no.
   - En una línea del código: \`gh api repos/$slug/pulls/$pr/comments/<id>/replies -f body="…"\`.
   - El cuerpo de la review o un comentario suelto del PR: \`gh pr comment $pr --repo $slug --body "…"\`, punto por
     punto.
9. No resuelvas los hilos, no edites el PR y no toques Jira ni Slack.

$SGIT_NOTE

Si no pudiste resolver algún punto o falló el push, escribí el motivo en una línea en \`$fail\`. Al terminar,
avisá con \`notify-send "stack-sync: review en #$pr" "<resultado en una línea>"\`. Esta pestaña queda abierta.
EOF
  launch_agent "$slug" "$pr" "$path" "$spec" review
  case $? in
    0) : >"$mark"; say "#$pr ($slug, $branch): review de $who -> abrí un Claude en su worktree ($path)" ;;
    1) say "#$pr ($slug, $branch): review de $who, pero no pude abrir el agente en Orca; reintento en la próxima corrida" ;;
  esac
}

# failed_checks <pr> <open-json>: names of the CI checks that failed on the PR head, comma separated
failed_checks() {
  jq -r --argjson n "$1" '.[] | select(.number == $n)
    | [.statusCheckRollup[]? | select((.conclusion // .state // "") | test("^(FAILURE|ERROR|TIMED_OUT|STARTUP_FAILURE)$"))
       | (.name // .context // "check")] | unique | join(", ")' <<<"$2" 2>/dev/null
}

# fix_ci <slug> <pr> <branch> <path> <head-oid> <checks> <base>: a Claude in that PR's worktree, once per (PR, head)
fix_ci() {
  local slug="$1" pr="$2" branch="$3" path="$4" oid="$5" checks="$6" base="$7" mark spec fail
  mark="$state/ci-${slug//\//_}-$pr-${oid:0:12}"
  [ -e "$mark" ] && return 0
  [ "$dry" -eq 1 ] && { say "dry-run: #$pr ($slug): CI en rojo ($checks) -> abriría un Claude en $path"; return 0; }
  spec="$state/specs/${slug//\//_}-$pr-ci.md"
  fail="$state/failed/${slug//\//_}-$pr-ci.md"
  cat >"$spec" <<EOF
# Arreglar el CI en rojo (stack-sync)

Esto es un brief: ejecutalo sin la pregunta de carril ni la de Continuar/Orquestar.

Estás en el worktree del PR #$pr de $slug (\`$path\`, rama \`$branch\`). No toques ningún otro worktree. Leé el
\`AGENTS.md\`/\`CLAUDE.md\` del repo (y el de la carpeta de arriba, si hay) y usá sus skills.

Fallaron estos checks del CI sobre la punta del PR: $checks.

1. \`gh pr checks $pr --repo $slug\` y, por cada uno en rojo, \`gh run view <run-id> --repo $slug --log-failed\`.
2. Si la falla no viene del código del PR (un servicio caído, un flaky, un secreto del CI), no cambies nada:
   \`gh run rerun <run-id> --repo $slug --failed\` una vez y reportá.
3. Si viene del código: el cambio más chico que la arregle, como commit nuevo: \`git add\` y
   \`$sgit commit -m "<mensaje>"\` (Conventional Commits en español, con la clave del ticket si el PR la tiene; sin
   atribución). Cada archivo conserva sus fines de línea:
   \`diff <(git diff --numstat HEAD) <(git diff --numstat --ignore-cr-at-eol HEAD)\` no muestra nada.
4. Corré solo lo que falló, localmente (el mismo comando del CI sobre los archivos tocados, o los tests
   relacionados), no la suite entera.
5. Antes de pushear, \`git fetch origin && git merge --no-edit origin/$base\`; si hay conflictos, resolvelos,
   \`git add\` y \`$sgit commit --no-edit\`.
6. \`$sgit push\` (a \`$branch\`, sin force). Nunca rebase, force, amend ni \`--no-verify\`. No edites el PR ni
   toques Jira o Slack.

$SGIT_NOTE

Si no pudiste arreglarlo, escribí el motivo en una línea en \`$fail\`. Al terminar, avisá con
\`notify-send "stack-sync: CI en #$pr" "<resultado en una línea>"\` y dejá acá la causa y el arreglo. Esta pestaña
queda abierta.
EOF
  launch_agent "$slug" "$pr" "$path" "$spec"
  case $? in
    0) : >"$mark"; say "#$pr ($slug, $branch): CI en rojo ($checks) -> abrí un Claude en su worktree ($path)" ;;
    1) say "#$pr ($slug, $branch): CI en rojo, pero no pude abrir el agente en Orca; reintento en la próxima corrida" ;;
  esac
}

# clean_merged <slug> <open-json>: remove the worktree and the branch of my merged PRs
clean_merged() {
  local slug="$1" open="$2" merged pr head oid path common blockers
  merged="$(tgh pr list --repo "$slug" --author @me --state merged --limit 30 \
    --json number,headRefName,headRefOid 2>/dev/null)" || return 0
  while IFS=$'\t' read -r pr head oid; do
    [ -n "$pr" ] || continue
    path="${wt["$slug|$head"]:-}"
    [ -n "$path" ] || continue
    [ -f "$path/.git" ] || continue # the main checkout (.git is a dir) is never removed
    if jq -e --arg h "$head" 'any(.[]; .baseRefName == $h)' <<<"$open" >/dev/null 2>&1; then
      note "#$pr ($slug, $head): mergeado, pero hay un PR apilado encima; el worktree espera"; continue
    fi
    if [ -n "$(git -C "$path" status --porcelain --untracked-files=no 2>/dev/null)" ]; then
      note "#$pr ($slug, $head): mergeado, pero $path tiene cambios sin commitear; no lo borro"; continue
    fi
    if [ "$(git -C "$path" rev-parse HEAD 2>/dev/null)" != "$oid" ]; then
      note "#$pr ($slug, $head): mergeado, pero $path tiene commits que no están en el PR; no lo borro"; continue
    fi
    [ "$dry" -eq 1 ] && { say "dry-run: #$pr ($slug, $head): mergeado -> borraría $path y la rama local y remota"; continue; }
    common="$(cd "$path" && cd "$(git rev-parse --git-common-dir)/.." && pwd)"
    if ! "$orca" worktree rm --worktree "path:$path" --json >/dev/null 2>&1 &&
       ! git -C "$common" worktree remove "$path" >/dev/null 2>&1; then
      # git no borra un worktree con archivos sin trackear. Si son solo los que pnpm regenera (en repos
      # que usan npm), se fuerza; con cualquier otro archivo se deja y se avisa una vez qué lo frena.
      blockers="$(git -C "$path" ls-files --others --exclude-standard 2>/dev/null | grep -vxE "$regenerable")"
      if [ -z "$blockers" ] && git -C "$common" worktree remove --force "$path" >/dev/null 2>&1; then
        :
      else
        blocked "$slug" "$pr" "#$pr ($slug, $head): mergeado, pero no pude borrar $path${blockers:+; lo frena: $(tr '\n' ' ' <<<"$blockers")}"
        continue
      fi
    fi
    rm -f "$state/blocked/${slug//\//_}-$pr"
    git -C "$common" branch -D "$head" >/dev/null 2>&1
    git -C "$common" ls-remote --exit-code --heads origin "$head" >/dev/null 2>&1 &&
      git -C "$common" push -q origin --delete "$head" >/dev/null 2>&1
    unset 'wt[$slug|$head]'
    say "#$pr ($slug, $head): mergeado -> borré el worktree y la rama local y remota"
  done < <(jq -r '.[] | [.number, .headRefName, .headRefOid] | @tsv' <<<"$merged" 2>/dev/null)
}

# PRs, bottom-up: trunk-based first, then those stacked on them (depth by base chain)
for slug in "${!slug_of[@]}"; do
  json="$(tgh pr list --repo "$slug" --author @me --state open --limit 100 \
    --json number,headRefName,baseRefName,mergeable,headRefOid,isDraft,author,reviews,comments,statusCheckRollup 2>/dev/null)" || continue
  [ -n "$json" ] || continue
  # El próximo a mergearse: mi PR listo (no borrador) más viejo contra el trunk. Solo ese recibe dev sin choque.
  next="$(jq -r --arg t "$trunk" '[.[] | select((.baseRefName == $t or .baseRefName == "main" or .baseRefName == "master")
    and (.isDraft // false) == false) | .number] | min // empty' <<<"$json")"
  rows="$(jq -r --arg t "$trunk" '
    (map({key: .headRefName, value: .baseRefName}) | from_entries) as $base
    | def depth($b; $n): if ($base[$b] // null) == null or $n > 20 then $n else depth($base[$b]; $n + 1) end;
    map(. + {d: depth(.baseRefName; 0)}) | sort_by(.d)[]
    | [.number, .headRefName, .baseRefName, .mergeable, .headRefOid, (.isDraft // false)] | @tsv' <<<"$json")"
  while IFS=$'\t' read -r pr head base mergeable oid draft; do
    [ -n "$pr" ] || continue
    path="${wt["$slug|$head"]:-}"
    if [ -z "$path" ]; then # no local worktree for this branch: only a new review is worth a notice
      IFS=$'\t' read -r rid who <<<"$(last_review "$pr" "$json")"
      [ -n "${rid:-}" ] && blocked "$slug" "$pr" "#$pr ($slug, $head): review de $who, pero no hay worktree local para corregirla"
      continue
    fi
    # an agent is working there: no merges and no other agent until it ends
    is_busy "$slug" "$pr" && { note "#$pr ($slug, $head): salteado, hay un agente trabajando en $path"; continue; }
    busy=0
    git -C "$path" fetch -q origin 2>/dev/null || { note "#$pr ($slug): fetch falló"; continue; }
    # -uno: un archivo sin trackear (el pnpm-lock.yaml que deja pnpm) no frena el merge; uno trackeado sí
    if [ -n "$(git -C "$path" status --porcelain --untracked-files=no 2>/dev/null)" ]; then
      note "#$pr ($slug, $head): salteado, $path tiene cambios sin commitear"; continue
    fi
    # Limpio y solo atrasado (el remoto tiene commits que el worktree no): fast-forward y sigue. Antes se salteaba
    # en cada pasada y el PR quedaba trabado. Con commits sin pushear no se toca.
    if [ "$(git -C "$path" rev-parse HEAD)" != "$oid" ] && git -C "$path" merge-base --is-ancestor HEAD "$oid" 2>/dev/null; then
      [ "$dry" -eq 1 ] && { say "dry-run: #$pr ($slug, $head): atrasado -> fast-forward a la punta del PR"; continue; }
      git -C "$path" merge -q --ff-only "$oid" 2>/dev/null && say "#$pr ($slug, $head): atrasado -> fast-forward a la punta del PR"
    fi
    if [ "$(git -C "$path" rev-parse HEAD)" != "$oid" ]; then
      note "#$pr ($slug, $head): salteado, $path no está en la punta del PR (commits sin pushear)"; continue
    fi
    if [ "$base" = "$trunk" ] || [ "$base" = main ] || [ "$base" = master ]; then
      # La base se trae solo si choca o si el PR es el próximo a mergearse: traerla en cada pasada llenaba los PR
      # de merges y volvía a correr el CI sin necesidad (ADR 0049, ajuste del 2026-11-24). El choque se detecta por
      # GitHub o, si todavía dice UNKNOWN, con un merge de prueba sin tocar el worktree. Un choque lo resuelve el
      # agente de merge_and_push.
      if ! git -C "$path" merge-base --is-ancestor "origin/$base" HEAD; then
        if [ "$draft" != true ] && [ "$pr" = "$next" ]; then
          merge_and_push "$slug" "$pr" "$head" "$path" "origin/$base" "atrás de $base (es el próximo a mergearse)"
        elif [ "$mergeable" = CONFLICTING ] ||
             ! git -C "$path" merge-tree --write-tree HEAD "origin/$base" >/dev/null 2>&1; then
          merge_and_push "$slug" "$pr" "$head" "$path" "origin/$base" "choca con $base"
        else
          note "#$pr ($slug, $head): atrás de $base sin choque y no es el próximo a mergearse (#${next:-ninguno}), no se trae"
        fi
      elif [ "$mergeable" = CONFLICTING ]; then
        merge_and_push "$slug" "$pr" "$head" "$path" "origin/$base" "choca con $base"
      fi
    else
      # El PR de abajo se mergea a su propia base, que no siempre es el trunk (alguien puede mergearlo sobre la
      # rama de más abajo): se trae y se retargetea a esa base, no al trunk.
      IFS=$'\t' read -r merged mbase <<<"$(tgh pr list --repo "$slug" --head "$base" --state merged --json number,baseRefName --limit 1 2>/dev/null |
        jq -r '.[0] // empty | "\(.number)\t\(.baseRefName // "")"')"
      mbase="${mbase:-$trunk}"
      if [ -n "$merged" ]; then
        merge_and_push "$slug" "$pr" "$head" "$path" "origin/$mbase" "el PR de abajo (#$merged, $base) se mergeó a $mbase" "$mbase"
      elif git -C "$path" rev-parse -q --verify "origin/$base" >/dev/null &&
           ! git -C "$path" merge-base --is-ancestor "origin/$base" HEAD; then
        merge_and_push "$slug" "$pr" "$head" "$path" "origin/$base" "la rama de abajo ($base) tiene cambios nuevos"
      fi
    fi
    [ "$busy" -eq 1 ] && continue
    IFS=$'\t' read -r rid who <<<"$(last_review "$pr" "$json")"
    if [ -n "${rid:-}" ] && [ ! -e "$state/review-${slug//\//_}-$pr-$rid" ]; then
      fix_review "$slug" "$pr" "$head" "$path" "$rid" "$who" "$base"; continue
    fi
    checks="$(failed_checks "$pr" "$json")"
    [ -n "$checks" ] && fix_ci "$slug" "$pr" "$head" "$path" "$oid" "$checks" "$base"
  done <<<"$rows"
  clean_merged "$slug" "$json"
done

[ "${#skips[@]}" -gt 0 ] && { [ -t 1 ] || [ "$dry" -eq 1 ]; } && printf '%s\n' "${skips[@]}"
if [ "${#summary[@]}" -gt 0 ]; then
  printf '%s\n' "${summary[@]}"
  if [ "$dry" -eq 0 ] && [ "${STACK_SYNC_NOTIFY:-1}" != 0 ] && command -v notify-send >/dev/null 2>&1; then
    notify-send "stack-sync" "$(printf '%s\n' "${summary[@]}")" 2>/dev/null
  fi
elif [ "$dry" -eq 1 ] && [ "${#skips[@]}" -eq 0 ]; then
  echo "stack-sync: nada que hacer"
fi
exit "$done_code"
