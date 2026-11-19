#!/usr/bin/env bash
# stack-sync: keeps Loren's PR branches up to date, each one in its own worktree (ADR 0032, 0041-0043).
# For every open PR of mine in the repos found under the roots, bottom-up:
#   1. its base branch's PR is merged   -> merge origin/<trunk>, push, retarget the PR to <trunk>
#   2. its base branch got new commits  -> merge origin/<base>, push
#   3. base is the trunk and the PR conflicts with it -> merge origin/<trunk>, push
#   4. a merge conflicts -> abort, and queue a brief in $state/queue/ for the Orca automation (ADR 0043),
#      whose Claude resolves it, runs the checks, commits and leaves a marker with its commit; queued once
#      per (PR, base commit). `--pending` exits 0 when the queue has work: the automation's precheck.
#   5. a worktree ahead of its PR with that marker -> push it (the agent never pushes: ADR 0042), then go on
#      with 1-3 (a stacked PR still gets retargeted).
# Never: rebase, force, amend; never touches a worktree with uncommitted changes to tracked
# files (untracked ones, like a pnpm-lock.yaml, don't count) or one whose HEAD is not the PR head (local
# commits not pushed, or behind): it skips it and says so. Only the worktree of that branch is touched.
#
# Usage: stack-sync.sh [--dry-run] [--roots dir1:dir2] [--owner <gh-owner>] [--trunk dev]
#        stack-sync.sh --pending   (exit 0 if a conflict waits in the queue, 1 if not; changes nothing)
# Config (not committed): ~/.config/stack-sync/config, sourced as shell, e.g.
#   STACK_SYNC_OWNER=<gh-owner>  STACK_SYNC_ROOTS=<dir>[:<dir>]  STACK_SYNC_TRUNK=dev
# Without an owner and roots it does nothing.
# Env: STACK_SYNC_ROOTS, STACK_SYNC_OWNER, STACK_SYNC_TRUNK, STACK_SYNC_STATE (default ~/.local/state/stack-sync),
#      STACK_SYNC_NOTIFY=0 to skip notify-send.
set -uo pipefail

dry=0
cfg="${XDG_CONFIG_HOME:-$HOME/.config}/stack-sync/config"
# the environment wins over the config file (tests and one-off runs set it)
env_roots="${STACK_SYNC_ROOTS:-}" env_owner="${STACK_SYNC_OWNER:-}" env_trunk="${STACK_SYNC_TRUNK:-}"
# shellcheck disable=SC1090
[ -r "$cfg" ] && . "$cfg"
roots="${env_roots:-${STACK_SYNC_ROOTS:-}}"
owner="${env_owner:-${STACK_SYNC_OWNER:-}}"
STACK_SYNC_TRUNK="${env_trunk:-${STACK_SYNC_TRUNK:-}}"
trunk="${STACK_SYNC_TRUNK:-dev}"
state="${STACK_SYNC_STATE:-$HOME/.local/state/stack-sync}"
pending=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry=1 ;;
    --pending) pending=1 ;;
    --roots) roots="${2:-}"; shift ;;
    --owner) owner="${2:-}"; shift ;;
    --trunk) trunk="${2:-}"; shift ;;
  esac
  shift
done

# precheck of the Orca automation: is there a conflict waiting? (no lock, no network)
if [ "$pending" -eq 1 ]; then compgen -G "$state/queue/*.md" >/dev/null; exit $?; fi
[ -n "$owner" ] && [ -n "$roots" ] || exit 0
mkdir -p "$state/queue" "$state/failed"
log="$state/stack-sync.log"
exec 9>"$state/lock"
flock -n 9 || exit 0 # another run is still going

summary=()
say() { summary+=("$1"); printf '%s %s\n' "$(date '+%F %T')" "$1" >>"$log"; }
# a skip is only logged (and printed on a manual run): a timer every 10 min must not notify the same skip
skips=()
note() { skips+=("$1"); printf '%s %s\n' "$(date '+%F %T')" "$1" >>"$log"; }
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
  queue_resolver "$slug" "$pr" "$branch" "$path" "$ref" "$why" "$retarget"
}

queue_resolver() {
  local slug="$1" pr="$2" branch="$3" path="$4" ref="$5" why="$6" retarget="$7"
  local refsha mark spec
  refsha="$(git -C "$path" rev-parse --short "$ref" 2>/dev/null)"
  mark="$state/launched-${slug//\//_}-$pr-$refsha"
  if [ -e "$mark" ]; then note "#$pr ($slug): conflicto con $ref ya está en la cola; espera"; return 0; fi
  spec="$state/queue/${slug//\//_}-$pr.md"
  [ "$dry" -eq 1 ] && { say "dry-run: #$pr ($slug): conflicto con $ref -> lo pondría en la cola"; return 0; }
  cat >"$spec" <<EOF
# Resolver conflictos de merge (stack-sync)

Esto es un brief: ejecutalo sin la pregunta de carril ni la de Continuar/Orquestar.

Repo: \`$path\` (rama \`$branch\`, PR #$pr de $slug). Trabajá SIEMPRE con \`cd\` a esa ruta y no toques
ningún otro worktree. Leé el \`AGENTS.md\`/\`CLAUDE.md\` del repo antes.

Motivo: $why. Hay que traer \`$ref\` a esta rama y da conflictos.

1. \`git fetch origin\` y \`git merge --no-edit $ref\`.
2. Resolvé cada conflicto conservando lo de los dos lados (la rama trae su cambio; \`$ref\` trae lo ya
   mergeado). Si un conflicto pide una decisión de producto, no la tomes: \`git merge --abort\` y reportá.
3. Corré los checks del repo (los de su \`AGENTS.md\`; en CX: \`pnpm lint\`, \`pnpm typecheck\`, \`pnpm test\`).
   Si el merge cambió el schema de Prisma, antes \`pnpm exec prisma generate\` (no toca la base).
4. Si pasan: \`git commit --no-edit\` (commit del merge) y después
   \`touch "$state/resolved-${slug//\//_}-$pr-\$(git rev-parse HEAD)"\`. **No pushees ni edites el PR**:
   stack-sync ve esa marca y pushea en su próxima corrida (cada 15 min).
5. Nunca rebase, force, amend ni \`--no-verify\`.

Al terminar: si quedó resuelto, borrá este archivo (\`rm "$spec"\`); si abortaste o fallaron los checks, movelo a
\`$state/failed/\` con una línea al final que diga por qué. Avisá con
\`notify-send "stack-sync: PR #$pr" "<resultado en una línea>"\` y dejá en el chat qué conflictos había, cómo los
resolviste y la salida de los checks.
EOF
  : >"$mark"
  say "#$pr ($slug, $branch): conflicto con $ref -> en la cola de la automatización de Orca ($spec)"
}

# PRs, bottom-up: trunk-based first, then those stacked on them (depth by base chain)
for slug in "${!slug_of[@]}"; do
  json="$(tgh pr list --repo "$slug" --author @me --state open --limit 100 \
    --json number,headRefName,baseRefName,mergeable,headRefOid 2>/dev/null)" || continue
  [ -n "$json" ] || continue
  rows="$(jq -r --arg t "$trunk" '
    (map({key: .headRefName, value: .baseRefName}) | from_entries) as $base
    | def depth($b; $n): if ($base[$b] // null) == null or $n > 20 then $n else depth($base[$b]; $n + 1) end;
    map(. + {d: depth(.baseRefName; 0)}) | sort_by(.d)[]
    | [.number, .headRefName, .baseRefName, .mergeable, .headRefOid] | @tsv' <<<"$json")"
  while IFS=$'\t' read -r pr head base mergeable oid; do
    [ -n "$pr" ] || continue
    path="${wt["$slug|$head"]:-}"
    [ -n "$path" ] || continue # no local worktree for this branch: nothing to do here
    git -C "$path" fetch -q origin 2>/dev/null || { note "#$pr ($slug): fetch falló"; continue; }
    # -uno: un archivo sin trackear (el pnpm-lock.yaml que deja pnpm) no frena el merge; uno trackeado sí
    if [ -n "$(git -C "$path" status --porcelain --untracked-files=no 2>/dev/null)" ]; then
      note "#$pr ($slug, $head): salteado, $path tiene cambios sin commitear"; continue
    fi
    # 5: la resolución de un agente (marca con su commit) se pushea acá; el agente nunca pushea (ADR 0042)
    local_head="$(git -C "$path" rev-parse HEAD)"
    resolved="$state/resolved-${slug//\//_}-$pr-$local_head"
    if [ "$local_head" != "$oid" ] && [ -e "$resolved" ] && git -C "$path" merge-base --is-ancestor "$oid" HEAD; then
      if [ "$dry" -eq 1 ]; then
        say "dry-run: #$pr ($slug, $head): pushearía la resolución del agente"; continue
      fi
      if git -C "$path" push -q origin "HEAD:$head" 2>/dev/null; then
        rm -f "$resolved"; oid="$local_head"
        say "#$pr ($slug, $head): pusheé la resolución de conflictos del agente"
        [ "$base" = "$trunk" ] || [ "$base" = main ] || [ "$base" = master ] && continue
      else
        say "#$pr ($slug, $head): la resolución del agente no se pudo pushear; queda en $path"; continue
      fi
    fi
    if [ "$(git -C "$path" rev-parse HEAD)" != "$oid" ]; then
      note "#$pr ($slug, $head): salteado, $path no está en la punta del PR (commits sin pushear o atrasado)"; continue
    fi
    if [ "$base" = "$trunk" ] || [ "$base" = main ] || [ "$base" = master ]; then
      [ "$mergeable" = CONFLICTING ] && merge_and_push "$slug" "$pr" "$head" "$path" "origin/$base" "choca con $base"
      continue
    fi
    merged="$(tgh pr list --repo "$slug" --head "$base" --state merged --json number --limit 1 2>/dev/null | jq -r '.[0].number // empty')"
    if [ -n "$merged" ]; then
      merge_and_push "$slug" "$pr" "$head" "$path" "origin/$trunk" "el PR de abajo (#$merged, $base) se mergeó" "$trunk"
    elif git -C "$path" rev-parse -q --verify "origin/$base" >/dev/null &&
         ! git -C "$path" merge-base --is-ancestor "origin/$base" HEAD; then
      merge_and_push "$slug" "$pr" "$head" "$path" "origin/$base" "la rama de abajo ($base) tiene cambios nuevos"
    fi
  done <<<"$rows"
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
exit 0
