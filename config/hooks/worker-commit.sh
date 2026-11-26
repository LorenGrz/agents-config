#!/usr/bin/env bash
# worker-commit.sh - lets an Orca worker commit on its own branch without a permission dialog (ADR 0062).
#
# Work repos version `ask` rules for `git commit *` in .claude/settings.json. An `ask` rule prompts even in
# bypassPermissions, and neither a user `allow` nor a hook's permissionDecision "allow" beats it, so workers
# stopped at every commit. The rules are matched against the command a PreToolUse hook hands back in
# `updatedInput`, so this hook rewrites a lone `git commit` into `bash <this file> --token <t> commit ...`.
# It grants nothing itself (no permissionDecision).
#
# Two modes:
#   hook (no arguments, PreToolUse JSON on stdin). It does not interpret bash: it rewrites only when the WHOLE
#   command is one `git commit` with these arguments, separated by spaces, and nothing else:
#       -q | --quiet | -a | --all | --no-edit (only while a merge is in progress)
#       -m | --message  followed by '...' (no ' inside) or "..." (no " $ ` \ inside)
#       -F | --file     followed by a plain path ([A-Za-z0-9._/-], not starting with -)
#   One line: no line break anywhere (a multi-line message goes as several -m). No &&, ;, |, $, backticks, <(,
#   redirections, heredocs or prefixes (env, export, cd, git -C). Anything else,
#   --amend, --no-verify and -n included, stays silent and the normal permission flow (the dialog) decides,
#   with one exception: for an authorized worker (the same checks below), a compound or multi-line command that
#   carries a `git commit` at a command position is denied with a reason that tells the worker how to send it
#   (git add and git commit as separate one-line commands, the message as -m), so it retries without a dialog.
#   Both the rewrite and the deny act only where an `ask` rule on `git commit` would stop the worker (user, project,
#   local or managed settings); with no such rule the hook does nothing.
#   It also needs: the session is a supervised Orca worker (`orca orchestration worker-start`) whose terminal
#   ($ORCA_TERMINAL_HANDLE) works on that worktree, or a stack-sync agent with a live busy mark there (ADR 0060),
#   and never the `scout` or `reviewer` subagents; the cwd is a linked worktree on a branch that is not a base
#   (main, master, dev, develop, qa, origin/HEAD) with no core.hooksPath of /dev/null; for the rewrite, a -m, -F or
#   --no-edit outside the quotes, and no `deny` rule that matches the command itself or `git commit -m x` (the
#   rewrite would dodge it too). The worker gate runs before any parsing.
#   wrapper (`worker-commit.sh --token <t> commit <args>`): runs only with a one-time token the hook wrote for that
#     worktree in the last 5 minutes, so it can't be called on its own; checks the same arguments, branch and
#     hooksPath again on the real argv, clears the git and husky variables that would skip or redirect the commit
#     hooks, and runs `git commit`. Every use goes to ~/.local/state/agents-config/worker-commit.log.
set -uo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/$(basename "${BASH_SOURCE[0]}")"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/agents-config"
TOKENS="$STATE/worker-commit-tokens"

# args_ok <merging 0|1> <args...>: the wrapper's check of the real argv, the same list as the hook's
args_ok() {
  local merging=$1 msg=0
  shift
  while [ $# -gt 0 ]; do
    case $1 in
      -q | --quiet | -a | --all) shift ;;
      --no-edit) [ "$merging" -eq 1 ] || return 1; msg=1; shift ;;
      -m | --message) [ $# -ge 2 ] || return 1; msg=1; shift 2 ;;
      -F | --file) [ $# -ge 2 ] && [[ $2 =~ ^[A-Za-z0-9._/][A-Za-z0-9._/-]*$ ]] || return 1; msg=1; shift 2 ;;
      *) return 1 ;;
    esac
  done
  [ "$msg" -eq 1 ] # a message (or a merge's own) is required: no editor, no empty-message error
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
  [ "$(git -C "$top" config --get core.hooksPath 2>/dev/null)" != /dev/null ] || return 1
  printf '%s' "$top"
}

# ---- wrapper mode ----------------------------------------------------------------------------------------
if [ $# -gt 0 ]; then
  die() { echo "worker-commit: $1" >&2; exit 2; }
  [ "$1" = --token ] && [[ ${2:-} =~ ^[0-9a-f]{32}$ ]] && [ "${3:-}" = commit ] ||
    die "solo corre desde el hook (ADR 0062); usá git commit directo"
  tok="$TOKENS/$2"
  shift 3
  # nothing in the environment may skip or redirect the commit hooks: cleared before any check
  unset GIT_DIR GIT_COMMON_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES \
    GIT_EXEC_PATH GIT_CONFIG GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM GIT_CONFIG_NOSYSTEM GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT HUSKY
  for v in $(compgen -v GIT_CONFIG_KEY_) $(compgen -v GIT_CONFIG_VALUE_); do unset "$v"; done
  top="$(target_ok .)" || { rm -f "$tok"; die "solo en un worktree, en una rama que no sea base; usá git commit directo"; }
  # the token: written by the hook for this worktree, used once, at most 5 minutes old
  [ -f "$tok" ] && [ -n "$(find "$tok" -mmin -5 2>/dev/null)" ] && [ "$(cat "$tok" 2>/dev/null)" = "$top" ] ||
    { rm -f "$tok"; die "token vencido o de otro worktree; usá git commit directo"; }
  rm -f "$tok"
  merging=0
  git -C "$top" rev-parse -q --verify MERGE_HEAD >/dev/null && merging=1
  args_ok "$merging" "$@" || die "argumento no permitido (sí: -m, -F <archivo>, -q, -a; --no-edit en un merge)"
  mkdir -p "$STATE" 2>/dev/null
  if git commit "$@"; then
    printf '%s commit %s en %s (%s)\n' "$(date '+%F %T')" "$(git rev-parse --short HEAD)" "$top" \
      "${ORCA_TERMINAL_HANDLE:-stack-sync}" >>"$STATE/worker-commit.log" 2>/dev/null
    exit 0
  fi
  exit 1
fi

# ---- hook mode: any problem exits 0 without output (the normal permission flow) ---------------------------
input="$(cat 2>/dev/null)" || exit 0
case $input in *git*commit*) ;; *) exit 0 ;; esac
# the worker gate first, before any parsing: a worker handle or a stack-sync busy mark
busy="${STACK_SYNC_STATE:-$HOME/.local/state/stack-sync}/busy"
if [ -z "${ORCA_TERMINAL_HANDLE:-}" ]; then
  compgen -G "$busy/*" >/dev/null || exit 0
fi
command -v jq >/dev/null 2>&1 || exit 0
case "$(jq -r '.agent_type // empty' <<<"$input" 2>/dev/null)" in scout | reviewer) exit 0 ;; esac
cmd="$(jq -r '.tool_input.command // empty' <<<"$input"; printf x)" || exit 0
cmd=${cmd%$'\n'x} # keep the command exactly as sent (no trailing newline is lost)
cwd="$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)"
[ -n "$cwd" ] || cwd=$PWD

# the whole command, one regex: git commit and the allowed arguments, nothing before or after
sq="'[^']*'"
dq='"[^"$`\\]*"'
path='[A-Za-z0-9._/][A-Za-z0-9._/-]*'
arg="(-q|--quiet|-a|--all|--no-edit|(-m|--message) ($sq|$dq)|(-F|--file) $path)"
re="^git commit( $arg)+\$"
# rules <ask|deny> <string...>: 0 when a Bash rule of that kind (user, project, local or managed settings) matches
# one of the strings, as a glob (the legacy `prefix:*` form included)
rules() {
  local kind=$1 s rule p str
  shift
  for s in "$HOME/.claude/settings.json" "$HOME/.claude/settings.local.json" "${CLAUDE_PROJECT_DIR:-$cwd}/.claude/settings.json" \
    "${CLAUDE_PROJECT_DIR:-$cwd}/.claude/settings.local.json" "$top/.claude/settings.json" "$top/.claude/settings.local.json" \
    /etc/claude-code/managed-settings.json; do
    [ -f "$s" ] || continue
    while IFS= read -r rule; do
      [ "$rule" = Bash ] && return 0
      [[ $rule == 'Bash('*')' ]] || continue
      p=${rule#Bash(}; p=${p%)}
      [[ $p == *:\* ]] && p="${p%:\*}*"
      for str in "$@"; do
        # shellcheck disable=SC2053 # $p is a glob on purpose
        [[ $str == $p ]] && return 0
      done
    done < <(jq -r --arg k "$kind" '.permissions[$k][]? | strings' "$s" 2>/dev/null)
  done
  return 1
}

mode=rewrite
if ! [[ $cmd != *$'\n'* && $cmd =~ $re ]]; then
  # not a lone commit. A compound or multi-line command that carries a `git commit` at a command position
  # (start, or after ; & | ( or a line break) gets the deny below; a single command (--amend, -m unquoted,
  # HUSKY=0 git commit) stays with the dialog.
  re_pos=$'(^|[;&|(\n])[ \t]*git([ \t]+-C[ \t]+[^ \t;&|]+)?[ \t]+commit([ \t]|$)'
  [[ $cmd =~ $re_pos ]] || exit 0
  if [[ $cmd != *$'\n'* ]]; then
    bare="$(sed -E "s/$sq//g; s/\"[^\"]*\"//g" <<<"$cmd")"
    case $bare in *'&&'* | *'||'* | *';'* | *'|'* | *'&'*) ;; *) exit 0 ;; esac
  fi
  mode=deny
fi

top="$(target_ok "$cwd")" || exit 0
real="$(cd "$top" && pwd -P)"
if [ "$mode" = rewrite ]; then
  # outside the quotes: a message source is required, and --no-edit only while a merge is in progress
  bare=" $(sed -E "s/$sq//g; s/$dq//g" <<<"$cmd") "
  [[ $bare =~ \ (-m|--message|-F|--file|--no-edit)\  ]] || exit 0
  case $bare in *" --no-edit "*) git -C "$top" rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1 || exit 0 ;; esac
  # only where an ask on git commit would stop this very command, and never past a deny that matches it
  rules ask "$cmd" || exit 0
  rules deny "$cmd" "git commit -m x" && exit 0
else
  # the deny only where the project asks for git commit: elsewhere the compound runs as it always did
  rules ask "git commit -m x" "git commit" || exit 0
fi

# authorized: a stack-sync agent with a live busy mark there, or a supervised Orca worker of that worktree
authorized() {
  local m mpath _ orca cursor="" page n=0 p
  for m in "$busy"/*; do
    [ -f "$m" ] && [ -n "$(find "$m" -mmin "-${STACK_SYNC_BUSY_MINUTES:-60}" 2>/dev/null)" ] || continue
    IFS=$'\t' read -r mpath _ <"$m" || true
    [ -n "$mpath" ] && [ "$(cd "$mpath" 2>/dev/null && pwd -P)" = "$real" ] && return 0
  done
  [ -n "${ORCA_TERMINAL_HANDLE:-}" ] || return 1
  orca="${WORKER_COMMIT_ORCA:-${ORCA_CLI_COMMAND:-orca}}"
  # any terminal state: a follow-up dispatch reuses the same terminal, which may show as retained, and a released
  # terminal has no live session left to carry its handle. Up to 10 pages of 100.
  while [ "$n" -lt 10 ]; do
    n=$((n + 1))
    page="$("$orca" orchestration worker-list --json --limit 100 ${cursor:+--cursor "$cursor"} 2>/dev/null)" || return 1
    while IFS= read -r p; do
      [ -n "$p" ] && [ "$(cd "$p" 2>/dev/null && pwd -P)" = "$real" ] && return 0
    done < <(jq -r --arg h "$ORCA_TERMINAL_HANDLE" \
      '.result.workers[]? | select(.terminal == $h) | (.workspace // "") | sub("^[^:]*::"; "")' <<<"$page" 2>/dev/null)
    cursor="$(jq -r '.result.nextCursor // empty' <<<"$page" 2>/dev/null)"
    [ -n "$cursor" ] || return 1
  done
  return 1
}
authorized || exit 0

if [ "$mode" = deny ]; then
  jq -nc --arg r "Mandá git add y git commit en comandos aparte, cada uno en una línea; el mensaje con -m en una línea (varios -m si hace falta). Sin redirecciones ni nada encadenado; si el mensaje trae \$, \` o \\, va entre comillas simples." \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
fi

# a one-time token for the wrapper; old ones are dropped
mkdir -p "$TOKENS" 2>/dev/null && chmod 700 "$TOKENS" 2>/dev/null || exit 0
find "$TOKENS" -type f -mmin +5 -delete 2>/dev/null
token="$(od -An -N16 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n')"
[[ $token =~ ^[0-9a-f]{32}$ ]] || exit 0
printf '%s' "$top" >"$TOKENS/$token" || exit 0

printf -v qself '%q' "$SELF"
new="bash $qself --token $token${cmd:3}"
jq -c --arg c "$new" '{hookSpecificOutput: {hookEventName: "PreToolUse",
  updatedInput: (.tool_input + {command: $c}),
  additionalContext: "worker-commit (ADR 0062): este git commit suelto corrió por worker-commit.sh, que el ask de git commit del repo no frena."}}' <<<"$input" 2>/dev/null
exit 0
