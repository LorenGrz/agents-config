#!/usr/bin/env bash
# leak-guard.sh - keep private organization data out of this public repo.
#
# Checks (fails with exit 1; never prints the matched term, CI logs may be public):
#   1. nothing tracked under organizations/ except README.md and _template/
#   2. no blocklist term (case-insensitive, fixed string) in the scanned content
#   3. no obvious secret (AWS key, private key block, GitHub/OpenAI-style token)
#
# Blocklist: one term per line (# comments ok), from $LEAK_BLOCKLIST (newline-separated,
# for a CI secret) and ~/.config/agents-config/blocklist (override: LEAK_BLOCKLIST_FILE).
# Terms are never stored in this repo; scripts/orgs.sh maintains the local file.
#
# Usage: leak-guard.sh [--staged | --all]   (default --all; --staged = lines being committed)
set -uo pipefail

HUB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$HUB"
MODE="${1:---all}"
BL_FILE="${LEAK_BLOCKLIST_FILE:-$HOME/.config/agents-config/blocklist}"
SECRETS='AKIA[0-9A-Z]{16}|-----BEGIN ([A-Z]+ )?PRIVATE KEY-----|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{40,}|sk-[A-Za-z0-9]{32,}'
fail=0

# 1. organizations/ must stay untracked
tracked="$(git ls-files organizations | grep -vE '^organizations/(README\.md|_template/)' || true)"
if [ -n "$tracked" ]; then
  echo "leak-guard: tracked files under organizations/ (each org is its own private repo):" >&2
  echo "$tracked" | sed 's/^/  /' >&2; fail=1
fi

# content to scan, as "file:line:text"
if [ "$MODE" = "--staged" ]; then
  content="$(git diff --cached -U0 --no-color --no-ext-diff --src-prefix=a/ --dst-prefix=b/ | awk '
    /^\+\+\+ b\// { file=substr($0,7); next }
    /^@@/ { split($3,a,","); line=substr(a[1],2)+0; next }
    /^\+/ && !/^\+\+\+/ { print file ":" line ":" substr($0,2); line++ }')"
else
  content="$(git ls-files -z | xargs -0 grep -InH . 2>/dev/null || true)"
fi

terms="$( { printf '%s\n' "${LEAK_BLOCKLIST:-}"; [ -f "$BL_FILE" ] && cat "$BL_FILE"; } | sed '/^[[:space:]]*\(#\|$\)/d')"
if [ -n "$terms" ]; then
  hits="$(grep -iFf <(printf '%s\n' "$terms") <<<"$content" | cut -d: -f1,2 | sort -u || true)"
  [ -n "$hits" ] && { echo "leak-guard: blocklist hit at:" >&2; sed 's/^/  /' <<<"$hits" >&2; fail=1; }
else
  echo "leak-guard: no blocklist configured (checks 1 and 3 only)" >&2
fi

hits="$(grep -E "$SECRETS" <<<"$content" | cut -d: -f1,2 | sort -u || true)"
[ -n "$hits" ] && { echo "leak-guard: possible secret at:" >&2; sed 's/^/  /' <<<"$hits" >&2; fail=1; }

[ "$fail" -eq 0 ] && echo "leak-guard: ok ($MODE)"
exit "$fail"
