#!/usr/bin/env bash
# test-worker-commit.sh - offline checks for config/hooks/worker-commit.sh (ADR 0062): temp repo with worktrees
# and a fake orca. Covers: the hook rewrites only the `git commit` of a supervised worker's command in its own
# worktree (compound with cd and a quoted message that contains `; git commit`, heredoc message, git -C, a stack-sync
# busy mark) and leaves the rest as it was (a `git push` after it stays); it stays silent for --amend, --no-verify,
# -n, a base branch, the main checkout, another terminal, another worktree, no Orca, two commits and two cd; the
# rewritten command really commits with the same message; and the wrapper alone refuses the same cases.
set -uo pipefail
HUB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$HUB/config/hooks/worker-commit.sh"
W="$(mktemp -d)"; [ -n "${KEEP:-}" ] || trap 'rm -rf "$W"' EXIT
pass=0; failn=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"; else failn=$((failn + 1)); echo "FAIL $1"; fi; }
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export XDG_STATE_HOME="$W/state" STACK_SYNC_STATE="$W/stack-sync"

R="$W/repo" WT="$W/wt" DEV="$W/wt-dev"
git init -q -b master "$R" && git -C "$R" commit -q --allow-empty -m init
git -C "$R" branch dev
git -C "$R" worktree add -q -b feat/x "$WT"
git -C "$R" worktree add -q "$DEV" dev
git -C "$R" switch -q -c feat/main # the main checkout on a non-base branch: refused for being the main checkout

# fake orca: worker-list answers with one active worker, terminal term_w on $WT
mkdir -p "$W/bin"
cat >"$W/bin/orca" <<EOF
#!/usr/bin/env bash
[ "\$1 \$2" = "orchestration worker-list" ] || exit 1
printf '{"ok":true,"result":{"workers":[{"terminal":"term_w","workspace":"id::%s"},{"terminal":"term_o","workspace":"id::%s"}]}}\n' "$WT" "$R"
EOF
chmod +x "$W/bin/orca"
export WORKER_COMMIT_ORCA="$W/bin/orca" ORCA_TERMINAL_HANDLE=term_w

# hook <cwd> <command>: prints the rewritten command, or nothing
hook() { jq -n --arg c "$2" --arg d "$1" '{tool_name:"Bash",cwd:$d,tool_input:{command:$c,description:"x"}}' |
  bash "$HOOK" | jq -r '.hookSpecificOutput.updatedInput.command // empty'; }
q="'$HOOK'"

out="$(hook "$W" "cd $WT && git add -A && git commit -q -m \"fix: a; git commit b\"")"
check "compuesto con cd: reescribe solo el commit" "[ \"\$out\" = \"cd $WT && git add -A && bash $q commit -q -m \\\"fix: a; git commit b\\\"\" ]"
echo a >"$WT/a"
(cd "$W" && eval "$out") >/dev/null 2>&1
check "el comando reescrito commitea con el mismo mensaje" "[ \"\$(git -C $WT log -1 --format=%s)\" = 'fix: a; git commit b' ]"

msg=$'git commit -m "$(cat <<\'EOF\'\nfeat: heredoc\n\ncuerpo\nEOF\n)"'
out="$(hook "$WT" "$msg")"
check "heredoc: reescribe" "[[ \$out == \"bash $q commit -m \"* ]]"
echo b >"$WT/b"; git -C "$WT" add b
(cd "$WT" && eval "$out") >/dev/null 2>&1
check "heredoc: el cuerpo llega entero" "[ \"\$(git -C $WT log -1 --format=%B)\" = \$'feat: heredoc\n\ncuerpo' ]"

check "git -C <worktree> commit: reescribe" "[ \"\$(hook $W 'git -C $WT commit -m x')\" = \"bash $q -C $WT commit -m x\" ]"
check "un push después sigue igual" "[ \"\$(hook $WT 'git commit -m x && git push')\" = \"bash $q commit -m x && git push\" ]"

for c in 'git commit --amend -m x' 'git commit --no-verify -m x' 'git commit -n -m x' 'git commit -nm x' \
  'git commit -m x && git commit -m y' "cd $WT && cd $WT && git commit -m x" 'git push' 'echo "git commit -m x"'; do
  check "silencio: $c" "[ -z \"\$(hook $WT '$c')\" ]"
done
check "silencio: rama base (dev)" "[ -z \"\$(hook $DEV 'git commit -m x')\" ]"
check "silencio: checkout principal" "[ -z \"\$(ORCA_TERMINAL_HANDLE=term_o hook $R 'git commit -m x')\" ]"
check "silencio: otra terminal" "[ -z \"\$(ORCA_TERMINAL_HANDLE=term_x hook $WT 'git commit -m x')\" ]"
check "silencio: worker de otro worktree" "[ -z \"\$(ORCA_TERMINAL_HANDLE=term_o hook $WT 'git commit -m x')\" ]"
check "silencio: sin Orca" "[ -z \"\$(ORCA_TERMINAL_HANDLE= hook $WT 'git commit -m x')\" ]"

mkdir -p "$STACK_SYNC_STATE/busy"; printf '%s\tfeat/x\n' "$WT" >"$STACK_SYNC_STATE/busy/pr-1"
check "marca viva de stack-sync: reescribe" "[ -n \"\$(ORCA_TERMINAL_HANDLE= hook $WT 'git commit -m x')\" ]"
rm -f "$STACK_SYNC_STATE/busy/pr-1"

# the wrapper alone
wrap() { (cd "$1" && shift && bash "$HOOK" "$@") >/dev/null 2>&1; }
echo c >"$WT/c"; git -C "$WT" add c
check "wrapper: --amend se niega" "! wrap $WT commit --amend -m x"
check "wrapper: --no-verify se niega" "! wrap $WT commit --no-verify -m x"
check "wrapper: --no-edit fuera de un merge se niega" "! wrap $WT commit --no-edit"
check "wrapper: otra terminal se niega" "! ORCA_TERMINAL_HANDLE=term_x wrap $WT commit -m x"
check "wrapper: rama base se niega" "! wrap $DEV commit --allow-empty -m x"
check "wrapper: commit válido" "wrap $WT commit -q -m 'feat: c' && [ \"\$(git -C $WT log -1 --format=%s)\" = 'feat: c' ]"
check "wrapper: deja registro" "grep -q 'term_w' $XDG_STATE_HOME/agents-config/worker-commit.log"

echo "$pass ok, $failn fail"
[ "$failn" -eq 0 ]
