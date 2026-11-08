#!/usr/bin/env bash
# test-intents.sh - offline checks for the intent router: gen-intents.sh, intent-router.sh, detect-stack.sh,
# the SessionStart project checks, per-project plugins (project-agents.sh) and workspace.sh (personal mode).
# Never touches ~/.config or organizations/: state is redirected to a temp dir and no org is used.
set -uo pipefail
HUB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
export AGENTS_CONFIG_STATE_DIR="$W/state" XDG_RUNTIME_DIR="$W/run"; mkdir -p "$XDG_RUNTIME_DIR"
pass=0; failn=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"; else failn=$((failn + 1)); echo "FAIL $1"; fi; }

ROUTER="$HUB/config/hooks/intent-router.sh"
START="$HUB/config/hooks/session-start.sh"
# prompt <text> <cwd>  -> additionalContext ("" when silent); fresh session id each call unless SID is set
# (calls run inside $(...) subshells, so the id must be random, not a counter)
prompt() { jq -n --arg p "$1" --arg c "$2" --arg s "${SID:-s$RANDOM$RANDOM}" '{hook_event_name:"UserPromptSubmit",prompt:$p,cwd:$c,session_id:$s}' \
  | bash "$ROUTER" | jq -r '.hookSpecificOutput.additionalContext // empty'; }
tool() { jq -n --arg t "$1" --arg cmd "${2:-}" --arg c "$W" --arg s "s$RANDOM$RANDOM" '{hook_event_name:"PreToolUse",tool_name:$t,tool_input:{command:$cmd},cwd:$c,session_id:$s}' \
  | bash "$ROUTER" | jq -r '.hookSpecificOutput.additionalContext // empty'; }
mkrepo() { mkdir -p "$1" && git -C "$1" init -q; }

# --- generated table
check "gen-intents --check is up to date" 'bash "$HUB/scripts/gen-intents.sh" --check >/dev/null 2>&1'
check "every skill with intents has a label, regex and command" '[ "$(jq "[.skills[].intents[] | select(.label == \"\" or .re == \"\" or .cmd == \"\")] | length" "$HUB/config/intents.json")" -eq 0 ]'
check "AGENTS.md table lists git-workflow" 'sed -n "/intents:start/,/intents:end/p" "$HUB/config/AGENTS.md" | grep -q "git-workflow"'

# --- hook: base branch resolution
mkrepo "$W/flow"; mkdir -p "$W/flow/scripts"; : >"$W/flow/scripts/gh-flow.sh"
mkrepo "$W/oh"; git -C "$W/oh" remote add origin https://github.com/someone/repo.git; git -C "$W/oh" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/master
mkrepo "$W/plain"
mkrepo "$W/rule"; printf '# x\n\nBase branch is `develop`.\n' >"$W/rule/AGENTS.md"
check "gh-flow repo -> pull from dev" 'prompt "traete los cambios" "$W/flow" | grep -q "git pull origin dev"'
check "origin/HEAD=master -> pull from master" 'prompt "Traé los cambios" "$W/oh" | grep -q "git pull origin master"'
check "no remote -> main fallback" 'prompt "bajá los cambios" "$W/plain" | grep -q "git pull origin main"'
check "AGENTS.md base-branch rule wins over origin/HEAD" 'prompt "pull the latest changes" "$W/rule" | grep -q "git pull origin develop"'
check "English phrase matches" 'prompt "open a PR please" "$W/flow" | grep -q "gh pr create --base dev"'
# --- hook: once per session, silence, subagents
SID=same; first="$(prompt "traete los cambios" "$W/flow")"; second="$(prompt "traete los cambios" "$W/flow")"; unset SID
check "first mention injects, second is silent (same session)" '[ -n "$first" ] && [ -z "$second" ]'
check "unrelated prompt is silent" '[ -z "$(prompt "explicame como funciona un for" "$W/flow")" ]'
check "silent inside a subagent" '[ -z "$(jq -n --arg c "$W/flow" "{hook_event_name:\"UserPromptSubmit\",agent_type:\"worker\",prompt:\"traete los cambios\",cwd:\$c,session_id:\"sx\"}" | bash "$ROUTER")" ]'
check "hook never blocks: exit 0 on garbage input" 'echo "not json" | bash "$ROUTER" >/dev/null 2>&1'
# --- hook: tools and commands
check "Slack MCP tool -> slack-usage" 'tool mcp__claude_ai_Slack__slack_read_channel | grep -q "slack-usage"'
check "Jira MCP tool -> jira-usage" 'tool mcp__claude_ai_Atlassian_Rovo__getJiraIssue | grep -q "jira-usage"'
check "Obsidian MCP tool -> obsidian-vault" 'tool mcp__obsidian__read_note | grep -q "obsidian-vault"'
check "Bash 'cd x && git push' -> git-workflow" 'tool Bash "cd /tmp && git push origin x" | grep -q "git-workflow"'
check "Bash 'gh issue list' -> github-usage" 'tool Bash "gh issue list" | grep -q "github-usage"'
check "Bash 'ls' is silent" '[ -z "$(tool Bash "ls -la")" ]'
check "unknown tool is silent" '[ -z "$(tool Read)" ]'
check "Jira key in a prompt (lowercased) -> jira-usage" 'prompt "mirá el ticket abc-123" "$W/plain" | grep -q "jira-usage"'
check "plugin shortcut: unknown-cause bug -> systematic-debugging" 'prompt "no sé por qué falla el login" "$W/plain" | grep -q "systematic-debugging"'

# --- detect-stack
mkdir -p "$W/ds/next" "$W/ds/nest" "$W/ds/none"
echo '{"dependencies":{"next":"1","react":"1"}}' >"$W/ds/next/package.json"
echo '{"dependencies":{"@nestjs/core":"1"}}' >"$W/ds/nest/package.json"; : >"$W/ds/nest/template.yaml"
check "detect-stack: next" '[ "$(bash "$HUB/scripts/detect-stack.sh" "$W/ds/next")" = "next" ]'
check "detect-stack: nestjs + aws" '[ "$(bash "$HUB/scripts/detect-stack.sh" "$W/ds/nest")" = "nestjs,aws" ]'
check "detect-stack: nothing recognised prints nothing" '[ -z "$(bash "$HUB/scripts/detect-stack.sh" "$W/ds/none")" ]'

# --- SessionStart project checks
start() { jq -n --arg c "$1" '{hook_event_name:"SessionStart",cwd:$c}' | bash "$START" | jq -r '.hookSpecificOutput.additionalContext'; }
mkrepo "$W/ss/noagents"
mkrepo "$W/ss/nextrepo"; echo '# a' >"$W/ss/nextrepo/AGENTS.md"; echo '{"dependencies":{"next":"1"}}' >"$W/ss/nextrepo/package.json"
mkrepo "$W/ss/ready"; echo '# a' >"$W/ss/ready/AGENTS.md"; mkdir -p "$W/ss/ready/.agents"; echo '{}' >"$W/ss/ready/.agents/project.json"
mkdir -p "$W/ss/ws"; echo '# ws' >"$W/ss/ws/AGENTS.md"; mkdir -p "$W/ss/loose"
check "repo without AGENTS.md -> propose project-init" 'start "$W/ss/noagents" | grep -q "project-init"'
check "repo without stack skills -> propose project-agents.sh with the detected stack" 'start "$W/ss/nextrepo" | grep -q "project-agents.sh --stack next --dry-run"'
check "configured repo -> no setup nudge" '! start "$W/ss/ready" | grep -qE "project-init|project-agents.sh"'
check "workspace folder -> read its AGENTS.md" 'start "$W/ss/ws" | grep -q "Workspace folder"'
check "loose folder -> one-line notice" 'start "$W/ss/loose" | grep -q "Not inside a git repo or workspace"'

# --- per-project plugins
mkdir -p "$W/pl/next" "$W/pl/vite/.claude"
echo '{"permissions":{"allow":["Bash(ls:*)"]},"enabledPlugins":{"foo@bar":true}}' >"$W/pl/vite/.claude/settings.json"
bash "$HUB/scripts/project-agents.sh" --stack next --dir "$W/pl/next" >/dev/null 2>&1
bash "$HUB/scripts/project-agents.sh" --stack react-vite --dir "$W/pl/vite" >/dev/null 2>&1
check "next stack enables vercel + playwright for the project" 'jq -e ".enabledPlugins | has(\"vercel@claude-plugins-official\") and has(\"playwright@anthropic-plugin-directory\")" "$W/pl/next/.claude/settings.json" >/dev/null'
check "react-vite enables playwright and keeps existing settings" 'jq -e ".enabledPlugins[\"foo@bar\"] and .enabledPlugins[\"playwright@anthropic-plugin-directory\"] and (.permissions.allow | length == 1)" "$W/pl/vite/.claude/settings.json" >/dev/null'
check "vercel and playwright are off in the global base" '[ "$(jq -r ".enabledPlugins[\"vercel@claude-plugins-official\"], .enabledPlugins[\"playwright@anthropic-plugin-directory\"]" "$HUB/config/settings.base.json" | tr "\n" " ")" = "false false " ]'
check "--no-packs installs no pack commands" 'bash "$HUB/scripts/project-agents.sh" --stack kotlin --no-packs --dir "$W/pl/np" >/dev/null 2>&1 && [ ! -d "$W/pl/np/.claude/commands" ]'

# --- workspace.sh (personal mode)
WS="$W/ws"; mkdir -p "$WS/front" "$WS/back"; git -C "$WS/front" init -q; git -C "$WS/back" init -q
WA=(--dir "$WS" --name app --repo front:frontend:react-vite --repo back:backend:java-spring)
WSH="$HUB/devops/project-init/scripts/workspace.sh"
check "workspace.sh refuses fewer than 2 repos" '! bash "$WSH" --dir "$WS" --name app --repo front:frontend:- >/dev/null 2>&1'
bash "$WSH" "${WA[@]}" >/dev/null 2>&1
check "workspace.sh writes AGENTS.md with marker and CLAUDE.md" 'head -n 1 "$WS/AGENTS.md" | grep -q workspace-init && grep -q "@AGENTS.md" "$WS/CLAUDE.md"'
check "workspace.sh ignores the child repos in its own git repo" '[ -d "$WS/.git" ] && grep -qx "/front/" "$WS/.gitignore" && grep -qx "/back/" "$WS/.gitignore"'
check "workspace.sh makes no commit and adds no remote" '! git -C "$WS" rev-parse HEAD >/dev/null 2>&1 && [ -z "$(git -C "$WS" remote)" ]'
check "workspace.sh re-run is idempotent" 'before="$(sha1sum "$WS/AGENTS.md" "$WS/.gitignore")"; bash "$WSH" "${WA[@]}" >/dev/null 2>&1; [ "$before" = "$(sha1sum "$WS/AGENTS.md" "$WS/.gitignore")" ]'
echo "mine" >"$WS/CLAUDE.md"; bash "$WSH" "${WA[@]}" >/dev/null 2>&1
check "workspace.sh never overwrites a file with its own content" '[ "$(cat "$WS/CLAUDE.md")" = "mine" ]'
mkdir -p "$W/foreign/a" "$W/foreign/b"; git -C "$W/foreign" init -q; git -C "$W/foreign/a" init -q; git -C "$W/foreign/b" init -q
check "workspace.sh refuses a git repo that is not its own workspace" '! bash "$WSH" --dir "$W/foreign" --name f --repo a:x:- --repo b:y:- >/dev/null 2>&1'

echo; echo "passed $pass, failed $failn"
[ "$failn" -eq 0 ]
