#!/usr/bin/env bash
# test-stack-sync.sh - offline checks for scripts/stack-sync.sh (ADR 0032, 0045): temp repos, a fake gh and a fake
# orca. Covers: base merged (merge trunk, push, retarget), base with new commits, trunk conflict (also with GitHub's
# mergeable still UNKNOWN), untracked files ignored, a local commit not pushed is left alone, dirty worktree, worktree
# not at the PR head, a conflict opens one Claude in its worktree once, merged PRs lose worktree and branch (not when
# stacked), and --precheck (ETag: syncs only when something changed, always exits 1).
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
    *" --author "*" --state merged "*) cat "$FAKE_GH/merged-mine.json" 2>/dev/null || echo '[]' ;;
    *" --author "*) cat "$FAKE_GH/open.json" ;;
    *" --state merged "*) head=$(sed -nE 's/.*--head ([^ ]+).*/\1/p' <<<"$*"); cat "$FAKE_GH/merged-$head.json" 2>/dev/null || echo '[]' ;;
  esac
fi
if [ "$1" = api ]; then printf 'HTTP/2.0 %s OK\r\nEtag: "e1"\r\n\r\n[]\n' "$(cat "$FAKE_GH/api-status")"; fi
exit 0
EOF
chmod +x "$W/bin/gh"
# fake orca: logs every call; `worktree rm` fails, so the script falls back to git worktree remove
cat >"$W/bin/orca" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"$FAKE_GH/orca"
[ "$1 $2" = "worktree rm" ] && exit 1
exit 0
EOF
chmod +x "$W/bin/orca"
echo 200 >"$W/gh/api-status"
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
branch eleven dev         # PR 11: conflicts with dev, but GitHub still says UNKNOWN
branch twelve dev         # PR 12: merged, clean worktree at its head -> removed
git -C "$R" fetch -q
c "$W/root/app-three" shared.txt from-three; git -C "$W/root/app-three" push -q origin three
c "$W/root/app-eight" shared.txt from-eight; git -C "$W/root/app-eight" push -q origin eight
# dev moves: one is squash-merged, and dev touches five.txt so five conflicts
git -C "$R" merge -q --squash origin/one >/dev/null; git -C "$R" commit -qm "squash one"
c "$R" five.txt from-dev; git -C "$R" push -q origin dev
c "$W/root/app-five" five.txt from-five; git -C "$W/root/app-five" push -q origin five
c "$W/root/app-eleven" five.txt from-eleven; git -C "$W/root/app-eleven" push -q origin eleven
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
printf '[%s,%s,%s,%s,%s,%s,%s,%s,%s]\n' "$(row 2 two one MERGEABLE)" "$(row 3 three dev MERGEABLE)" "$(row 4 four three MERGEABLE)" \
  "$(row 5 five dev CONFLICTING)" "$(row 6 six dev MERGEABLE)" "$(row 7 seven dev MERGEABLE)" "$(row 8 eight three MERGEABLE)" \
  "$(rowp 10 ten)" "$(row 11 eleven dev UNKNOWN)" >"$W/gh/open.json"
echo '[{"number":1}]' >"$W/gh/merged-one.json"
printf '[{"number":1,"headRefName":"one","headRefOid":"%s"},{"number":12,"headRefName":"twelve","headRefOid":"%s"}]\n' "$(oid one)" "$(oid twelve)" >"$W/gh/merged-mine.json"

bash "$SYNC" >/dev/null 2>&1; out="$(cat "$W/state/stack-sync.log")"
anc() { git -C "$W/root/app-$1" merge-base --is-ancestor "origin/$2" HEAD; }
pushed() { git -C "$W/root/app-$1" fetch -q origin; [ "$(git -C "$W/root/app-$1" rev-parse HEAD)" = "$(git -C "$W/root/app-$1" rev-parse "origin/$1")" ]; }

check "base merged: two gets origin/dev and is pushed" 'anc two dev && pushed two'
check "base merged: two is retargeted to dev" 'grep -q "pr edit 2 --repo org/app --base dev" "$W/gh/calls"'
check "base with new commits: four gets origin/three and is pushed despite an untracked file" 'anc four three && pushed four'
check "a local commit is not pushed by the script" '! pushed ten && grep -q "#10.*no está en la punta" <<<"$out"'
L="$W/gh/orca"
check "trunk conflict on five: merge aborted, a Claude opened in its worktree" 'grep -q "agent launch --agent claude --worktree path:$W/root/app-five" "$L" && [ -z "$(git -C "$W/root/app-five" status --porcelain)" ]'
check "conflict with the base on eight: its Claude points at its worktree" 'grep -q "worktree path:$W/root/app-eight" "$L"'
check "mergeable UNKNOWN but conflicting locally: eleven gets its Claude" 'grep -q "worktree path:$W/root/app-eleven" "$L"'
check "the brief tells the agent to push without force" 'grep -q "git push origin HEAD:five" "$W/state/specs/org_app-5.md" && ! grep -q -- "--force" "$W/state/specs/org_app-5.md"'
check "dirty worktree is skipped and kept" '[ "$(cat "$W/root/app-six/six.txt")" = dirty ] && grep -q "#6.*cambios sin commitear" <<<"$out"'
check "worktree not at the PR head is skipped" 'grep -q "#7.*no está en la punta" <<<"$out"'
check "three (trunk-based, mergeable) is not touched" '! grep -q "#3 " <<<"$out"'
check "merged twelve: worktree and local branch removed" '[ ! -d "$W/root/app-twelve" ] && ! git -C "$R" rev-parse -q --verify refs/heads/twelve >/dev/null'
check "merged twelve: remote branch deleted" '! git -C "$R" ls-remote --exit-code --heads origin twelve >/dev/null'
check "merged one keeps its worktree: two is stacked on it" '[ -d "$W/root/app-one" ] && grep -q "#1.*apilado encima" <<<"$out"'
n_launch=$(grep -c "agent launch" "$L")
bash "$SYNC" >/dev/null 2>&1
check "a second run does not open the same conflicts again" '[ "$(grep -c "agent launch" "$L")" -eq "$n_launch" ]'
echo 304 >"$W/gh/api-status"; calls=$(wc -l <"$W/gh/calls")
check "--precheck right after a sync, nothing changed (304): exits 1 without syncing" '! bash "$SYNC" --precheck >/dev/null 2>&1 && [ "$(tail -n +$((calls + 1)) "$W/gh/calls" | grep -c "pr list")" -eq 0 ]'
echo 200 >"$W/gh/api-status"; calls=$(wc -l <"$W/gh/calls")
check "--precheck when a PR changed (200): syncs and still exits 1" '! bash "$SYNC" --precheck >/dev/null 2>&1 && tail -n +$((calls + 1)) "$W/gh/calls" | grep -q "pr list"'
check "never force-pushes or rebases" '! grep -qE -- "git -C [^ ]+ (rebase|push[^#]*--force)" "$SYNC"'
check "dry-run changes nothing" 'before=$(git -C "$W/root/app-four" rev-parse HEAD); bash "$SYNC" --dry-run >/dev/null 2>&1; [ "$(git -C "$W/root/app-four" rev-parse HEAD)" = "$before" ]'

echo "$pass passed, $failn failed"
[ "$failn" -eq 0 ]
