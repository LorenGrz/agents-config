#!/usr/bin/env bash
# test-worker-commit.sh - offline checks for config/hooks/worker-commit.sh (ADR 0062): temp repo with worktrees,
# a fake orca and an isolated HOME. Covers: the hook rewrites only a lone `git commit` of a supervised worker in its
# own worktree, with the allowed arguments (-m/--message quoted, -q, -a, -F <file>, --no-edit in a merge), and the
# rewritten command really commits; the 17 real worker commands with a commit of 25/11 (anonymized, same shape)
# and every compound or multi-line command with a commit (the reviewers' repros: a push hidden in a heredoc or in
# quotes, an EOF) are denied in a worker with the reason «send git add and git commit apart» and go to the dialog
# outside one; the commit each real form carries, sent alone, is rewritten; a single command outside the list goes
# to the dialog; so do bad flags, a base
# branch (also by origin/HEAD), a detached HEAD, the main checkout, another terminal, no Orca, a stale busy mark,
# the scout and reviewer subagents, a deny rule that matches git commit and a hooksPath of /dev/null; and the
# wrapper refuses to run without the hook's one-time token, with a used token, with a bad argument or elsewhere.
# WORKER_COMMIT_E2E=1 also runs `claude -p` (network, a few cents): without the hook a project `ask` on
# `git commit *` stops the commit even in bypass; with it a lone commit passes, a commit with a push is denied with the
# reason (and the reason is absent without the hook), and a compound commit ends committed after the retry.
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
# the project asks for git commit, as the work repos do; every worktree below inherits it
mkdir -p "$R/.claude" && echo '{"permissions":{"ask":["Bash(git commit *)"]}}' >"$R/.claude/settings.json"
git -C "$R" add .claude && git -C "$R" commit -q -m settings
# a repo with no ask at all: the hook leaves it alone
N="$W/plain" NW="$W/plain-wt"
git init -q -b master "$N" && git -C "$N" commit -q --allow-empty -m init && git -C "$N" worktree add -q -b feat/n "$NW"
git -C "$R" branch dev
git -C "$R" worktree add -q -b feat/x "$WT"
git -C "$R" worktree add -q -b feat/y "$WT2"
git -C "$R" worktree add -q "$DEV" dev
git -C "$R" worktree add -q --detach "$DET"
git -C "$R" worktree add -q -b trunk "$HEADB"
git -C "$R" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/trunk # the repo's default: a base too
git -C "$R" switch -q -c feat/main # the main checkout on a non-base branch: refused for being the main checkout

# fake orca: worker-list in two pages; term_w (retained, as after a follow-up dispatch) works on $WT and is on the
# second page; term_o works on the main checkout, term_d on the detached worktree, term_h on the default branch
mkdir -p "$W/bin"
cat >"$W/bin/orca" <<EOF
#!/usr/bin/env bash
[ "\$1 \$2" = "orchestration worker-list" ] || exit 1
case " \$* " in
  *" --cursor c2 "*) printf '{"ok":true,"result":{"workers":[{"terminal":"term_w","terminalState":"retained","workspace":"id::%s"}],"nextCursor":null}}\n' "$WT" ;;
  *) printf '{"ok":true,"result":{"workers":[{"terminal":"term_o","workspace":"id::%s"},{"terminal":"term_d","workspace":"id::%s"},{"terminal":"term_h","workspace":"id::%s"},{"terminal":"term_n","workspace":"id::%s"}],"nextCursor":"c2"}}\n' "$R" "$DET" "$HEADB" "$NW" ;;
esac
EOF
chmod +x "$W/bin/orca"
export WORKER_COMMIT_ORCA="$W/bin/orca" ORCA_TERMINAL_HANDLE=term_w

# hook <cwd> <command> [agent_type]: prints the rewritten command, or nothing
hook() { jq -n --arg c "$2" --arg d "$1" --arg t "${3:-}" \
  '{tool_name:"Bash",cwd:$d,tool_input:{command:$c,description:"x"}} + (if $t == "" then {} else {agent_type:$t} end)' |
  bash "$HOOK" | jq -r '.hookSpecificOutput.updatedInput.command // empty'; }
# what <cwd> <command>: rewrite, deny (only with the expected reason) or dialog (no output)
REASON='Mandá git add y git commit en comandos aparte, cada uno en una línea; el mensaje con -m en una línea (varios -m si hace falta). Sin redirecciones ni nada encadenado; si el mensaje trae $, ` o \, va entre comillas simples.'
what() { local o; o="$(jq -n --arg c "$2" --arg d "$1" '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}' | bash "$HOOK")"
  if [ -z "$o" ]; then echo dialog
  elif [ "$(jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$o")" = deny ]; then
    [ "$(jq -r '.hookSpecificOutput.permissionDecisionReason' <<<"$o")" = "$REASON" ] && echo deny || echo deny-otro-motivo
  elif [ -n "$(jq -r '.hookSpecificOutput.updatedInput.command // empty' <<<"$o")" ]; then echo rewrite
  else echo otro; fi; }
shape() { sed -E 's/--token [0-9a-f]{32}/--token TOKEN/' <<<"$1"; }
run() { (cd "$1" && eval "$2") >/dev/null 2>&1; }
w="bash $HOOK --token TOKEN"

# --- 25/11: the 17 real worker commands with a commit (anonymized, same shape): denied with the reason in a worker,
# the dialog outside one
M='"feat(x): aviso en vivo (T-1)"' M2='"Tests y docs al día."'
ML=$'"feat(x): disponibilidad por categoría (T-2)\n\nCard «Disponibilidad»: Marketing con «Disponible» y\nUtilidad con «Habilitada»."'
# the same message as one line per -m, the shape the brief asks for
T='"feat(x): disponibilidad por categoría (T-2)"' B1='"Card «Disponibilidad»: Marketing con «Disponible» y"' B2='"Utilidad con «Habilitada»."'
real=(
  "git add docs/a.md docs/b.md src/a.test.ts src/a.ts && git commit -q -m $M -m $M2 && git log --oneline -2"
  "git add docs/c.md src/a.test.ts src/a.ts && git commit -q -m $M -m $M2 && git log --oneline -3"
  "git merge-base --is-ancestor origin/dev HEAD && echo base-ok && git add src/a.ts src/b.ts && git commit -q -m $M && git add src/c.ts && git commit -q -m $M2"
  "cd $WT; git merge-base --is-ancestor origin/dev HEAD && echo base-ok; git status --short; git add docs/a.md && git commit -q -m $M && git log --oneline -1"
  "git status --short && git add CLAUDE.md src/a.ts src/b.test.ts && git commit -q -m $M && git log --oneline -1"
  "diff <(git diff --numstat HEAD) <(git diff --numstat --ignore-cr-at-eol HEAD) && echo eol-ok && git status --short && git add src/a.ts && git commit -q -m $M -m $M2 && git log --oneline -1"
  "cd $WT; git add -A && git commit -q -m $ML && git log --oneline -3"
  "git add docs/a.md src/a.tsx src/a.test.tsx && git commit -q -m $M && git log --oneline -1"
  "git add src/a.test.tsx && git commit -q -m $M && git log --oneline -2"
  "cd $WT; git diff --check && git add -A && git status --short && git commit -q -m $M && git log --oneline -4"
  "cd $WT; git diff --check && echo ws-ok; git add src prisma && git commit -q -m $M && git add -A docs && git commit -q -m $M2 && git status --short && git log --oneline -3; diff <(git diff --numstat origin/dev...HEAD) <(git diff --numstat --ignore-cr-at-eol origin/dev...HEAD) && echo EOL-OK"
  "cd $WT; git diff --check -- . ':!src/a.ts' ':!src/b.ts' | head -5; echo \"---\"; git diff --ignore-cr-at-eol --check | head -5; echo \"---\"; git add src prisma && git commit -q -m $M && git add -A docs && git commit -q -m $M2"
  "git commit -q -m $ML && git log --oneline -1"
  "git commit -q -m $ML && git log --oneline -4"
  "git reset -q && git add src/a.test.tsx src/b.test.ts && git commit -q -m $M && git add -A && git commit -q -m $M2 && git log --oneline -4"
  $'python3 - <<\'EOF\'\np = "src/a.test.tsx"\nprint(p)\nEOF\ngrep -n "x" src/a.test.tsx; git add src/a.test.tsx && git commit -q -m '"$M"' && git log --oneline -4'
  $'python3 - <<\'EOF\'\nimport pathlib\nEOF\ngit add -A && diff <(git diff --cached --numstat HEAD) <(git diff --cached --numstat --ignore-cr-at-eol HEAD) && echo eol-ok && git commit -q -m '"$M"' && git log --oneline -3'
)
for i in "${!real[@]}"; do
  c=${real[i]}
  check "25/11 forma $((i + 1)) en un worker: deny con el motivo" "[ \"\$(what $WT \"\$c\")\" = deny ]"
  check "25/11 forma $((i + 1)) fuera de un worker: diálogo" "[ \"\$(ORCA_TERMINAL_HANDLE= what $WT \"\$c\")\" = dialog ]"
done

# ... and the commit each one carries, sent alone, is rewritten
for c in "git commit -q -m $M -m $M2" "git commit -q -m $M" "git commit -q -m $T -m $B1 -m $B2"; do
  check "25/11 commit suelto: reescribe ${c:0:40}…" "[ \"\$(shape \"\$(hook $WT \"\$c\")\")\" = \"$w\${c:3}\" ]"
done
echo a >"$WT/a"; git -C "$WT" add a
check "commit suelto con mensaje multilínea en un -m: deny con el motivo" "[ \"\$(what $WT \"git commit -q -m \$ML\")\" = deny ]"
run "$WT" "$(hook "$WT" "git commit -q -m $T -m $B1 -m $B2")"
check "tres -m: commitea título y cuerpo" "[ \"\$(git -C $WT log -1 --format=%B)\" = \$'feat(x): disponibilidad por categoría (T-2)\\n\\nCard «Disponibilidad»: Marketing con «Disponible» y\\n\\nUtilidad con «Habilitada».' ]"
echo b >"$WT/b"; git -C "$WT" add b
out="$(hook "$WT" "git commit -q -m 'fix: comillas simples; nada más' -m $M2")"
run "$WT" "$out"
check "comillas simples y dos -m: commitea" "[ \"\$(git -C $WT log -1 --format=%s)\" = 'fix: comillas simples; nada más' ]"
echo b2 >"$WT/b2"; git -C "$WT" add b2
check "el token se usa una vez (con algo staged)" "! run $WT \"\$out\" && ! git -C $WT diff --cached --quiet -- b2"
printf 'feat: desde archivo\n' >"$W/msg.txt"; cp "$W/msg.txt" "$WT/.msg"; echo c >"$WT/c"; git -C "$WT" add c
run "$WT" "$(hook "$WT" 'git commit -q -F .msg')"
check "-F <archivo>: commitea" "[ \"\$(git -C $WT log -1 --format=%s)\" = 'feat: desde archivo' ]"
echo d >"$WT/c"
run "$WT" "$(hook "$WT" "git commit -a -q --message \"fix: -a y --message\"")"
check "-a y --message: commitea" "[ \"\$(git -C $WT log -1 --format=%s)\" = 'fix: -a y --message' ]"

git -C "$WT2" commit -q --allow-empty -m y-only
git -C "$WT" merge -q --no-ff --no-commit feat/y 2>/dev/null
out="$(hook "$WT" 'git commit --no-edit')"
check "--no-edit durante un merge: reescribe" "[ -n \"\$out\" ]"
run "$WT" "$out"
check "--no-edit durante un merge: queda el merge commiteado" "[ \"\$(git -C $WT rev-list --parents -n1 HEAD | wc -w)\" = 3 ]"
check "--no-edit fuera de un merge: diálogo" "[ -z \"\$(hook $WT 'git commit --no-edit')\" ]"

printf '%s\tfeat/x\n' "$WT" >"$STACK_SYNC_STATE/busy/pr-1"
check "marca viva de stack-sync: reescribe sin Orca" "[ -n \"\$(ORCA_TERMINAL_HANDLE= hook $WT 'git commit -m \"x\"')\" ]"
touch -d '2 hours ago' "$STACK_SYNC_STATE/busy/pr-1"
check "marca vencida de stack-sync: diálogo" "[ -z \"\$(ORCA_TERMINAL_HANDLE= hook $WT 'git commit -m \"x\"')\" ]"
rm -f "$STACK_SYNC_STATE/busy/pr-1"

# --- the reviewers' repros and every shape outside the list. In a worker, a compound or multi-line command with a
# commit at a command position is denied with the reason; a single command outside the list goes to the dialog.
deny_cases=(
  $'echo \'"$(cat <<\'EOF\'\n\'; git push origin HEAD:refs/heads/pwned; echo \'\nEOF\n)"\' && git commit --allow-empty -q -m "x"'
  $'echo \'<<\'EOF\'\n\'; git push origin HEAD:refs/heads/x; echo \'\nEOF\n\' && git commit -m "x"'
  $'git commit -q -m "$(cat <<\'EOF\'\nmsg\nEOF)"; git push origin HEAD:refs/heads/x; : "$(cat <<\'EOF\'\nx\nEOF\n)"'
  $'git commit -m "$(cat <<\'EOF\'\nmsg\nEOF\ngit push origin HEAD\ncat <<\'EOF\'\nx\nEOF\n)"'
  $'git commit -q -F - <<\'EOF\'\nfeat: por stdin\nEOF'
  'git commit -m "x" ; git push' 'git commit -m "x"; git push' 'git commit -m "x" | tail -1' 'git commit -m "x" &'
  $'git commit -m "x" \\\n--no-verify' $'git commit -m x\ngit push' $'git commit -m "x"\ngit push' $'git commit -m "x\ny"'
  'export HUSKY=0; git commit -m "x"' "cd $WT && git commit -m x" 'git add -A && git commit -q -m "x"' 'git add a; git commit -m "x"'
)
for c in "${deny_cases[@]}"; do
  check "worker, deny: ${c//$'\n'/⏎}" "[ \"\$(what $WT \"\$c\")\" = deny ]"
  check "fuera de un worker, diálogo: ${c//$'\n'/⏎}" "[ \"\$(ORCA_TERMINAL_HANDLE= what $WT \"\$c\")\" = dialog ]"
done
repros=(
  "git commit -m 'x'' ; git push'" 'git commit -m "a"'"'b'"
  'git commit -m "$(git push origin HEAD)"' 'git commit -m `git push`' 'git commit -F <(echo hi)'
  'git commit -m "x" > log.txt' "git commit -m it\\'s" 'HUSKY=0 git commit -m "x"' 'env HUSKY=0 git commit -m "x"'
  "git -C $WT commit -m x" 'git -c core.hooksPath=/dev/null commit -m "x"' ' git commit -m "x"' 'git commit  -m "x"' 'git commit -m "x" '
  'git commit -m "a\"b"' 'git commit -m "costo $HOME"' 'git commit --allow-empty -m "x"' 'git commit -s -m "x"' 'git commit -qm x'
  'git commit -m x' 'git commit -m "x" -- a' 'git commit -m "x" *' 'git commit -m "--amend"x' 'git commit -F -' 'git commit -F -x' 'git commit'
  'git commit --amend -m "x"' 'git commit --no-verify -m "x"' 'git commit -n -m "x"' 'git commit -m "x" -n' 'git commit --fixup HEAD'
  'echo "git commit -m x"' 'git push'
)
for c in "${repros[@]}"; do
  check "worker, diálogo: ${c//$'\n'/⏎}" "[ \"\$(what $WT \"\$c\")\" = dialog ]"
done

# --- wrong target or session: dialog
check "compuesto en rama base: diálogo" "[ \"\$(what $DEV 'git add a && git commit -m \\\"x\\\"')\" = dialog ]"
check "compuesto en el checkout principal: diálogo" "[ \"\$(ORCA_TERMINAL_HANDLE=term_o what $R 'git add a && git commit -m \\\"x\\\"')\" = dialog ]"
check "compuesto de otra terminal: diálogo" "[ \"\$(ORCA_TERMINAL_HANDLE=term_x what $WT 'git add a && git commit -m \\\"x\\\"')\" = dialog ]"
check "compuesto de un subagente reviewer: diálogo" "[ -z \"\$(jq -n --arg d $WT '{cwd:\$d,agent_type:\"reviewer\",tool_input:{command:\"git add a && git commit -m x\"}}' | bash $HOOK)\" ]"
check "diálogo: rama base (dev)" "[ -z \"\$(hook $DEV 'git commit -m \"x\"')\" ]"
check "diálogo: rama base por origin/HEAD" "[ -z \"\$(ORCA_TERMINAL_HANDLE=term_h hook $HEADB 'git commit -m \"x\"')\" ]"
check "diálogo: HEAD detached" "[ -z \"\$(ORCA_TERMINAL_HANDLE=term_d hook $DET 'git commit -m \"x\"')\" ]"
check "diálogo: checkout principal" "[ -z \"\$(ORCA_TERMINAL_HANDLE=term_o hook $R 'git commit -m \"x\"')\" ]"
check "diálogo: worker de otro worktree" "[ -z \"\$(hook $WT2 'git commit -m \"x\"')\" ]"
check "diálogo: otra terminal" "[ -z \"\$(ORCA_TERMINAL_HANDLE=term_x hook $WT 'git commit -m \"x\"')\" ]"
check "diálogo: sin Orca" "[ -z \"\$(ORCA_TERMINAL_HANDLE= hook $WT 'git commit -m \"x\"')\" ]"
check "diálogo: subagente reviewer" "[ -z \"\$(hook $WT 'git commit -m \"x\"' reviewer)\" ]"
check "diálogo: subagente scout" "[ -z \"\$(hook $WT 'git commit -m \"x\"' scout)\" ]"
mkdir -p "$WT/.claude"
for d in 'Bash(git commit:*)' 'Bash(git commit *)' 'Bash(git *)' 'Bash(git*)' 'Bash(git c*)' 'Bash(*)' 'Bash'; do
  jq -n --arg d "$d" '{permissions:{deny:[$d]}}' >"$WT/.claude/settings.local.json"
  check "diálogo: deny $d" "[ -z \"\$(hook $WT 'git commit -m \"x\"')\" ]"
done
echo '{"permissions":{"deny":["Bash(git push --force *)"]}}' >"$WT/.claude/settings.local.json"
check "un deny de git push no lo frena" "[ -n \"\$(hook $WT 'git commit -m \"x\"')\" ]"
rm -f "$WT/.claude/settings.local.json"
# a deny more specific than `git commit -m x` still applies to the command it matches
for pair in 'Bash(git commit -a*)|git commit -a -m "x"' 'Bash(git commit -a:*)|git commit -a -m "x"' \
  'Bash(git commit --all*)|git commit --all -m "x"' 'Bash(git commit -q*)|git commit -q -m "x"' 'Bash(git commit -F*)|git commit -F .msg'; do
  jq -n --arg d "${pair%%|*}" '{permissions:{deny:[$d]}}' >"$WT/.claude/settings.local.json"
  check "diálogo: deny ${pair%%|*} con ${pair#*|}" "[ \"\$(what $WT '${pair#*|}')\" = dialog ]"
done
jq -n '{permissions:{deny:["Bash(git commit -a*)"]}}' >"$WT/.claude/settings.local.json"
check "un deny de -a no frena un commit sin -a" "[ \"\$(what $WT 'git commit -q -m \"x\"')\" = rewrite ]"
rm -f "$WT/.claude/settings.local.json"

# a repo with no ask on git commit: nothing changes, neither the rewrite nor the deny
check "repo sin ask: un commit suelto sigue igual" "[ \"\$(ORCA_TERMINAL_HANDLE=term_n what $NW 'git commit -q -m \"x\"')\" = dialog ]"
check "repo sin ask: un compuesto sigue igual (sin deny)" "[ \"\$(ORCA_TERMINAL_HANDLE=term_n what $NW 'git add a && git commit -q -m \"x\"')\" = dialog ]"
mkdir -p "$NW/.claude"; echo '{"permissions":{"ask":["Bash(git commit:*)"]}}' >"$NW/.claude/settings.local.json"
check "repo con ask en settings.local: reescribe" "[ \"\$(ORCA_TERMINAL_HANDLE=term_n what $NW 'git commit -q -m \"x\"')\" = rewrite ]"
check "repo con ask en settings.local: compuesto, deny" "[ \"\$(ORCA_TERMINAL_HANDLE=term_n what $NW 'git add a && git commit -q -m \"x\"')\" = deny ]"
rm -rf "$NW/.claude"

# a message source is required; --no-edit inside a message is text
for c in 'git commit -q' 'git commit -a' 'git commit -a -q'; do
  check "diálogo: sin mensaje, $c" "[ \"\$(what $WT '$c')\" = dialog ]"
done
check "--no-edit dentro del mensaje no cuenta como flag" "[ \"\$(what $WT 'git commit -q -m \"quita --no-edit del script\"')\" = rewrite ]"
git -C "$WT" config core.hooksPath /dev/null
check "diálogo: core.hooksPath en /dev/null" "[ -z \"\$(hook $WT 'git commit -m \"x\"')\" ]"
git -C "$WT" config --unset core.hooksPath

# --- the wrapper alone
wrap() { (cd "$1" && shift && bash "$HOOK" "$@") >/dev/null 2>&1; }
echo e >"$WT/e"; git -C "$WT" add e
tok() { sed -nE 's/.*--token ([0-9a-f]{32}).*/\1/p' <<<"$(hook "$WT" 'git commit -m "x"')"; }
check "wrapper sin token: se niega" "! wrap $WT commit -m x"
check "wrapper con un token inventado: se niega" "! wrap $WT --token 0123456789abcdef0123456789abcdef commit -m x"
check "wrapper: token válido con --amend se niega" "! wrap $WT --token $(tok) commit --amend -m x"
check "wrapper: token válido con --no-verify se niega" "! wrap $WT --token $(tok) commit --no-verify -m x"
echo z >"$WT2/z"; git -C "$WT2" add z
check "wrapper: token de un worktree en otro se niega (con algo staged)" "! wrap $WT2 --token $(tok) commit -m x && ! git -C $WT2 diff --cached --quiet -- z"
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
  ask() { # <settings or empty> <command> [prompt]: the session's stream goes to $E/out
    (cd "$E/wt" && HOME=$REAL_HOME WORKER_COMMIT_ORCA="$W/bin/orca-e2e" ORCA_TERMINAL_HANDLE=term_e timeout 240 claude -p \
      "${3:-Run exactly this Bash command once, verbatim, nothing added or removed:
$2
Then reply only with its output or the denial text.}" \
      --model haiku --dangerously-skip-permissions --setting-sources user,project,local ${1:+--settings "$1"} \
      --output-format stream-json --verbose </dev/null >"$E/out" 2>&1); }
  n0=$(git -C "$E/wt" rev-list --count HEAD)
  ask "" "git commit --allow-empty -q -m sin-hook"
  check "e2e: sin el hook, el ask de git commit lo frena" "[ \$(git -C $E/wt rev-list --count HEAD) = $n0 ]"
  echo a >"$E/wt/a"; git -C "$E/wt" add a
  ask "$set_hook" "git commit -q -m \"con-hook\""
  check "e2e: con el hook, un commit suelto pasa sin diálogo" "[ \"\$(git -C $E/wt log -1 --format=%s)\" = con-hook ]"
  echo b >"$E/wt/b"; git -C "$E/wt" add b
  ask "" "git commit -q -m \"con-push\" && git push origin feat/e"
  check "e2e: sin el hook, el compuesto no trae el motivo" "! grep -q 'comandos aparte' $E/out"
  ask "$set_hook" "git commit -q -m \"con-push\" && git push origin feat/e"
  check "e2e: con el hook, el compuesto se niega con el motivo" "grep -q 'Mandá git add y git commit en comandos aparte' $E/out"
  check "e2e: y no corre (ni commit ni push)" "[ \"\$(git -C $E/wt log -1 --format=%s)\" = con-hook ] && ! git -C $E/origin.git rev-parse -q --verify feat/e >/dev/null"
  echo c >"$E/wt/c"
  ask "$set_hook" "" 'Commit the new file c in this repo with: git add c && git commit -q -m "ciclo" (if a hook denies a command, follow its reason exactly and retry). Do not push. Reply only "listo" or the error.'
  check "e2e: deny, reintento aparte y commit (el ciclo entero)" "[ \"\$(git -C $E/wt log -1 --format=%s)\" = ciclo ]"
fi

echo "$pass ok, $failn fail"
[ "$failn" -eq 0 ]
