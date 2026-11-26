#!/usr/bin/env bash
# test-worker-commit.sh - offline checks for config/hooks/worker-commit.sh (ADR 0062): temp repo with worktrees,
# a fake orca and an isolated HOME. Covers: the hook rewrites only the `git` of the one `git commit` of a supervised
# worker in its own worktree, and the rewritten command really commits (the 25/11 shapes: cd + merge-base + status +
# add + commit, add + commit with two -m + log | tail; a heredoc message; -F - with a heredoc; git -C; --no-edit in a
# merge; a stack-sync busy mark); it stays silent outside its grammar (export, assignment, env, git -c, $(...),
# <(...), backtick, backslash, line continuation, a heredoc before the commit, a heredoc message that hides a
# command after its first delimiter line or uses <<-, an unquoted #, a background &, two commits, two cd),
# for bad flags, a base branch (also by origin/HEAD), a detached HEAD, the main checkout, another worktree, another
# terminal, no Orca, a stale busy mark, the scout and reviewer subagents, a deny rule on git commit and a hooksPath
# of /dev/null; a commit with a push goes whole to the dialog; long commands stay fast; and the wrapper refuses to run
# without the hook's one-time token, with a used token, with a bad flag or on a base branch.
# WORKER_COMMIT_E2E=1 also runs `claude -p` (network, a few cents): without the hook a project `ask` on
# `git commit *` stops the commit even in bypass; with it the commit passes and a `git push` still asks.
set -uo pipefail
HUB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$HUB/config/hooks/worker-commit.sh"
W="$(mktemp -d)"; [ -n "${KEEP:-}" ] || trap 'rm -rf "$W"' EXIT
pass=0; failn=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"; else failn=$((failn + 1)); echo "FAIL $1"; fi; }
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
REAL_HOME=$HOME
export HOME="$W/home" XDG_STATE_HOME="$W/state" STACK_SYNC_STATE="$W/stack-sync"
mkdir -p "$HOME" "$STACK_SYNC_STATE/busy"
unset CLAUDE_PROJECT_DIR

R="$W/repo" WT="$W/wt" WT2="$W/wt2" DEV="$W/wt-dev" DET="$W/wt-det" HEADB="$W/wt-head"
git init -q -b master "$R" && git -C "$R" commit -q --allow-empty -m init
git -C "$R" branch dev
git -C "$R" worktree add -q -b feat/x "$WT"
git -C "$R" worktree add -q -b feat/y "$WT2"
git -C "$R" worktree add -q "$DEV" dev
git -C "$R" worktree add -q --detach "$DET"
git -C "$R" worktree add -q -b trunk "$HEADB"
git -C "$R" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/trunk # the repo's default: a base too
git -C "$R" switch -q -c feat/main # the main checkout on a non-base branch: refused for being the main checkout

# fake orca: worker-list in two pages; term_w (retained, as after a follow-up dispatch) works on $WT and is on the
# second page; term_o works on the main checkout, term_d on the detached worktree and term_h on the default branch
mkdir -p "$W/bin"
cat >"$W/bin/orca" <<EOF
#!/usr/bin/env bash
[ "\$1 \$2" = "orchestration worker-list" ] || exit 1
case " \$* " in
  *" --cursor c2 "*) printf '{"ok":true,"result":{"workers":[{"terminal":"term_w","terminalState":"retained","workspace":"id::%s"}],"nextCursor":null}}\n' "$WT" ;;
  *) printf '{"ok":true,"result":{"workers":[{"terminal":"term_o","workspace":"id::%s"},{"terminal":"term_d","workspace":"id::%s"},{"terminal":"term_h","workspace":"id::%s"}],"nextCursor":"c2"}}\n' "$R" "$DET" "$HEADB" ;;
esac
EOF
chmod +x "$W/bin/orca"
export WORKER_COMMIT_ORCA="$W/bin/orca" ORCA_TERMINAL_HANDLE=term_w

# hook <cwd> <command> [agent_type]: prints the rewritten command, or nothing
hook() { jq -n --arg c "$2" --arg d "$1" --arg t "${3:-}" \
  '{tool_name:"Bash",cwd:$d,tool_input:{command:$c,description:"x"}} + (if $t == "" then {} else {agent_type:$t} end)' |
  bash "$HOOK" | jq -r '.hookSpecificOutput.updatedInput.command // empty'; }
# shape <rewritten>: the rewritten command with the token replaced by TOKEN
shape() { sed -E 's/--token [0-9a-f]{32}/--token TOKEN/' <<<"$1"; }
run() { (cd "$1" && eval "$2") >/dev/null 2>&1; }
w="bash $HOOK --token TOKEN"

# --- rewrites, and the rewritten command commits
c="cd $WT; git merge-base --is-ancestor master HEAD && echo base-ok; git status --short; git add docs && git commit -q -m \"fix: a; git commit b\""
out="$(hook "$W" "$c")"
check "25/11: cd + merge-base + status + add + commit" "[ \"\$(shape \"\$out\")\" = \"\${c/git commit -q/$w commit -q}\" ]"
mkdir -p "$WT/docs"; echo a >"$WT/docs/a"
run "$W" "$out"
check "25/11: commitea con el mismo mensaje" "[ \"\$(git -C $WT log -1 --format=%s)\" = 'fix: a; git commit b' ]"
check "25/11: el token se usa una vez" "! run $W \"\$out\""

echo b >"$WT/b"; echo c >"$WT/c"
out="$(hook "$WT" 'git add b c && git commit -q -m "feat: x" -m "cuerpo" && git log --oneline -2 | tail -1')"
check "25/11: add + commit con dos -m + log | tail" "[[ \$(shape \"\$out\") == \"git add b c && $w commit -q -m \"* ]]"
run "$WT" "$out"
check "25/11: el cuerpo del segundo -m llega" "[ \"\$(git -C $WT log -1 --format=%B)\" = \$'feat: x\n\ncuerpo' ]"

msg=$'git commit -m "$(cat <<\'EOF\'\nfeat: heredoc $HOME `x`\n\ncuerpo\nEOF\n)"'
out="$(hook "$WT" "$msg")"
check "heredoc literal en -m: reescribe" "[[ \$(shape \"\$out\") == \"$w commit -m \"* ]]"
echo d >"$WT/d"; git -C "$WT" add d; run "$WT" "$out"
check "heredoc literal en -m: el texto llega sin expandir" "[ \"\$(git -C $WT log -1 --format=%B)\" = \$'feat: heredoc \$HOME \`x\`\n\ncuerpo' ]"

msg=$'git commit -q -F - <<\'EOF\'\nfeat: por stdin\nEOF'
out="$(hook "$WT" "$msg")"
echo e >"$WT/e"; git -C "$WT" add e; run "$WT" "$out"
check "-F - con heredoc: commitea" "[ \"\$(git -C $WT log -1 --format=%s)\" = 'feat: por stdin' ]"

check "git -C <su worktree> commit: reescribe" "[ \"\$(shape \"\$(hook $W 'git -C $WT commit -m x')\")\" = \"$w -C $WT commit -m x\" ]"
check "commit + push: silencio, el diálogo decide el comando entero" "[ -z \"\$(hook $WT 'git commit -m x && git push')\" ]"
check "2>&1 y >/dev/null se aceptan" "[ -n \"\$(hook $WT 'git commit -q -m x 2>&1 >/dev/null')\" ]"

git -C "$WT2" commit -q --allow-empty -m y-only
git -C "$WT" merge -q --no-ff --no-commit feat/y 2>/dev/null
out="$(hook "$WT" 'git commit --no-edit')"
check "--no-edit durante un merge: reescribe" "[ -n \"\$out\" ]"
run "$WT" "$out"
check "--no-edit durante un merge: queda el merge commiteado" "[ \"\$(git -C $WT rev-list --parents -n1 HEAD | wc -w)\" = 3 ]"
check "--no-edit fuera de un merge: silencio" "[ -z \"\$(hook $WT 'git commit --no-edit')\" ]"

printf '%s\tfeat/x\n' "$WT" >"$STACK_SYNC_STATE/busy/pr-1"
check "marca viva de stack-sync: reescribe sin Orca" "[ -n \"\$(ORCA_TERMINAL_HANDLE= hook $WT 'git commit -m x')\" ]"
touch -d '2 hours ago' "$STACK_SYNC_STATE/busy/pr-1"
check "marca vencida de stack-sync: silencio" "[ -z \"\$(ORCA_TERMINAL_HANDLE= hook $WT 'git commit -m x')\" ]"
rm -f "$STACK_SYNC_STATE/busy/pr-1"

UTF="$W/wt-año"; git -C "$R" worktree add -q -b feat/ñ "$UTF"; printf '%s\tfeat/ñ\n' "$UTF" >"$STACK_SYNC_STATE/busy/pr-2"
out="$(ORCA_TERMINAL_HANDLE= hook "$W" "cd $UTF && git commit --allow-empty -q -m 'acción'")"
check "ruta con tildes: reescribe en el lugar justo" "[ \"\$(shape \"\$out\")\" = \"cd $UTF && $w commit --allow-empty -q -m 'acción'\" ]"
run "$W" "$out"
check "ruta con tildes: commitea" "[ \"\$(git -C $UTF log -1 --format=%s)\" = acción ]"
rm -f "$STACK_SYNC_STATE/busy/pr-2"

# --- silent: outside the grammar
for c in 'export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=/dev/null; git commit -m x' \
  'export HUSKY=0; git commit -m x' 'HUSKY=0 git commit -m x' 'env HUSKY=0 git commit -m x' \
  'git -c core.hooksPath=/dev/null commit -m x' 'git commit -m "$(git push origin HEAD)"' 'git commit -F <(echo hi)' \
  'git commit -m `git push`' "git commit -m it\\'s" $'git commit -m x \\\n--no-verify' \
  $'cat > x.sh <<\'EOF\'\ngit commit -q -m init\nEOF' 'git commit -m x &' 'git commit -m x > log.txt' \
  'git commit -m x && git commit -m y' "cd $WT && cd $WT && git commit -m x" 'rm -rf x; git commit -m x' \
  'diff <(git show HEAD:b) b; git add b && git commit -q -m x' 'git push' 'echo "git commit -m x"' \
  $'git commit -m "$(cat <<\'EOF\'\nmsg\nEOF\ngit push origin HEAD\ncat <<\'EOF\'\nx\nEOF\n)"' \
  $'git commit -m "$(cat <<\'EOF\'\nEOF\ngit push\ncat <<\'EOF\'\nEOF\n)"' \
  $'git commit -m "$(cat <<-\'EOF\'\nmsg\n\tEOF\n)"' \
  $'echo #\'\nexport SKIP=x\n#\'\ngit commit -m x'; do
  check "silencio: ${c//$'\n'/⏎}" "[ -z \"\$(hook $WT \"\$c\")\" ]"
done

# --- silent: bad flags, wrong target, wrong session
for c in 'git commit --amend -m x' 'git commit --no-verify -m x' 'git commit -n -m x' 'git commit -nm x' 'git commit --fixup HEAD'; do
  check "silencio: $c" "[ -z \"\$(hook $WT '$c')\" ]"
done
check "silencio: rama base (dev)" "[ -z \"\$(hook $DEV 'git commit -m x')\" ]"
check "silencio: rama base por origin/HEAD" "[ -z \"\$(ORCA_TERMINAL_HANDLE=term_h hook $HEADB 'git commit -m x')\" ]"
check "silencio: HEAD detached" "[ -z \"\$(ORCA_TERMINAL_HANDLE=term_d hook $DET 'git commit -m x')\" ]"
check "silencio: checkout principal" "[ -z \"\$(ORCA_TERMINAL_HANDLE=term_o hook $R 'git commit -m x')\" ]"
check "silencio: git -C hacia otro worktree" "[ -z \"\$(hook $WT 'git -C $WT2 commit -m x')\" ]"
check "silencio: otra terminal" "[ -z \"\$(ORCA_TERMINAL_HANDLE=term_x hook $WT 'git commit -m x')\" ]"
check "silencio: sin Orca" "[ -z \"\$(ORCA_TERMINAL_HANDLE= hook $WT 'git commit -m x')\" ]"
check "silencio: subagente reviewer" "[ -z \"\$(hook $WT 'git commit -m x' reviewer)\" ]"
check "silencio: subagente scout" "[ -z \"\$(hook $WT 'git commit -m x' scout)\" ]"
mkdir -p "$WT/.claude"; echo '{"permissions":{"deny":["Bash(git commit:*)"]}}' >"$WT/.claude/settings.local.json"
check "silencio: deny de git commit en el proyecto" "[ -z \"\$(hook $WT 'git commit -m x')\" ]"
echo '{"permissions":{"deny":["Bash(git push --force *)"]}}' >"$WT/.claude/settings.local.json"
check "un deny de otra cosa no lo frena" "[ -n \"\$(hook $WT 'git commit -m x')\" ]"
rm -rf "$WT/.claude"
git -C "$WT" config core.hooksPath /dev/null
check "silencio: core.hooksPath en /dev/null" "[ -z \"\$(hook $WT 'git commit -m x')\" ]"
git -C "$WT" config --unset core.hooksPath

# --- speed: long commands, worker or not
big="git commit -m \"$(head -c 60000 /dev/zero | tr '\0' a)\""
t0=$(date +%s%N); ORCA_TERMINAL_HANDLE= hook "$WT" "$big" >/dev/null; t1=$(date +%s%N); hook "$WT" "$big" >/dev/null; t2=$(date +%s%N)
check "60 KB sin ser worker: menos de 1 s" "[ \$(((t1 - t0) / 1000000)) -lt 1000 ]"
check "60 KB siendo worker: menos de 2 s" "[ \$(((t2 - t1) / 1000000)) -lt 2000 ]"

# --- the wrapper alone
wrap() { (cd "$1" && shift && bash "$HOOK" "$@") >/dev/null 2>&1; }
echo f >"$WT/f"; git -C "$WT" add f
check "wrapper sin token se niega" "! wrap $WT commit -m x"
check "wrapper con un token inventado se niega" "! wrap $WT --token 0123456789abcdef0123456789abcdef commit -m x"
out="$(hook "$WT" 'git commit --amend -m x')"
check "wrapper: --amend no llega ni a tener token" "[ -z \"\$out\" ]"
tok="$(sed -nE 's/.*--token ([0-9a-f]{32}).*/\1/p' <<<"$(hook "$WT" 'git commit -m x')")"
check "wrapper: un token válido con --amend se niega" "! wrap $WT --token $tok commit --amend -m x"
tok="$(sed -nE 's/.*--token ([0-9a-f]{32}).*/\1/p' <<<"$(hook "$WT" 'git commit -m x')")"
check "wrapper: el token de un worktree no sirve en otro" "! wrap $WT2 --token $tok commit --allow-empty -m x"
check "wrapper: deja registro" "grep -q 'term_w' $XDG_STATE_HOME/agents-config/worker-commit.log"

# --- optional: the real thing, with claude -p (WORKER_COMMIT_E2E=1)
if [ "${WORKER_COMMIT_E2E:-0}" = 1 ] && command -v claude >/dev/null; then
  E="$W/e2e"; git init -q --bare "$E/origin.git"; git init -q -b master "$E/repo"
  git -C "$E/repo" commit -q --allow-empty -m init && git -C "$E/repo" remote add origin "$E/origin.git"
  mkdir -p "$E/repo/.claude"; echo '{"permissions":{"ask":["Bash(git commit *)","Bash(git push *)"]}}' >"$E/repo/.claude/settings.json"
  git -C "$E/repo" add .claude && git -C "$E/repo" commit -q -m settings && git -C "$E/repo" worktree add -q -b feat/e "$E/wt"
  printf '#!/usr/bin/env bash\nprintf %s\n' "'{\"ok\":true,\"result\":{\"workers\":[{\"terminal\":\"term_e\",\"workspace\":\"id::$E/wt\"}]}}'" >"$W/bin/orca-e2e"
  chmod +x "$W/bin/orca-e2e"
  set_hook="{\"hooks\":{\"PreToolUse\":[{\"matcher\":\"Bash\",\"hooks\":[{\"type\":\"command\",\"command\":\"bash $HOOK\"}]}]}}"
  ask() { # <settings or empty> <command>
    (cd "$E/wt" && HOME=$REAL_HOME WORKER_COMMIT_ORCA="$W/bin/orca-e2e" ORCA_TERMINAL_HANDLE=term_e timeout 240 claude -p \
      "Run exactly this Bash command once, verbatim, nothing else: $2 -- Then reply only with its output or the denial text." \
      --model haiku --dangerously-skip-permissions --setting-sources project,local ${1:+--settings "$1"} \
      --output-format text </dev/null >/dev/null 2>&1); }
  n0=$(git -C "$E/wt" rev-list --count HEAD)
  ask "" "git commit --allow-empty -q -m sin-hook"
  check "e2e: sin el hook, el ask de git commit lo frena" "[ \$(git -C $E/wt rev-list --count HEAD) = $n0 ]"
  ask "$set_hook" "cd $E/wt && git commit --allow-empty -q -m con-hook"
  check "e2e: con el hook, commitea sin diálogo" "[ \"\$(git -C $E/wt log -1 --format=%s)\" = con-hook ]"
  ask "$set_hook" "git commit --allow-empty -q -m con-push && git push origin feat/e"
  check "e2e: con un push, sigue preguntando (ni commit ni push)" "[ \"\$(git -C $E/wt log -1 --format=%s)\" = con-hook ] && ! git -C $E/origin.git rev-parse -q --verify feat/e >/dev/null"
fi

echo "$pass ok, $failn fail"
[ "$failn" -eq 0 ]
