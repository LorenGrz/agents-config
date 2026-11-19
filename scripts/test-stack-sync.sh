#!/usr/bin/env bash
# test-stack-sync.sh - offline checks for scripts/stack-sync.sh (ADR 0032): temp repos, a fake gh and a
# no Orca (ADR 0043: conflicts go to a queue). Covers: base merged (merge trunk, push, retarget), base with new commits, trunk
# conflict, untracked files ignored, a local commit not pushed is left alone, dirty worktree, worktree not at the PR head, a merge conflict queued only once, and --pending / --sync-pending as the precheck (ADR 0044).
set -uo pipefail
HUB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYNC="$HUB/scripts/stack-sync.sh"
W="$(mktemp -d)"; [ -n "${KEEP:-}" ] || trap 'rm -rf "$W"' EXIT; echo "tmp: $W" >&2
pass=0; failn=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"; else failn=$((failn + 1)); echo "FAIL $1"; fi; }
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

# --- fake gh: answers from files in $W/gh, logs every call
mkdir -p "$W/bin" "$W/gh"
cat >"$W/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"$FAKE_GH/calls"
if [ "$1 $2" = "pr list" ]; then
  case " $* " in
    *" --author "*) cat "$FAKE_GH/open.json" ;;
    *" --state merged "*) head=$(sed -nE 's/.*--head ([^ ]+).*/\1/p' <<<"$*"); cat "$FAKE_GH/merged-$head.json" 2>/dev/null || echo '[]' ;;
  esac
fi
exit 0
EOF
chmod +x "$W/bin/gh"
export PATH="$W/bin:$PATH" FAKE_GH="$W/gh" STACK_SYNC_NOTIFY=0
export STACK_SYNC_STATE="$W/state" STACK_SYNC_ROOTS="$W/root" STACK_SYNC_OWNER=org

# --- repos: bare origin "github.com/org/app", main clone on dev, one worktree per branch
git init -q --bare "$W/origin.git"
git clone -q "$W/origin.git" "$W/root/app" 2>/dev/null
R="$W/root/app"
git -C "$R" remote set-url origin "https://github.com/org/app.git"
git -C "$R" config url."$W/origin.git".insteadOf "https://github.com/org/app.git"
c() { printf '%s\n' "$3" >"$1/$2"; git -C "$1" add -A; git -C "$1" commit -qm "$2"; }
git -C "$R" switch -q -c dev; c "$R" base.txt base; git -C "$R" push -q origin dev
branch() { git -C "$R" worktree add -q -b "$1" "$W/root/app-$1" "origin/$2" 2>/dev/null; c "$W/root/app-$1" "$1.txt" "$1"; git -C "$W/root/app-$1" push -q origin "$1"; }
git -C "$R" fetch -q
branch one dev            # PR 1 -> dev (its PR gets merged)
branch two one            # PR 2 stacked on one
branch three dev          # PR 3 -> dev
branch four three         # PR 4 stacked on three (three gets new commits)
branch five dev           # PR 5 -> dev, conflicts with dev
branch six dev            # PR 6: dirty worktree
branch seven dev          # PR 7: local commit not pushed
branch eight three        # PR 8 stacked on three, conflicts with three
branch ten dev            # PR 10: local merge commit not pushed
git -C "$R" fetch -q
c "$W/root/app-three" shared.txt from-three; git -C "$W/root/app-three" push -q origin three
c "$W/root/app-eight" shared.txt from-eight; git -C "$W/root/app-eight" push -q origin eight
# dev moves: one is squash-merged, and dev touches five.txt so five conflicts
git -C "$R" merge -q --squash origin/one >/dev/null; git -C "$R" commit -qm "squash one"
c "$R" five.txt from-dev; git -C "$R" push -q origin dev
c "$W/root/app-five" five.txt from-five; git -C "$W/root/app-five" push -q origin five
echo dirty >"$W/root/app-six/six.txt"
echo lock >"$W/root/app-four/pnpm-lock.yaml"   # untracked: must not block four
c "$W/root/app-seven" local.txt not-pushed
c "$W/root/app-ten" ten-merge.txt not-pushed
git -C "$R" fetch -q

oid() { git -C "$W/root/app-$1" rev-parse "origin/$1"; }
row() { printf '{"number":%s,"headRefName":"%s","baseRefName":"%s","mergeable":"%s","headRefOid":"%s"}' "$1" "$2" "$3" "$4" "$(oid "$2")"; }
# ten: the PR head is the parent of the local commit
oidp() { git -C "$W/root/app-$1" rev-parse HEAD~1; }
rowp() { printf '{"number":%s,"headRefName":"%s","baseRefName":"dev","mergeable":"CONFLICTING","headRefOid":"%s"}' "$1" "$2" "$(oidp "$2")"; }
printf '[%s,%s,%s,%s,%s,%s,%s,%s]\n' "$(row 2 two one MERGEABLE)" "$(row 3 three dev MERGEABLE)" "$(row 4 four three MERGEABLE)" \
  "$(row 5 five dev CONFLICTING)" "$(row 6 six dev MERGEABLE)" "$(row 7 seven dev MERGEABLE)" "$(row 8 eight three MERGEABLE)" \
  "$(rowp 10 ten)" >"$W/gh/open.json"
echo '[{"number":1}]' >"$W/gh/merged-one.json"

bash "$SYNC" >/dev/null 2>&1; out="$(cat "$W/state/stack-sync.log")"
anc() { git -C "$W/root/app-$1" merge-base --is-ancestor "origin/$2" HEAD; }
pushed() { git -C "$W/root/app-$1" fetch -q origin; [ "$(git -C "$W/root/app-$1" rev-parse HEAD)" = "$(git -C "$W/root/app-$1" rev-parse "origin/$1")" ]; }

check "base merged: two gets origin/dev and is pushed" 'anc two dev && pushed two'
check "base merged: two is retargeted to dev" 'grep -q "pr edit 2 --repo org/app --base dev" "$W/gh/calls"'
check "base with new commits: four gets origin/three and is pushed despite an untracked file" 'anc four three && pushed four'
check "the brief tells the agent to push without force" 'grep -q "git push origin HEAD:five" "$W/state/queue/org_app-5.md" && ! grep -q -- "--force" "$W/state/queue/org_app-5.md"'
check "a local commit is not pushed by the script" '! pushed ten && grep -q "#10.*no está en la punta" <<<"$out"'
Q="$W/state/queue"
check "trunk conflict on five: merge aborted, brief queued" 'grep -q "PR #5 de org/app" "$Q/org_app-5.md" && [ -z "$(git -C "$W/root/app-five" status --porcelain)" ]'
check "conflict with the base on eight: its brief points at its worktree" 'grep -q "$W/root/app-eight" "$Q/org_app-8.md"'
check "--pending exits 0 with a queued conflict" 'bash "$SYNC" --pending'
check "dirty worktree is skipped and kept" '[ "$(cat "$W/root/app-six/six.txt")" = dirty ] && grep -q "#6.*cambios sin commitear" <<<"$out"'
check "worktree not at the PR head is skipped" 'grep -q "#7.*no está en la punta" <<<"$out" && ! anc seven dev 2>/dev/null || true; grep -q "#7.*no está en la punta" <<<"$out"'
check "three (trunk-based, mergeable) is not touched" '! grep -q "#3 " <<<"$out"'
rm -f "$Q"/*.md   # what the agent does once it resolved them
bash "$SYNC" >/dev/null 2>&1
check "a second run does not requeue the same conflicts" '! ls "$Q"/*.md >/dev/null 2>&1'
check "--pending exits 1 with an empty queue" '! bash "$SYNC" --pending'
check "--sync-pending exits 1 when nothing is queued after the sync" '! bash "$SYNC" --sync-pending >/dev/null 2>&1'
echo x >"$Q/org_app-99.md"
check "--sync-pending exits 0 when a conflict waits" 'bash "$SYNC" --sync-pending >/dev/null 2>&1'
rm -f "$Q/org_app-99.md"
check "never force-pushes or rebases" '! grep -qE -- "git -C [^ ]+ (rebase|push[^#]*--force)" "$SYNC"'
check "dry-run changes nothing" 'before=$(git -C "$W/root/app-four" rev-parse HEAD); bash "$SYNC" --dry-run >/dev/null 2>&1; [ "$(git -C "$W/root/app-four" rev-parse HEAD)" = "$before" ]'

echo "$pass passed, $failn failed"
[ "$failn" -eq 0 ]
