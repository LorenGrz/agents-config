#!/usr/bin/env bash
# leak-guard.sh - keep private organization data out of this public repo.
#
# Usage: leak-guard.sh [--all | --staged | --message <file> | --log <git-log-args...> | --refs <name...>]
#   --all      every tracked file: names and content (default)
#   --staged   files being committed: names (renames included) and the staged blobs
#   --message  a commit message file (used by the commit-msg hook)
#   --log      commit messages, ref names and patches of a git log range, e.g. --log A..B
#   --refs     branch/tag names about to be pushed (the pre-push hook)
#
# Checks (exit 1 on any):
#   1. nothing tracked under organizations/ except README.md and _template/
#   2. no blocklist term (case-insensitive, fixed string) in names or content, binary files included
#   3. no obvious secret (AWS key, private key block, GitHub/OpenAI-style token)
#
# It NEVER prints a blocklist term: a path that contains one is shown as <path #id>, and in CI
# (CI set) every path is shown that way. Messages and content are reported as file:line only.
#
# Blocklist: one term per line (# comments ok), from $LEAK_BLOCKLIST (newline-separated, for a
# CI secret) and ~/.config/agents-config/blocklist (override: LEAK_BLOCKLIST_FILE); scripts/orgs.sh
# maintains the local file. Without any term: a warning locally, a failure in CI.
# Limits: it only knows the listed terms (renamed or abbreviated names pass) and it cannot see
# history that was already pushed.
set -uo pipefail
shopt -s lastpipe   # the last stage of a pipeline runs in this shell, so `fail` survives

HUB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$HUB"
MODE="${1:---all}"; [ $# -gt 0 ] && shift
BL_FILE="${LEAK_BLOCKLIST_FILE:-$HOME/.config/agents-config/blocklist}"
SECRETS='AKIA[0-9A-Z]{16}|-----BEGIN ([A-Z]+ )?PRIVATE KEY-----|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{40,}|sk-[A-Za-z0-9]{32,}'
fail=0
tf="$(mktemp)"; trap 'rm -f "$tf"' EXIT

{ printf '%s\n' "${LEAK_BLOCKLIST:-}"; [ -f "$BL_FILE" ] && cat "$BL_FILE"; } | sed -e 's/\r$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^\(#\|$\)/d' > "$tf"
have_terms=0; [ -s "$tf" ] && have_terms=1

has_term() { [ "$have_terms" -eq 1 ] && grep -qiF -f "$tf" <<<"$1"; }
# loc <path>: how a path may be shown (redacted when it holds a term, or always in CI)
loc() {
  if [ -n "${CI:-}" ] || has_term "$1"; then printf '<path #%s>' "$(printf '%s' "$1" | cksum | cut -d' ' -f1)"; else printf '%s' "$1"; fi
}
report() { echo "leak-guard: $*" >&2; fail=1; }
hit_list() { # hit_list <label> : reads "path:line" or "path" lines on stdin
  local n=0 shown=0 l p
  while IFS= read -r l; do
    n=$((n + 1)); [ "$shown" -lt 15 ] || continue
    shown=$((shown + 1))
    if [ -n "${CI:-}" ] || has_term "$l"; then echo "  <hit #$(printf '%s' "$l" | cksum | cut -d' ' -f1)>" >&2; else echo "  $l" >&2; fi
  done
  [ "$n" -gt 0 ] && report "$1: $n hit(s)"
  return 0
}

# --- 1. organizations/ must stay untracked (count only: the names can be org names)
n="$(git ls-files organizations | grep -cvE '^organizations/(README\.md|_template/)' || true)"
[ "${n:-0}" -gt 0 ] && report "$n tracked file(s) under organizations/ (each org is its own private repo)"

scan_names() { # scan_names : reads NUL-separated paths
  local f
  while IFS= read -r -d '' f; do has_term "$f" && echo "$f"; done | hit_list "blocklist term in a file name"
}

case "$MODE" in
  --all)
    git ls-files -z | scan_names
    [ "$have_terms" -eq 1 ] && { git ls-files -z | xargs -0 -r grep -aHniF -f "$tf" -- 2>/dev/null | cut -d: -f1,2 | sort -u | hit_list "blocklist term in content"; }
    git ls-files -z | xargs -0 -r grep -aHnE "$SECRETS" -- 2>/dev/null | cut -d: -f1,2 | sort -u | hit_list "possible secret"
    ;;
  --staged)
    git diff --cached --name-only -z --diff-filter=ACMR | scan_names
    while IFS= read -r -d '' f; do
      if [ "$have_terms" -eq 1 ]; then git show ":$f" 2>/dev/null | grep -aniF -f "$tf" | cut -d: -f1 | while read -r n; do printf '%s:%s\n' "$f" "$n"; done; fi
    done < <(git diff --cached --name-only -z --diff-filter=ACMR) | hit_list "blocklist term in staged content"
    while IFS= read -r -d '' f; do
      git show ":$f" 2>/dev/null | grep -anE "$SECRETS" | cut -d: -f1 | while read -r n; do printf '%s:%s\n' "$f" "$n"; done
    done < <(git diff --cached --name-only -z --diff-filter=ACMR) | hit_list "possible secret in staged content"
    ;;
  --message)
    f="${1:-}"; [ -f "$f" ] || { echo "leak-guard: --message needs a file" >&2; exit 2; }
    msg="$(grep -av '^#' "$f" || true)"   # git comments (and the -v diff) are not part of the message
    [ "$have_terms" -eq 1 ] && { grep -aiF -f "$tf" <<<"$msg" | sed 's|.*|commit message|' | hit_list "blocklist term in the commit message"; }
    grep -aE "$SECRETS" <<<"$msg" | sed 's|.*|commit message|' | hit_list "possible secret in the commit message"
    ;;
  --log)
    [ $# -gt 0 ] || { echo "leak-guard: --log needs git log arguments" >&2; exit 2; }
    if ! out="$(git log --format='%H%n%B%n%D%n--' "$@" 2>/dev/null)"; then
      echo "leak-guard: git log failed for the given range (unknown commit?); nothing was checked" >&2; exit 2
    fi
    # patches too: a term added in one commit and removed in the next is still in the pushed history
    if ! patches="$(git log -p --format= "$@" 2>/dev/null)"; then echo "leak-guard: git log -p failed" >&2; exit 2; fi
    [ "$have_terms" -eq 1 ] && { grep -aniF -f "$tf" <<<"$out" | cut -d: -f1 | sed 's|^|log line |' | hit_list "blocklist term in commit messages or ref names"; }
    [ "$have_terms" -eq 1 ] && { grep -aiF -f "$tf" <<<"$patches" | sed 's|.*|patch|' | hit_list "blocklist term in the patches of the range"; }
    grep -anE "$SECRETS" <<<"$out" | cut -d: -f1 | sed 's|^|log line |' | hit_list "possible secret in commit messages"
    grep -aE "$SECRETS" <<<"$patches" | sed 's|.*|patch|' | hit_list "possible secret in the patches of the range"
    ;;
  --refs)
    for r in "$@"; do has_term "$r" && echo "$r"; done | sed 's|.*|ref|' | hit_list "blocklist term in a branch or tag name"
    ;;
  *) echo "usage: leak-guard.sh [--all | --staged | --message <file> | --log <args> | --refs <name...>]" >&2; exit 2 ;;
esac

if [ "$have_terms" -eq 0 ]; then
  if [ -n "${CI:-}" ]; then report "no blocklist configured in CI (set the LEAK_BLOCKLIST secret); term checks did not run"
  else echo "leak-guard: no blocklist configured (organization and secret checks only)" >&2; fi
fi

[ "$fail" -eq 0 ] && echo "leak-guard: ok ($MODE)"
exit "$fail"
