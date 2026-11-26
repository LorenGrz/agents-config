#!/usr/bin/env bash
# worker-commit.sh - lets an Orca worker commit on its own branch without a permission dialog (ADR 0062).
#
# Work repos version `ask` rules for `git commit *` in .claude/settings.json. An `ask` rule prompts even in
# bypassPermissions, and neither a user `allow` nor a hook's permissionDecision "allow" beats it, so workers
# stopped at every commit. The rules are matched against the command a PreToolUse hook hands back in
# `updatedInput`, so this hook rewrites the `git` of the one `git commit` into `bash <this file> --token <t>`.
# It grants nothing itself (no permissionDecision): every other segment still goes through the repo's rules.
#
# Two modes:
#   hook (no arguments, PreToolUse JSON on stdin). Rewrites only when all of these hold; otherwise it stays silent
#   and the normal permission flow (the dialog) decides:
#     - the session is a supervised Orca worker (`orca orchestration worker-start`) whose terminal
#       ($ORCA_TERMINAL_HANDLE) works on the target worktree, or a stack-sync agent with a live busy mark there
#       (ADR 0060); never the `scout` or `reviewer` subagents;
#     - the whole command fits a small grammar (an allowlist, not a denylist): segments joined by `&&`, `||`, `;`,
#       newlines or a pipe into `tail`/`head`; each segment is `cd <dir>`, `echo`, `true`, `pwd` or
#       `git [-C <dir>] add|status|log|diff|show|merge-base|rev-parse|branch|commit`; exactly one `git commit` and
#       at most one `cd`. Outside single quotes there is no `$`, backtick, backslash, parenthesis, brace, `&`
#       (background) or redirection other than `2>&1` and `[2]>/dev/null`; so no `export`, assignment, `env`,
#       `git -c`, command or process substitution. The one exception is a literal heredoc message
#       (`-m "$(cat <<'EOF' ... EOF)"` or `-F - <<'EOF' ... EOF`, quoted delimiter, so the body never expands);
#     - only the commit flags below (no --amend, --no-verify, -n, --fixup...);
#     - the target is a linked worktree on a branch that is not a base (main, master, dev, develop, qa, origin/HEAD);
#     - no `deny` rule covers `git commit` (user, project or managed settings): the rewrite would dodge it too.
#   wrapper (`worker-commit.sh --token <t> [-C <dir>] commit <args>`): runs only with a one-time token the hook wrote
#     for that worktree in the last 5 minutes, so it can't be called on its own; checks the flags, the branch and
#     a core.hooksPath of /dev/null again on the real arguments, clears the git and husky variables that would skip
#     or redirect the commit hooks, and runs `git commit`. Every use goes to
#     ~/.local/state/agents-config/worker-commit.log.
#
# Allowed commit flags: -m/--message <msg>, -F/--file <file>, -q, -a, -s, -v, --allow-empty, their long forms,
# clusters like -am, pathspecs after them, and --no-edit only while a merge is in progress.
set -uo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/$(basename "${BASH_SOURCE[0]}")"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/agents-config"
TOKENS="$STATE/worker-commit-tokens"

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
      *) ;; # pathspec, or a placeholder word left by the hook's analysis
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

# ---- wrapper mode ----------------------------------------------------------------------------------------
if [ $# -gt 0 ]; then
  die() { echo "worker-commit: $1" >&2; exit 2; }
  [ "$1" = --token ] && [[ ${2:-} =~ ^[0-9a-f]{32}$ ]] ||
    die "solo corre desde el hook (ADR 0062); usá git commit directo"
  tok="$TOKENS/$2"
  shift 2
  dir=.
  if [ "${1:-}" = -C ] && [ $# -ge 2 ]; then dir=$2; shift 2; fi
  [ "${1:-}" = commit ] || die "uso: worker-commit.sh --token <t> [-C <dir>] commit <flags>"
  shift
  top="$(target_ok "$dir")" || die "solo en un worktree, en una rama que no sea base; usá git commit directo"
  # the token: written by the hook for this worktree, used once, at most 5 minutes old
  [ -f "$tok" ] && [ -n "$(find "$tok" -mmin -5 2>/dev/null)" ] && [ "$(cat "$tok" 2>/dev/null)" = "$top" ] ||
    { rm -f "$tok"; die "token vencido o de otro worktree; usá git commit directo"; }
  rm -f "$tok"
  merging=0
  git -C "$top" rev-parse -q --verify MERGE_HEAD >/dev/null && merging=1
  flags_ok "$merging" "$@" || die "flag no permitido (sí: -m, -F, -q, -a, -s, -v, --allow-empty; --no-edit en un merge)"
  # nothing in the environment may skip or redirect the commit hooks; the repo's own hooksPath must exist
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_EXEC_PATH \
    GIT_CONFIG GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM GIT_CONFIG_NOSYSTEM GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT HUSKY
  for v in $(compgen -v GIT_CONFIG_KEY_) $(compgen -v GIT_CONFIG_VALUE_); do unset "$v"; done
  [ "$(git -C "$top" config --get core.hooksPath 2>/dev/null)" != /dev/null ] ||
    die "core.hooksPath es /dev/null: no commiteo salteando los hooks"
  mkdir -p "$STATE" 2>/dev/null
  if git -C "$dir" commit "$@"; then
    printf '%s commit %s en %s (%s)\n' "$(date '+%F %T')" "$(git -C "$top" rev-parse --short HEAD)" "$top" \
      "${ORCA_TERMINAL_HANDLE:-stack-sync}" >>"$STATE/worker-commit.log" 2>/dev/null
    exit 0
  fi
  exit 1
fi

# ---- hook mode: any problem exits 0 without output (the normal permission flow) ---------------------------
input="$(cat 2>/dev/null)" || exit 0
case $input in *git*commit*) ;; *) exit 0 ;; esac
# cheap gates first: a worker handle or a stack-sync busy mark, and jq/perl
busy="${STACK_SYNC_STATE:-$HOME/.local/state/stack-sync}/busy"
if [ -z "${ORCA_TERMINAL_HANDLE:-}" ]; then
  compgen -G "$busy/*" >/dev/null || exit 0
fi
command -v jq >/dev/null 2>&1 && command -v perl >/dev/null 2>&1 || exit 0
case "$(jq -r '.agent_type // empty' <<<"$input" 2>/dev/null)" in scout | reviewer) exit 0 ;; esac
cmd="$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null)" || exit 0
cwd="$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)"
[ -n "$cwd" ] || cwd=$PWD
export LC_ALL=C # perl counts bytes; so must bash when it slices the command at perl's offset

# The grammar check (linear). Prints: the offset of the commit's `git`, the -C or cd directory as written
# (empty: the cwd), then the commit's words with quoted text masked. Exit 1: not ours.
analysis="$(WC_CMD="$cmd" perl -e '
  use strict; use warnings;
  my $c = $ENV{WC_CMD};
  my $a = $c;
  # literal heredocs (quoted delimiter) become placeholders of the same length
  $a =~ s{("\$\(cat\s*<<-?\s*([\x27"])(\w+)\2\n.*?\n\3\n?\s*\)")}{q(") . (q(M) x (length($1) - 2)) . q(")}gse;
  $a =~ s{(<<-?\s*([\x27"])(\w+)\2\n.*?\n\3)(?=\n|\z)}{q(H) x length($1)}gse;
  # mask quoted text; refuse expansions and escapes
  my ($q, $m) = (q(), q());
  for my $ch (split //, $a) {
    if ($q eq "\x27") { if ($ch eq "\x27") { $q = q(); $m .= $ch } else { $m .= q(_) } next }
    if ($q eq q(")) {
      if ($ch eq q(")) { $q = q(); $m .= $ch } elsif ($ch =~ /[\$`\\]/) { exit 1 } else { $m .= q(_) }
      next;
    }
    if ($ch eq "\x27" || $ch eq q(")) { $q = $ch; $m .= $ch; next }
    exit 1 if $ch =~ /[\$`\\(){}]/;
    $m .= $ch;
  }
  exit 1 if $q ne q();
  # allowed redirections become placeholders; any other < or > is refused
  $m =~ s{(?<![^\s])(2>&1|2?>/dev/null)(?![^\s;&|])}{q(R) x length($1)}ge;
  exit 1 if $m =~ /[<>]/;
  my (@segs, $pos, $prev);
  ($pos, $prev) = (0, q());
  while ($m =~ /(&&|\|\||[;\n|&])/g) {
    my ($sep, $s, $e) = ($1, $-[0], $+[0]);
    push @segs, [$pos, substr($m, $pos, $s - $pos), $prev];
    exit 1 if $sep eq q(&);
    ($prev, $pos) = ($sep, $e);
  }
  push @segs, [$pos, substr($m, $pos), $prev];
  my %gitsub = map { $_ => 1 } qw(add status log diff show merge-base rev-parse branch commit);
  my ($commits, $cds, $start, $dir, @cw) = (0, 0, -1, q());
  my $cddir = q();
  for my $sg (@segs) {
    my ($off, $text, $psep) = @$sg;
    my @w = grep { length && !/^R+$/ } split /[ \t]+/, $text;
    next unless @w;
    if ($psep eq q(|)) { exit 1 unless $w[0] =~ /^(tail|head)$/; next }
    my $commit_seg = 0;
    if ($w[0] eq q(cd)) {
      exit 1 unless @w == 2;
      $cds++;
      if ($commits == 0) { my $i = index($text, $w[1]); $cddir = substr($c, $off + $i, length $w[1]) }
    } elsif ($w[0] =~ /^(echo|true|pwd)$/) {
    } elsif ($w[0] eq q(git)) {
      my $k = 1;
      my $cdir = q();
      if (($w[1] // q()) eq q(-C)) {
        exit 1 unless defined $w[2];
        my $i = index($text, $w[2], index($text, q(-C)));
        $cdir = substr($c, $off + $i, length $w[2]);
        $k = 3;
      }
      exit 1 unless defined $w[$k] && $gitsub{$w[$k]};
      if ($w[$k] eq q(commit)) {
        $commits++;
        $commit_seg = 1;
        $start = $off + index($text, q(git));
        $dir = $cdir;
        @cw = @w[$k + 1 .. $#w];
      }
    } else { exit 1 }
    exit 1 if !$commit_seg && grep { /^H+$/ } @w; # a heredoc only for the commit
  }
  exit 1 unless $commits == 1 && $cds <= 1;
  $dir = $cddir if $dir eq q();
  print join("\n", $start, $dir, @cw), "\n";
' 2>/dev/null)" || exit 0

start=$(sed -n 1p <<<"$analysis")
dirw=$(sed -n 2p <<<"$analysis")
mapfile -t words < <(sed -n '3,$p' <<<"$analysis")
[[ $start =~ ^[0-9]+$ ]] && [ "${cmd:start:3}" = git ] || exit 0

dir=$cwd
if [ -n "$dirw" ]; then
  dir=${dirw#[\"\']}; dir=${dir%[\"\']}
  [[ $dir == "~"* ]] && dir=$HOME${dir#\~}
  [[ $dir == /* ]] || dir=$cwd/$dir
fi

top="$(target_ok "$dir")" || exit 0
real="$(cd "$top" && pwd -P)"
merging=0
git -C "$top" rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1 && merging=1
flags_ok "$merging" "${words[@]}" || exit 0
[ "$(git -C "$top" config --get core.hooksPath 2>/dev/null)" != /dev/null ] || exit 0

# a deny rule on git commit (user, project or managed settings) must keep working: the rewrite would dodge it
for s in "$HOME/.claude/settings.json" "$HOME/.claude/settings.local.json" "${CLAUDE_PROJECT_DIR:-$top}/.claude/settings.json" \
  "${CLAUDE_PROJECT_DIR:-$top}/.claude/settings.local.json" "$top/.claude/settings.json" "$top/.claude/settings.local.json" \
  /etc/claude-code/managed-settings.json; do
  [ -f "$s" ] || continue
  jq -e '[.permissions.deny[]? | strings | select(test("^Bash($|\\((\\*|git( \\*|:\\*)?|git commit([ :*].*)?)\\))"))] | length > 0' \
    "$s" >/dev/null 2>&1 && exit 0
done

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

# a one-time token for the wrapper; old ones are dropped
mkdir -p "$TOKENS" 2>/dev/null && chmod 700 "$TOKENS" 2>/dev/null || exit 0
find "$TOKENS" -type f -mmin +5 -delete 2>/dev/null
token="$(od -An -N16 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n')"
[[ $token =~ ^[0-9a-f]{32}$ ]] || exit 0
printf '%s' "$top" >"$TOKENS/$token" || exit 0

printf -v qself '%q' "$SELF"
new="${cmd:0:start}bash $qself --token $token${cmd:start+3}"
jq -c --arg c "$new" '{hookSpecificOutput: {hookEventName: "PreToolUse",
  updatedInput: (.tool_input + {command: $c}),
  additionalContext: "worker-commit (ADR 0062): el git commit de este worker corrió por worker-commit.sh, que el ask de git commit del repo no frena; el resto del comando pasó por las reglas de siempre."}}' <<<"$input" 2>/dev/null
exit 0
