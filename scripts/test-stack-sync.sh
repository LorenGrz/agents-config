#!/usr/bin/env bash
# test-stack-sync.sh - offline checks for scripts/stack-sync.sh (ADR 0032, 0045): temp repos, a fake gh and a fake
# orca. Covers: base merged (merge trunk, push, retarget), base with new commits, trunk conflict (also with GitHub's
# mergeable still UNKNOWN), untracked files ignored, a local commit not pushed is left alone, dirty worktree, worktree
# not at the PR head, a conflict opens one Claude in its worktree once, merged PRs lose worktree and branch (not when
# stacked; with pnpm's untracked files too; another untracked file keeps it and is notified once), --precheck (ETag: syncs only when something changed, always exits 1),
# agents (ADR 0050): one per worktree at a time, at most 2 attempts per PR and day, Sonnet first and Opus second;
# and reviews (ADR 0047): someone else's review opens one Claude in that worktree once, my own review does not, a PR
# with a conflict agent gets no review agent, and a review on a PR without a worktree is notified once; and a red CI
# (ADR 0048): a failed check on the PR head opens one Claude once, a green CI does not, and a review goes first;
# a clean worktree only behind its PR head is fast-forwarded, and a PR below merged into a branch other than dev
# retargets the PR above to that branch.
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
# never the real config (it may point STACK_SYNC_ORCA at the real Orca): only the fakes above
export XDG_CONFIG_HOME="$W/config" STACK_SYNC_ORCA="$W/bin/orca"

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
branch thirteen dev       # PR 13: merged, only pnpm's untracked files -> removed with --force
branch fourteen dev       # PR 14: merged, another untracked file -> kept, notified once
branch fifteen dev        # PR 15: up to date, someone else asked for changes -> review agent
branch sixteen dev        # PR 16: up to date, only my own review -> nothing
branch eighteen dev       # PR 18: up to date, a CI check failed -> CI agent
branch nineteen dev       # PR 19: up to date, CI green -> nothing
branch twenty dev         # PR 20: clean worktree one commit behind its PR head -> fast-forward
branch nine dev           # PR 9: merged into three, not into dev
branch twentyone nine     # PR 21 stacked on nine -> gets origin/three, retargeted to three
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
echo lock >"$W/root/app-thirteen/pnpm-lock.yaml"; echo ws >"$W/root/app-thirteen/pnpm-workspace.yaml"
echo notes >"$W/root/app-fourteen/notas.txt"
c "$W/root/app-seven" local.txt not-pushed
c "$W/root/app-ten" ten-merge.txt not-pushed
c "$W/root/app-twenty" twenty-2.txt pushed; git -C "$W/root/app-twenty" push -q origin twenty; git -C "$W/root/app-twenty" reset -q --hard HEAD~1
git -C "$R" fetch -q

oid() { git -C "$W/root/app-$1" rev-parse "origin/$1"; }
row() { printf '{"number":%s,"headRefName":"%s","baseRefName":"%s","mergeable":"%s","headRefOid":"%s"}' "$1" "$2" "$3" "$4" "$(oid "$2")"; }
# ten: the PR head is the parent of the local commit
oidp() { git -C "$W/root/app-$1" rev-parse HEAD~1; }
# rowr <n> <branch> <reviews-json>: an up-to-date PR to dev, authored by me, with reviews
rowr() { printf '{"number":%s,"headRefName":"%s","baseRefName":"dev","mergeable":"MERGEABLE","headRefOid":"%s","author":{"login":"me"},"reviews":%s}' "$1" "$2" "$(oid "$2")" "$3"; }
# rowc <n> <branch> <checks-json>: an up-to-date PR to dev with CI checks and no reviews
rowc() { printf '{"number":%s,"headRefName":"%s","baseRefName":"dev","mergeable":"MERGEABLE","headRefOid":"%s","author":{"login":"me"},"reviews":[],"statusCheckRollup":%s}' "$1" "$2" "$(oid "$2")" "$3"; }
rev() { printf '{"id":"%s","author":{"login":"%s"},"state":"%s"}' "$1" "$2" "$3"; }
rowp() { printf '{"number":%s,"headRefName":"%s","baseRefName":"dev","mergeable":"CONFLICTING","headRefOid":"%s"}' "$1" "$2" "$(oidp "$2")"; }
ci18='[{"name":"Lint, tests y build","conclusion":"FAILURE"},{"name":"schema","conclusion":"SUCCESS"}]'
write_open() {
# five conflicts and also has a review: the conflict agent owns it. 17 has a review but no local worktree.
five_rev="$(row 5 five dev CONFLICTING | sed "s/}\$/,\"author\":{\"login\":\"me\"},\"reviews\":[$(rev R5 ana CHANGES_REQUESTED)]}/")"
printf '[%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s]\n' "$(row 2 two one MERGEABLE)" "$(row 3 three dev MERGEABLE)" "$(row 4 four three MERGEABLE)" \
  "$five_rev" "$(row 6 six dev MERGEABLE)" "$(row 7 seven dev MERGEABLE)" "$(row 8 eight three MERGEABLE)" \
  "$(rowp 10 ten)" "$(row 11 eleven dev UNKNOWN)" \
  "$(rowr 15 fifteen "[$(rev R15a me COMMENTED),$(rev R15 ana CHANGES_REQUESTED)]" | sed 's/}$/,"statusCheckRollup":[{"name":"tests","conclusion":"FAILURE"}]}/')" \
  "$(rowr 16 sixteen "[$(rev R16 me COMMENTED)]")" \
  '{"number":17,"headRefName":"seventeen","baseRefName":"dev","mergeable":"MERGEABLE","headRefOid":"x","author":{"login":"me"},"reviews":[{"id":"R17","author":{"login":"ana"},"state":"COMMENTED"}]}' \
  "$(rowc 18 eighteen "$ci18")" \
  "$(rowc 19 nineteen '[{"name":"Lint, tests y build","conclusion":"SUCCESS"}]')" \
  "$(row 20 twenty dev MERGEABLE)" "$(row 21 twentyone nine MERGEABLE)" \
  >"$W/gh/open.json"
}
write_open
echo '[{"number":1}]' >"$W/gh/merged-one.json"
echo '[{"number":9,"baseRefName":"three"}]' >"$W/gh/merged-nine.json"
printf '[{"number":1,"headRefName":"one","headRefOid":"%s"},{"number":12,"headRefName":"twelve","headRefOid":"%s"},{"number":13,"headRefName":"thirteen","headRefOid":"%s"},{"number":14,"headRefName":"fourteen","headRefOid":"%s"}]\n' \
  "$(oid one)" "$(oid twelve)" "$(oid thirteen)" "$(oid fourteen)" >"$W/gh/merged-mine.json"

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
check "twenty, clean and one commit behind: fast-forwarded to the PR head" '[ "$(git -C "$W/root/app-twenty" rev-parse HEAD)" = "$(oid twenty)" ] && grep -q "#20 .*atrasado -> fast-forward" <<<"$out"'
check "PR below merged into three, not dev: twentyone gets origin/three and is retargeted to three" 'anc twentyone three && pushed twentyone && grep -q "pr edit 21 --repo org/app --base three" "$W/gh/calls" && ! grep -q "pr edit 21 --repo org/app --base dev" "$W/gh/calls"'
check "three behind dev (no conflict): gets origin/dev and is pushed" 'anc three dev && pushed three && grep -q "#3 .*atrás de dev" <<<"$out"'
check "merged twelve: worktree and local branch removed" '[ ! -d "$W/root/app-twelve" ] && ! git -C "$R" rev-parse -q --verify refs/heads/twelve >/dev/null'
check "merged twelve: remote branch deleted" '! git -C "$R" ls-remote --exit-code --heads origin twelve >/dev/null'
check "merged one keeps its worktree: two is stacked on it" '[ -d "$W/root/app-one" ] && grep -q "#1.*apilado encima" <<<"$out"'
check "merged thirteen with only pnpm's untracked files: worktree and branch removed" '[ ! -d "$W/root/app-thirteen" ] && ! git -C "$R" rev-parse -q --verify refs/heads/thirteen >/dev/null'
check "merged fourteen with another untracked file: kept, and the log names the file" '[ -f "$W/root/app-fourteen/notas.txt" ] && grep -q "#14.*lo frena: notas.txt" <<<"$out"'
check "review by someone else: a Claude opened in fifteen's worktree" 'grep -q "worktree path:$W/root/app-fifteen" "$L" && grep -q "#15.*review de ana" <<<"$out"'
check "the review brief keeps line endings, brings dev before pushing and answers each comment" 'f="$W/state/specs/org_app-15-review.md"; grep -q "ignore-cr-at-eol" "$f" && grep -q "merge --no-edit origin/dev" "$f" && grep -q "comments/<id>/replies" "$f" && grep -q "No resuelvas los hilos" "$f"'
check "only my own review: no agent for sixteen" '! grep -q "app-sixteen" "$L"'
check "conflict and review on five: only the conflict agent" '[ "$(grep -c "worktree path:$W/root/app-five" "$L")" -eq 1 ] && [ ! -e "$W/state/specs/org_app-5-review.md" ]'
check "review on a PR without a worktree is notified" 'grep -q "#17.*no hay worktree local" <<<"$out"'
check "red CI: a Claude opened in eighteen's worktree, naming the failed check" 'grep -q "worktree path:$W/root/app-eighteen" "$L" && grep -q "#18.*CI en rojo (Lint, tests y build)" <<<"$out"'
check "the CI brief reads the failed logs and never forces" 'grep -q "log-failed" "$W/state/specs/org_app-18-ci.md" && ! grep -q -- "--force" "$W/state/specs/org_app-18-ci.md"'
check "green CI: no agent for nineteen" '! grep -q "app-nineteen" "$L"'
check "review and red CI on fifteen: only the review agent in this run" '[ "$(grep -c "worktree path:$W/root/app-fifteen" "$L")" -eq 1 ] && [ ! -e "$W/state/specs/org_app-15-ci.md" ]'
n_launch=$(grep -c "agent launch" "$L")
# the first run pushed merges: the PRs' heads moved, and eighteen's new head has its CI still running
ci18='[{"name":"Lint, tests y build","conclusion":null,"state":"PENDING"}]'
write_open
check "an agent's worktree is marked busy while it works" '[ -e "$W/state/busy/org_app-15" ]'
check "the brief tells the agent to remove its busy mark" 'grep -q "rm -f $W/state/busy/org_app-15" "$W/state/specs/org_app-15-review.md"'
check "a conflict agent's first attempt runs on Sonnet" 'grep "worktree path:$W/root/app-five" "$L" | head -1 | grep -q -- "--model claude-sonnet-5-5"'
check "a review agent runs on Opus from the first attempt" 'grep "worktree path:$W/root/app-fifteen" "$L" | head -1 | grep -q -- "--model claude-opus-5-5 --effort high"'
rm -f "$W/state/busy/"* # the agents of the first run ended
bash "$SYNC" >/dev/null 2>&1
check "a second run opens the CI agent of fifteen, now that its review has one" '[ -e "$W/state/specs/org_app-15-ci.md" ]'
check "a second run does not open the same conflicts, reviews or CI fixes again" '[ "$(grep -c "agent launch" "$L")" -eq "$((n_launch + 1))" ]'
check "a second run does not notify the blocked fourteen again" '[ "$(grep -c "#14" "$W/state/stack-sync.log")" -eq 1 ]'
check "a second run does not notify the review on seventeen again" '[ "$(grep -c "#17" "$W/state/stack-sync.log")" -eq 1 ]'
check "the second attempt on a PR runs on Opus at high effort" 'grep "worktree path:$W/root/app-fifteen" "$L" | tail -1 | grep -q -- "--model claude-opus-5-5 --effort high"'

# third run: eighteen is red again, but its agent is still working; fifteen has a new review, but used its 2 attempts
ci18='[{"name":"Lint, tests y build","conclusion":"FAILURE"}]'
git -C "$W/root/app-eighteen" fetch -q; write_open
sed -i 's/"id":"R15","author":{"login":"ana"}/"id":"R15b","author":{"login":"ana"}/' "$W/gh/open.json"
rm -f "$W/state/busy/"*; : >"$W/state/busy/org_app-18"; n3=$(grep -c "agent launch" "$L")
bash "$SYNC" >/dev/null 2>&1
check "a worktree with a working agent is skipped: no merge, no second agent" '[ "$(grep -c "agent launch" "$L")" -eq "$n3" ] && grep -q "#18.*hay un agente trabajando" "$W/state/stack-sync.log"'
check "after 2 attempts in a day, no third agent and Loren is told once" '! grep -q "org_app-15-.*R15b" "$W/state/stack-sync.log" && grep -q "#15.*2 intentos automáticos" "$W/state/stack-sync.log"'
bash "$SYNC" >/dev/null 2>&1
check "the out-of-attempts notice is not repeated" '[ "$(grep -c "#15.*2 intentos automáticos" "$W/state/stack-sync.log")" -eq 1 ]'
echo 304 >"$W/gh/api-status"; calls=$(wc -l <"$W/gh/calls")
check "--precheck right after a sync, nothing changed (304): exits 1 without syncing" '! bash "$SYNC" --precheck >/dev/null 2>&1 && [ "$(tail -n +$((calls + 1)) "$W/gh/calls" | grep -c "pr list")" -eq 0 ]'
echo 200 >"$W/gh/api-status"; calls=$(wc -l <"$W/gh/calls")
check "--precheck when a PR changed (200): syncs and still exits 1" '! bash "$SYNC" --precheck >/dev/null 2>&1 && tail -n +$((calls + 1)) "$W/gh/calls" | grep -q "pr list"'
check "never force-pushes or rebases" '! grep -qE -- "git -C [^ ]+ (rebase|push[^#]*--force)" "$SYNC"'
check "dry-run changes nothing" 'before=$(git -C "$W/root/app-four" rev-parse HEAD); bash "$SYNC" --dry-run >/dev/null 2>&1; [ "$(git -C "$W/root/app-four" rev-parse HEAD)" = "$before" ]'

echo "$pass passed, $failn failed"
[ "$failn" -eq 0 ]
