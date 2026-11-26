#!/usr/bin/env bash
# test-worktree-cleanup.sh - offline checks for config/hooks/worktree-cleanup.sh (ADR 0030): temp repos with
# linked worktrees and a fake `gh` on the PATH (the PR lookup is a file per branch, no network).
set -uo pipefail
HUB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$HUB/config/hooks/worktree-cleanup.sh"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
pass=0; failn=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"; else failn=$((failn + 1)); echo "FAIL $1"; fi; }

# fake gh: `gh pr list --repo R --head B ...` prints $FAKE_PRS/<B with / as _>.json, or [] when there is none
mkdir -p "$W/bin" "$W/prs"
cat >"$W/bin/gh" <<'GH'
#!/usr/bin/env bash
head=""; while [ $# -gt 0 ]; do [ "$1" = "--head" ] && head="$2"; shift; done
f="$FAKE_PRS/${head//\//_}.json"
[ -f "$f" ] && cat "$f" || echo '[]'
GH
chmod +x "$W/bin/gh"
export FAKE_PRS="$W/prs"
export PATH="$W/bin:$PATH"

# mkrepo <dir> -> repo with one commit on main and a github origin (never fetched; origin/main faked at init)
mkrepo() { mkdir -p "$1" && git -C "$1" init -q -b main && git -C "$1" commit -q --allow-empty -m init \
  && git -C "$1" remote add origin https://github.com/acme/"$(basename "$1")".git && push_main "$1"; }
# push_main <repo> -> origin/main points at the local main (a push, without a remote)
push_main() { git -C "$1" update-ref refs/remotes/origin/main "$(git -C "$1" rev-parse main)"; }
# mergein <repo> <branch> -> --no-ff merge of the branch into main (main is checked out in the main worktree)
mergein() { git -C "$1" merge -q --no-ff "$2" -m "Merge $2"; }
# mkwt <repo> <branch> -> worktree <repo>-<branch> with one extra commit
mkwt() { git -C "$1" worktree add -q -b "$2" "$1-$2" && git -C "$1-$2" commit -q --allow-empty -m "work $2"; }
# merged <branch> <oid> <number> -> the fake PR lookup answers a merged PR
merged() { printf '[{"number":%s,"headRefOid":"%s"}]\n' "$3" "$2" >"$W/prs/${1//\//_}.json"; }
head_of() { git -C "$1" rev-parse HEAD; }
has_branch() { git -C "$1" show-ref --verify --quiet "refs/heads/$2"; }
# run <cwd> [args] -> hook run as the SessionStart hook with that cwd
run() { jq -n --arg c "$1" '{hook_event_name:"SessionStart",cwd:$c}' | bash "$HOOK"; }

# --- scope: a repo, from its main worktree
R="$W/r1/repo-a"; mkrepo "$R"
mkwt "$R" feat-ok; merged feat-ok "$(head_of "$R-feat-ok")" 11
mkwt "$R" feat-dirty; merged feat-dirty "$(head_of "$R-feat-dirty")" 12; echo x >"$R-feat-dirty/new.txt"
mkwt "$R" feat-ahead; merged feat-ahead "$(head_of "$R-feat-ahead")" 13; git -C "$R-feat-ahead" commit -q --allow-empty -m later
mkwt "$R" feat-open
mkwt "$R" feat-here; merged feat-here "$(head_of "$R-feat-here")" 14
out="$(run "$R-feat-here/")"
check "deletes the merged worktree whose head matches" '[ ! -d "$R-feat-ok" ] && ! has_branch "$R" feat-ok'
check "reports it as SessionStart additionalContext" 'jq -e ".hookSpecificOutput.hookEventName == \"SessionStart\" and (.hookSpecificOutput.additionalContext | test(\"borré .*repo-a-feat-ok \\\\(rama feat-ok, PR #11 mergeado\\\\)\"))" <<<"$out" >/dev/null'
check "does not touch a worktree with uncommitted changes" '[ -d "$R-feat-dirty" ] && has_branch "$R" feat-dirty'
check "does not touch a worktree whose head differs from the PR head" '[ -d "$R-feat-ahead" ] && has_branch "$R" feat-ahead'
check "does not touch a worktree without a merged PR" '[ -d "$R-feat-open" ] && has_branch "$R" feat-open'
check "does not touch the worktree that holds the cwd" '[ -d "$R-feat-here" ] && has_branch "$R" feat-here'
check "does not touch the main worktree" '[ -d "$R/.git" ] && has_branch "$R" main'
check "reports only what it deleted" '[ "$(jq -r ".hookSpecificOutput.additionalContext" <<<"$out" | wc -l)" = 1 ]'
check "nothing to delete prints nothing" '[ -z "$(run "$R-feat-here")" ]'

# --- dry run and manual mode
mkwt "$R" feat-dry; merged feat-dry "$(head_of "$R-feat-dry")" 21
out="$(bash "$HOOK" --cwd "$R" --dry-run)"
check "--dry-run lists but does not delete" '[ -d "$R-feat-dry" ] && has_branch "$R" feat-dry && grep -q "borraría .*feat-dry.*PR #21" <<<"$out"'
out="$(bash "$HOOK" --cwd "$R")"
check "--cwd deletes and prints plain text" '[ ! -d "$R-feat-dry" ] && ! has_branch "$R" feat-dry && grep -q "^worktree-cleanup: borré .*feat-dry" <<<"$out" && ! grep -q hookSpecificOutput <<<"$out"'
check "--cwd with nothing to do says so" 'grep -q "nada que borrar" <<<"$(bash "$HOOK" --cwd "$R")"'

# --- a merged worktree with something running inside is kept (ADR 0065): the hook never kills processes
mkwt "$R" feat-busy; merged feat-busy "$(head_of "$R-feat-busy")" 25
(cd "$R-feat-busy" && exec sleep 30) & busy=$!
sleep 0.3
out="$(bash "$HOOK" --cwd "$R")"
check "keeps a merged worktree with a live process and says why" '[ -d "$R-feat-busy" ] && kill -0 $busy 2>/dev/null && grep -q "no borré .*feat-busy.*procesos" <<<"$out"'
kill $busy 2>/dev/null; wait $busy 2>/dev/null
bash "$HOOK" --cwd "$R" >/dev/null
check "deletes it once nothing runs there" '[ ! -d "$R-feat-busy" ]'

# --- cwd inside a linked worktree: its siblings are cleaned, itself is not
mkwt "$R" feat-sib; merged feat-sib "$(head_of "$R-feat-sib")" 31
run "$R-feat-open/" >/dev/null
check "from inside a worktree, siblings are cleaned" '[ ! -d "$R-feat-sib" ]'

# --- cwd without stdin cwd falls back to $PWD
mkwt "$R" feat-pwd; merged feat-pwd "$(head_of "$R-feat-pwd")" 41
(cd "$R" && echo '{}' | bash "$HOOK" >/dev/null)
check "no cwd in the JSON uses \$PWD" '[ ! -d "$R-feat-pwd" ]'

# --- a folder that groups repos
F="$W/ws"; mkdir -p "$F"; mkrepo "$F/repo-b"; mkrepo "$F/repo-c"
mkwt "$F/repo-b" t1; merged t1 "$(head_of "$F/repo-b-t1")" 51
mkwt "$F/repo-c" t2; merged t2 "$(head_of "$F/repo-c-t2")" 52
mkwt "$F/repo-c" t3
out="$(run "$F")"
check "folder mode cleans the worktrees of every repo inside" '[ ! -d "$F/repo-b-t1" ] && [ ! -d "$F/repo-c-t2" ] && ! has_branch "$F/repo-b" t1 && ! has_branch "$F/repo-c" t2'
check "folder mode keeps the unmerged one and the main repos" '[ -d "$F/repo-c-t3" ] && [ -d "$F/repo-b/.git" ] && [ -d "$F/repo-c/.git" ]'
check "folder mode reports both" '[ "$(jq -r ".hookSpecificOutput.additionalContext" <<<"$out" | wc -l)" = 2 ]'

# --- local --no-ff merge, no PR (personal repos): the tip is in origin/<default> but off its first-parent chain
L="$W/r2/repo-l"; mkrepo "$L"; git -C "$L" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
git -C "$L" worktree add -q -b feat-fresh "$L-feat-fresh"            # created, no commits of its own
mkwt "$L" feat-local; mkwt "$L" feat-ldirty; mkwt "$L" feat-lhere
mergein "$L" feat-local; mergein "$L" feat-ldirty; mergein "$L" feat-lhere; echo x >"$L-feat-ldirty/new.txt"
git -C "$L" worktree add -q -b feat-stale "$L-feat-stale"            # created at the base tip...
git -C "$L" commit -q --allow-empty -m advance; push_main "$L"         # ...and the base moved on
mkwt "$L" feat-unpushed; mergein "$L" feat-unpushed                   # merged into local main only
out="$(run "$L-feat-lhere")"
check "local: deletes the worktree merged into origin/main with --no-ff" '[ ! -d "$L-feat-local" ] && ! has_branch "$L" feat-local'
check "local: reports it with the base, no PR number" 'jq -r ".hookSpecificOutput.additionalContext" <<<"$out" | grep -qx "worktree-cleanup: borré .*repo-l-feat-local (rama feat-local, mergeada en origin/main)"'
check "local: keeps a fresh worktree with no commits" '[ -d "$L-feat-fresh" ] && has_branch "$L" feat-fresh'
check "local: keeps a fresh worktree after the base moved on" '[ -d "$L-feat-stale" ] && has_branch "$L" feat-stale'
check "local: keeps a merged worktree with uncommitted changes" '[ -d "$L-feat-ldirty" ] && has_branch "$L" feat-ldirty'
check "local: keeps the merged worktree that holds the cwd" '[ -d "$L-feat-lhere" ] && has_branch "$L" feat-lhere'
check "local: keeps a worktree merged only into the local base" '[ -d "$L-feat-unpushed" ] && has_branch "$L" feat-unpushed'
check "local: reports only what it deleted" '[ "$(jq -r ".hookSpecificOutput.additionalContext" <<<"$out" | wc -l)" = 1 ]'
git -C "$L" update-ref -d refs/remotes/origin/HEAD; push_main "$L"
run "$L" >/dev/null
check "local: without origin/HEAD it falls back to origin/main" '[ ! -d "$L-feat-unpushed" ]'

# --- no gh: silent, exit 0 (PATH with only the tools the hook needs)
mkdir -p "$W/nogh"; for c in bash git jq sed grep head cat timeout dirname basename; do ln -sf "$(command -v "$c")" "$W/nogh/$c"; done
mkwt "$R" feat-nogh; merged feat-nogh "$(head_of "$R-feat-nogh")" 61
out="$(jq -n --arg c "$R" '{cwd:$c}' | PATH="$W/nogh" bash "$HOOK"; echo "rc=$?")"
check "without gh it exits 0 with no output and deletes nothing" '[ "$out" = "rc=0" ] && [ -d "$R-feat-nogh" ]'
mkwt "$L" feat-lnogh; mergein "$L" feat-lnogh; push_main "$L"
out="$(jq -n --arg c "$L" '{cwd:$c}' | PATH="$W/nogh" bash "$HOOK" | jq -r .hookSpecificOutput.additionalContext)"
check "without gh a local --no-ff merge is still cleaned" '[ ! -d "$L-feat-lnogh" ] && grep -q "feat-lnogh.*mergeada en origin/main" <<<"$out"'

# --- gh failing (no network): silent, nothing deleted
cat >"$W/bin/gh" <<'GH'
#!/usr/bin/env bash
exit 1
GH
out="$(run "$R"; echo "rc=$?")"
check "a failing gh exits 0 with no output and deletes nothing" '[ "$out" = "rc=0" ] && [ -d "$R-feat-nogh" ]'

# --- not a git repo and not a workspace: silent
mkdir -p "$W/empty"
check "outside any repo it is silent" '[ "$(run "$W/empty"; echo "rc=$?")" = "rc=0" ]'
check "bash -n passes" 'bash -n "$HOOK"'
check "settings.base.json wires the hook in SessionStart" 'jq -e ".hooks.SessionStart[].hooks[].command | select(test(\"worktree-cleanup.sh\"))" "$HUB/config/settings.base.json" >/dev/null'

echo "$pass passed, $failn failed"
[ "$failn" -eq 0 ]
