#!/usr/bin/env bash
# test-worktree-frenar.sh - offline checks for config/hooks/worktree-frenar.sh (ADR 0065): a temp repo with a
# linked worktree and background processes whose cwd is inside it.
set -uo pipefail
HUB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRENAR="$HUB/config/hooks/worktree-frenar.sh"
W="$(mktemp -d)"; trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$W"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
pass=0; failn=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"; else failn=$((failn + 1)); echo "FAIL $1"; fi; }
alive() { kill -0 "$1" 2>/dev/null; }

R="$W/repo"; mkdir -p "$R" && git -C "$R" init -q -b main && echo .cache/ >"$R/.gitignore" \
  && git -C "$R" add .gitignore && git -C "$R" commit -q -m init  # .cache/ ignored, like .next in a real repo
git -C "$R" worktree add -q --detach "$R-wt"

# a writer like next dev, and one that ignores TERM
(cd "$R-wt" && exec bash -c 'while :; do mkdir -p .cache; date >.cache/x; sleep 0.1; done') & writer=$!
(cd "$R-wt" && exec bash -c 'trap "" TERM; while :; do sleep 0.2; done') & stubborn=$!
(cd "$R" && exec sleep 30) & outside=$!
sleep 0.3

out="$(bash "$FRENAR" --listar "$R-wt")"; code=$?
check "--listar exits 1 and lists what runs inside" '[ $code = 1 ] && grep -q "$writer" <<<"$out" && alive $writer'
check "--listar ignores processes outside the worktree" '! grep -q "$outside" <<<"$out"'

(cd "$R-wt" && ORCA_WORKTREE_PATH="$R-wt" bash "$FRENAR" >/dev/null); code=$?
wait $writer $stubborn 2>/dev/null
check "stops what runs inside, TERM-ignoring included (Orca's env, cwd inside)" '[ $code = 0 ] && ! alive $writer && ! alive $stubborn'
check "leaves processes outside alone" 'alive $outside'
check "--listar with nothing running exits 0" 'bash "$FRENAR" --listar "$R-wt" >/dev/null'
git -C "$R" worktree remove "$R-wt" 2>/dev/null
check "the worktree is then removed completely" '[ ! -e "$R-wt" ]'

out="$(bash "$FRENAR" "$R" 2>&1)"; code=$?
check "refuses the main worktree" '[ $code = 1 ] && grep -q "principal" <<<"$out" && alive $outside'
mkdir -p "$W/plain"
check "outside git does nothing and exits 0" 'bash "$FRENAR" "$W/plain"'
check "bash -n passes" 'bash -n "$FRENAR"'

echo "$pass passed, $failn failed"
[ "$failn" -eq 0 ]
