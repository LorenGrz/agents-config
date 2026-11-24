#!/usr/bin/env bash
# stack-sync-git.sh - the only commit and push a stack-sync agent runs (ADR 0060). Work repos may version `ask`
# rules for `git commit` and `git push` in .claude/settings.json; they prompt even in bypassPermissions, so an
# agent of stack-sync would wait for Loren. This command is not matched by those rules, so it is narrow on purpose:
#   - it works only in a worktree with a live stack-sync busy mark (an agent launched there less than
#     STACK_SYNC_BUSY_MINUTES ago), and takes the PR branch from that mark;
#   - commit: only `-m <msg>` (one or more) or `--no-edit` while a merge is in progress; never --amend,
#     --no-verify or any other flag;
#   - push: only HEAD to that PR branch on origin, without force;
#   - every use goes to the stack-sync log.
#
# Usage: stack-sync-git.sh commit -m <msg> [-m <msg>...]
#        stack-sync-git.sh commit --no-edit        (the commit of a merge)
#        stack-sync-git.sh push
set -uo pipefail

state="${STACK_SYNC_STATE:-$HOME/.local/state/stack-sync}"
busy_minutes="${STACK_SYNC_BUSY_MINUTES:-60}"
log="$state/stack-sync.log"
die() { echo "stack-sync-git: $1" >&2; exit 2; }

top="$(git rev-parse --show-toplevel 2>/dev/null)" || die "no es un repo git"
# the busy mark of this worktree: "<path>\t<branch>", written by stack-sync when it launched the agent
branch=""
for m in "$state"/busy/*; do
  [ -f "$m" ] && [ -n "$(find "$m" -mmin "-$busy_minutes" 2>/dev/null)" ] || continue
  IFS=$'\t' read -r mpath mbranch <"$m" || true
  [ "$mpath" = "$top" ] && [ -n "$mbranch" ] && { branch="$mbranch"; break; }
done
[ -n "$branch" ] || die "no hay un agente de stack-sync activo en $top; usá git directo"
record() { printf '%s stack-sync-git: %s en %s (%s): %s\n' "$(date '+%F %T')" "$1" "$top" "$branch" "$2" >>"$log"; }

action="${1:-}"; shift || true
case "$action" in
  commit)
    args=()
    if [ "${1:-}" = --no-edit ] && [ $# -eq 1 ]; then
      git rev-parse -q --verify MERGE_HEAD >/dev/null || die "--no-edit es solo para el commit de un merge en curso"
      args=(--no-edit)
    else
      [ $# -gt 0 ] || die "falta -m <mensaje>"
      while [ $# -gt 0 ]; do
        [ "$1" = -m ] && [ $# -ge 2 ] || die "commit solo acepta -m <mensaje> o --no-edit (rechazado: $1)"
        args+=(-m "$2"); shift 2
      done
    fi
    if git commit "${args[@]}"; then record commit "ok $(git rev-parse --short HEAD)"; else record commit falló; exit 1; fi
    ;;
  push)
    [ $# -eq 0 ] || die "push no lleva argumentos: siempre HEAD a $branch, sin force"
    if git push origin "HEAD:refs/heads/$branch"; then record push ok; else record push falló; exit 1; fi
    ;;
  *) die "uso: stack-sync-git.sh commit -m <mensaje> | commit --no-edit | push" ;;
esac
