#!/usr/bin/env bash
# worker-commit.sh - lets an Orca worker commit on its own branch without a permission dialog (ADR 0062).
#
# Work repos version `ask` rules for `git commit *` in .claude/settings.json. An `ask` rule prompts even in
# bypassPermissions, and neither a user `allow` nor a hook's permissionDecision "allow" beats it, so workers
# stopped at every commit. The rules are matched against the command a PreToolUse hook hands back in
# `updatedInput`, so this hook rewrites only the `git commit` of the command into `bash <this file> commit`.
# It grants nothing itself (no permissionDecision): every other segment (a `git push`, `gh pr create`) still goes
# through the repo's rules, the deny rules and the other hooks (the org guards see the original command).
#
# Two modes:
#   hook (no arguments, PreToolUse JSON on stdin): rewrites only when all of these hold, otherwise stays silent:
#     - exactly one `git commit` (or `git -C <dir> commit`) at a command position, at most one `cd` before it;
#     - only the flags below (no --amend, --no-verify, -n, --fixup...);
#     - the target is a linked worktree on a branch that is not a base (main, master, dev, develop, qa, origin/HEAD);
#     - the session is a supervised Orca worker (`orca orchestration worker-start`) whose active terminal
#       ($ORCA_TERMINAL_HANDLE) works on that worktree, or a stack-sync agent with a live busy mark there (ADR 0060).
#   wrapper (`worker-commit.sh [-C <dir>] commit <args>`): checks the same again on the real arguments and runs
#     `git commit`; every use goes to ~/.local/state/agents-config/worker-commit.log.
#
# Allowed commit flags: -m/--message <msg>, -F/--file <file>, -q, -a, -s, -v, --allow-empty, their long forms,
# clusters like -am, pathspecs after them, and --no-edit only while a merge is in progress.
set -uo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/$(basename "${BASH_SOURCE[0]}")"

# flags_ok <merging 0|1> <args...>: 0 when every argument is an allowed commit flag, its value, or a pathspec
flags_ok() {
  local merging=$1 a want=0
  shift
  for a in "$@"; do
    if [ "$want" -eq 1 ]; then want=0; continue; fi
    case $a in
      -m | --message | -F | --file) want=1 ;;
      --message=* | --file=*) ;;
      -q | --quiet | -a | --all | -s | --signoff | -v | --verbose | --allow-empty | --) ;;
      --no-edit) [ "$merging" -eq 1 ] || return 1 ;;
      --*) return 1 ;;
      -m?* | -F?*) ;; # value attached: -mfix
      -*)
        [[ $a =~ ^-[aqsv]*[mF]?$ ]] || return 1
        [[ $a == *[mF] ]] && want=1
        ;;
      *) ;; # pathspec, or a redirection token left by the hook's word split
    esac
  done
  [ "$want" -eq 0 ]
}

# target_ok <dir>: prints the worktree top when <dir> is a linked worktree on a non-base branch
target_ok() {
  local top gd cd br def
  top="$(git -C "$1" rev-parse --show-toplevel 2>/dev/null)" || return 1
  gd="$(git -C "$top" rev-parse --path-format=absolute --git-dir 2>/dev/null)" || return 1
  cd="$(git -C "$top" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 1
  [ "$gd" != "$cd" ] || return 1 # the main checkout, not a worktree
  br="$(git -C "$top" symbolic-ref --short -q HEAD)" || return 1
  def="$(git -C "$top" symbolic-ref --short -q refs/remotes/origin/HEAD 2>/dev/null)"
  case $br in main | master | dev | develop | qa | "${def#origin/}") return 1 ;; esac
  printf '%s' "$top"
}

# authorized <top>: a stack-sync agent with a live busy mark there, or a supervised Orca worker of that worktree
authorized() {
  local top=$1 state m mpath mbranch orca p
  state="${STACK_SYNC_STATE:-$HOME/.local/state/stack-sync}"
  for m in "$state"/busy/*; do
    [ -f "$m" ] && [ -n "$(find "$m" -mmin "-${STACK_SYNC_BUSY_MINUTES:-60}" 2>/dev/null)" ] || continue
    IFS=$'\t' read -r mpath mbranch <"$m" || true
    [ "$mpath" = "$top" ] && return 0
  done
  [ -n "${ORCA_TERMINAL_HANDLE:-}" ] || return 1
  orca="${WORKER_COMMIT_ORCA:-${ORCA_CLI_COMMAND:-orca}}"
  while IFS= read -r p; do
    [ -n "$p" ] && [ "$(cd "$p" 2>/dev/null && pwd -P)" = "$(cd "$top" && pwd -P)" ] && return 0
  done < <("$orca" orchestration worker-list --json --terminal-state active --limit 100 2>/dev/null |
    jq -r --arg h "$ORCA_TERMINAL_HANDLE" \
      '.result.workers[]? | select(.terminal == $h) | (.workspace // "") | sub("^[^:]*::"; "")' 2>/dev/null)
  return 1
}

# ---- wrapper mode ----------------------------------------------------------------------------------------
if [ $# -gt 0 ]; then
  die() { echo "worker-commit: $1" >&2; exit 2; }
  dir=.
  if [ "$1" = -C ] && [ $# -ge 2 ]; then dir=$2; shift 2; fi
  [ "${1:-}" = commit ] || die "uso: worker-commit.sh [-C <dir>] commit <flags>"
  shift
  top="$(target_ok "$dir")" || die "solo en un worktree, en una rama que no sea base; usá git commit directo"
  merging=0
  git -C "$top" rev-parse -q --verify MERGE_HEAD >/dev/null && merging=1
  flags_ok "$merging" "$@" || die "flag no permitido (sí: -m, -F, -q, -a, -s, -v, --allow-empty; --no-edit en un merge)"
  authorized "$top" || die "esta sesión no es un worker de Orca de $top; usá git commit directo"
  log="${XDG_STATE_HOME:-$HOME/.local/state}/agents-config/worker-commit.log"
  mkdir -p "$(dirname "$log")" 2>/dev/null
  if git -C "$dir" commit "$@"; then
    printf '%s commit %s en %s (%s)\n' "$(date '+%F %T')" "$(git -C "$top" rev-parse --short HEAD)" "$top" \
      "${ORCA_TERMINAL_HANDLE:-stack-sync}" >>"$log" 2>/dev/null
    exit 0
  fi
  exit 1
fi

# ---- hook mode: any problem exits 0 without output (the normal permission flow) ---------------------------
command -v jq >/dev/null 2>&1 || exit 0
input="$(cat 2>/dev/null)" || exit 0
cmd="$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null)" || exit 0
case $cmd in *git*commit*) ;; *) exit 0 ;; esac
cwd="$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)"
[ -n "$cwd" ] || cwd=$PWD

# quoted characters become '_' (same length), so operators and words inside a message are data
m="" q=""
for ((i = 0; i < ${#cmd}; i++)); do
  c=${cmd:i:1}
  if [ -n "$q" ]; then
    if [ "$c" = "$q" ]; then q=""; m+=$c; else m+=_; fi
  elif [ "$c" = "'" ] || [ "$c" = '"' ]; then q=$c; m+=$c
  else m+=$c; fi
done

nl=$'\n'
re_commit="(^|[;&|({$nl])([[:space:]]*)git([[:space:]]+-C[[:space:]]+[^[:space:];&|)]+)?[[:space:]]+commit([[:space:]]|$)"
[[ $m =~ $re_commit ]] || exit 0
whole=${BASH_REMATCH[0]} lead=${BASH_REMATCH[1]}${BASH_REMATCH[2]} copt=${BASH_REMATCH[3]}
pre=${m%%"$whole"*}
start=$((${#pre} + ${#lead})) # index of "git"
[[ ${m:start+3} =~ $re_commit ]] && exit 0 # more than one commit

# the commit segment ends at the next unquoted operator
seg_m=${m:start}
seg_m=${seg_m%%[;&|)$nl]*}
read -r -a words <<<"$seg_m"
i=1
[ "${words[1]:-}" = -C ] && i=3
[ "${words[i]:-}" = commit ] || exit 0

# target directory: git -C <dir>, else the only `cd <dir>` before the commit, else the session's cwd
unquote() { local p=$1; p=${p#[\"\']}; p=${p%[\"\']}; [[ $p == "~"* ]] && p=$HOME${p#\~}; [[ $p == /* ]] || p=$cwd/$p; printf '%s' "$p"; }
dir=$cwd
if [ -n "$copt" ]; then
  read -r -a cw <<<"${cmd:start:${#seg_m}}"
  dir="$(unquote "${cw[2]}")"
else
  head_m=${m:0:start}
  re_cd="(^|[;&|({$nl])[[:space:]]*cd[[:space:]]+([^[:space:];&|)]+)"
  if [[ $head_m =~ $re_cd ]]; then
    cdw=${BASH_REMATCH[0]} cdarg=${BASH_REMATCH[2]}
    cpre=${head_m%%"$cdw"*}
    [[ ${head_m:${#cpre}+${#cdw}} =~ $re_cd ]] && exit 0 # more than one cd
    off=$((${#cpre} + ${#cdw} - ${#cdarg}))
    dir="$(unquote "${cmd:off:${#cdarg}}")"
  fi
fi

top="$(target_ok "$dir")" || exit 0
merging=0
git -C "$top" rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1 && merging=1
flags_ok "$merging" "${words[@]:i+1}" || exit 0
authorized "$top" || exit 0

new="${cmd:0:start}bash '$SELF'${cmd:start+3}"
jq -c --arg c "$new" '{hookSpecificOutput: {hookEventName: "PreToolUse",
  updatedInput: (.tool_input + {command: $c}),
  additionalContext: "worker-commit (ADR 0062): el git commit de este worker corrió por worker-commit.sh, que el ask de git commit del repo no frena; el resto del comando pasó por las reglas de siempre."}}' <<<"$input" 2>/dev/null
exit 0
