#!/usr/bin/env bash
# SessionStart: delete the linked git worktrees whose branch is already merged (ADR 0030, 0053).
# Merged means either of:
#   - a merged PR on GitHub whose head is exactly the worktree's HEAD (squash merges leave the branch
#     unmerged for git, so PR repos are read from GitHub);
#   - no PR: the HEAD is in origin/<default> but off its first-parent chain, i.e. it came in through a
#     --no-ff merge that was pushed (the personal-repo flow). A fresh branch with no commits of its own sits
#     on that chain, so it is never taken; a fast-forward merge is not detected either (kept, the safe side).
# A worktree is removed only when it is clean, so nothing uncommitted is lost. No fetch: a stale origin ref
# only delays the cleanup. Never breaks the session: any failure exits 0 in silence, ~10 s budget.
#
# Usage (hook): reads the SessionStart JSON on stdin (`cwd`), prints additionalContext when it deleted something.
#   worktree-cleanup.sh --cwd <dir> [--dry-run]   manual run: plain-text summary; --dry-run only lists.
set -uo pipefail

BUDGET=10   # seconds for the whole run
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CALL_MAX=5  # seconds for one gh call

manual=0; dry=0; cwd=""
while [ $# -gt 0 ]; do
  case "$1" in
    --cwd) manual=1; cwd="${2:-}"; shift; [ $# -gt 0 ] && shift ;;
    --dry-run) dry=1; shift ;;
    *) shift ;;
  esac
done

deadline=$((SECONDS + BUDGET))
lines=()
have_gh=0

say_note() { [ "$manual" -eq 1 ] && echo "worktree-cleanup: $1"; return 0; }

left() { echo $((deadline - SECONDS)); }

# gh_merged <owner/repo> <branch> -> JSON array on stdout (empty on any failure or timeout)
gh_merged() {
  local t; t="$(left)"; [ "$t" -gt 0 ] || return 1
  [ "$t" -le "$CALL_MAX" ] || t="$CALL_MAX"
  if command -v timeout >/dev/null 2>&1; then
    timeout "$t" gh pr list --repo "$1" --head "$2" --state merged --json number,headRefOid --limit 1
  else
    gh pr list --repo "$1" --head "$2" --state merged --json number,headRefOid --limit 1
  fi
}

# Process the linked worktrees of one repo (any of its worktrees as $1).
clean_repo() {
  local any="$1" main="" path="" branch="" line
  local slug="" url="" base="" b firstparent=""
  url="$(git -C "$any" remote get-url origin 2>/dev/null)" || url=""
  [ "$have_gh" -eq 1 ] && slug="$(printf '%s' "$url" | sed -nE 's#^.*github\.com[:/]+([^/]+/[^/]+)$#\1#p' | sed -E 's#\.git$##')"
  # pushed default branch: origin/HEAD, else origin/main or origin/master
  base="$(git -C "$any" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)" || base=""
  if [ -z "$base" ]; then
    for b in main master; do
      git -C "$any" show-ref --verify --quiet "refs/remotes/origin/$b" && { base="origin/$b"; break; }
    done
  fi
  [ -n "$base" ] && firstparent="$(git -C "$any" rev-list --first-parent "$base" 2>/dev/null)"
  [ -n "$slug" ] || [ -n "$firstparent" ] || return 0

  local porcelain; porcelain="$(git -C "$any" worktree list --porcelain 2>/dev/null)" || return 0
  main="$(printf '%s\n' "$porcelain" | sed -n '1s/^worktree //p')"
  [ -n "$main" ] || return 0

  # one record per blank-line-separated block; the first block is the main worktree
  local -a recs=()
  local block=""
  while IFS= read -r line || [ -n "$line" ]; do
    if [ -z "$line" ]; then [ -n "$block" ] && recs+=("$block"); block=""; else block="$block$line"$'\n'; fi
  done <<<"$porcelain"
  [ -n "$block" ] && recs+=("$block")

  local rec i=0
  for rec in "${recs[@]}"; do
    i=$((i + 1)); [ "$i" -gt 1 ] || continue
    [ "$(left)" -gt 0 ] || return 0
    path="$(printf '%s' "$rec" | sed -n 's/^worktree //p' | head -n1)"
    branch="$(printf '%s' "$rec" | sed -n 's#^branch refs/heads/##p' | head -n1)"
    printf '%s' "$rec" | grep -qE '^(locked|prunable|bare)' && continue
    [ -n "$path" ] && [ -n "$branch" ] && [ -d "$path" ] || continue
    case "$branch" in main|master|dev|develop) continue ;; esac
    # never the worktree that holds the session
    case "$cwd_real/" in "$path"/*) continue ;; esac
    # a. dirty: not touched
    [ -z "$(git -C "$path" status --porcelain 2>/dev/null)" ] || continue
    local json num oid head reason=""
    head="$(git -C "$path" rev-parse HEAD 2>/dev/null)" || continue
    # b. merged PR whose head is exactly what is checked out here
    if [ -n "$slug" ] && json="$(gh_merged "$slug" "$branch" 2>/dev/null)"; then
      num="$(printf '%s' "$json" | jq -r '.[0].number // empty' 2>/dev/null)"
      oid="$(printf '%s' "$json" | jq -r '.[0].headRefOid // empty' 2>/dev/null)"
      [ -n "$num" ] && [ "$head" = "$oid" ] && reason="PR #$num mergeado"
    fi
    # c. no PR: pushed --no-ff merge (in the base, off its first-parent chain)
    if [ -z "$reason" ] && [ -n "$firstparent" ] \
      && git -C "$path" merge-base --is-ancestor "$head" "$base" 2>/dev/null \
      && ! grep -qxF "$head" <<<"$firstparent"; then
      reason="mergeada en $base"
    fi
    [ -n "$reason" ] || continue
    # d. remove (no --force: git refuses when it is not safe); -D because a squash merge leaves the branch "unmerged"
    if [ "$dry" -eq 1 ]; then
      lines+=("worktree-cleanup (dry-run): borraría $path (rama $branch, $reason)")
      continue
    fi
    # Con algo corriendo adentro no se borra: un dev server vivo deja la carpeta a medias, y este hook no mata
    # procesos por su cuenta (puede ser una sesión abierta ahí). ADR 0065.
    if ! bash "$HERE/worktree-frenar.sh" --listar "$path" >/dev/null 2>&1; then
      lines+=("worktree-cleanup: no borré $path (rama $branch, $reason): tiene procesos corriendo")
      continue
    fi
    git -C "$main" worktree remove "$path" >/dev/null 2>&1 || continue
    git -C "$main" branch -D "$branch" >/dev/null 2>&1
    lines+=("worktree-cleanup: borré $path (rama $branch, $reason)")
  done
  return 0
}

main() {
  command -v git >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || return 0
  # without gh only the local-merge check runs
  if command -v gh >/dev/null 2>&1; then have_gh=1; else say_note "gh no está disponible: solo merges locales"; fi

  if [ "$manual" -eq 0 ] && [ ! -t 0 ]; then
    cwd="$(jq -r '.cwd // empty' 2>/dev/null || true)"
  fi
  [ -n "$cwd" ] && [ -d "$cwd" ] || { [ "$manual" -eq 1 ] && [ -n "$cwd" ] && return 0; cwd="$PWD"; }
  cwd_real="$(cd "$cwd" 2>/dev/null && pwd -P)" || return 0

  if git -C "$cwd_real" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    clean_repo "$cwd_real"
  else
    # a folder that groups repos: each direct child with its own .git directory (dedup by main worktree)
    local d seen=$'\n' mainwt
    for d in "$cwd_real"/*/; do
      [ -d "${d}.git" ] || continue
      mainwt="$(git -C "$d" worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')"
      case "$seen" in *$'\n'"$mainwt"$'\n'*) continue ;; esac
      seen="$seen$mainwt"$'\n'
      clean_repo "${d%/}"
    done
  fi
  return 0
}

cwd_real=""
main 2>/dev/null || true

if [ "${#lines[@]}" -gt 0 ]; then
  msg="$(printf '%s\n' "${lines[@]}")"
  if [ "$manual" -eq 1 ] || [ "$dry" -eq 1 ]; then
    printf '%s\n' "$msg"
  else
    jq -n --arg c "$msg" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}' 2>/dev/null
  fi
elif [ "$manual" -eq 1 ] || [ "$dry" -eq 1 ]; then
  echo "worktree-cleanup: nada que borrar"
fi
exit 0
