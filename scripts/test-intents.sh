#!/usr/bin/env bash
# test-intents.sh - offline checks for the intent router: gen-intents.sh, intent-router.sh, detect-stack.sh,
# the SessionStart project checks, per-project plugins (project-agents.sh) and workspace.sh (personal mode).
# Never touches ~/.config or organizations/: state is redirected to a temp dir; the org checks run a copy of the
# router inside a temp hub with a fake org.
set -uo pipefail
HUB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
export AGENTS_CONFIG_STATE_DIR="$W/state" XDG_RUNTIME_DIR="$W/run"; mkdir -p "$XDG_RUNTIME_DIR"
unset CAO_TERMINAL_ID  # the hooks change behaviour inside CAO panes; tests must not depend on where they run
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
check "AGENTS.md table lists github-usage" 'sed -n "/intents:start/,/intents:end/p" "$HUB/config/AGENTS.md" | grep -q "github-usage"'

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
check "Bash 'cd x && git push' -> github-usage" 'tool Bash "cd /tmp && git push origin x" | grep -q "github-usage"'
check "Bash 'gh issue list' -> github-usage" 'tool Bash "gh issue list" | grep -q "github-usage"'
check "Bash 'ls' is silent" '[ -z "$(tool Bash "ls -la")" ]'
check "unknown tool is silent" '[ -z "$(tool Read)" ]'
check "Jira key in a prompt (lowercased) -> jira-usage" 'prompt "mirá el ticket abc-123" "$W/plain" | grep -q "jira-usage"'
check "plugin shortcut: unknown-cause bug -> systematic-debugging" 'prompt "no sé por qué falla el login" "$W/plain" | grep -q "systematic-debugging"'

# --- hook: organization replacement skills (router copied into a temp hub; HUB is derived from its location)
OH="$W/orghub"; mkdir -p "$OH/config/hooks" "$OH/scripts" "$OH/organizations/acme/skills/acme-github"
cp "$HUB/config/hooks/intent-router.sh" "$OH/config/hooks/"; cp "$HUB/config/intents.json" "$OH/config/"; cp "$HUB/scripts/orgs.sh" "$OH/scripts/"
printf '%s\n' '{"name":"acme","match":{"gh_owners":["acme-inc"],"remote_patterns":[]},"replaces":{"github-usage":"acme-github","jira-usage":"acme-jira","/smart-commit":"/acme-commit"}}' >"$OH/organizations/acme/org.json"
printf -- '---\nname: acme-github\n---\n' >"$OH/organizations/acme/skills/acme-github/SKILL.md"
bash "$OH/scripts/orgs.sh" index >/dev/null 2>&1; jq '.orgs = [{name:"acme",remote:"x"}]' "$AGENTS_CONFIG_STATE_DIR/organizations.json" >"$W/reg.json" && mv "$W/reg.json" "$AGENTS_CONFIG_STATE_DIR/organizations.json"
mkrepo "$W/acme-repo"; git -C "$W/acme-repo" remote add origin https://github.com/acme-inc/shop.git
mkrepo "$W/other-repo"; git -C "$W/other-repo" remote add origin https://github.com/someone/shop.git
oprompt() { jq -n --arg p "$1" --arg c "$2" --arg s "s$RANDOM$RANDOM" '{hook_event_name:"UserPromptSubmit",prompt:$p,cwd:$c,session_id:$s}' \
  | bash "$OH/config/hooks/intent-router.sh" | jq -r '.hookSpecificOutput.additionalContext // empty'; }
otool() { jq -n --arg t "$1" --arg cmd "${2:-}" --arg c "$3" --arg s "s$RANDOM$RANDOM" '{hook_event_name:"PreToolUse",tool_name:$t,tool_input:{command:$cmd},cwd:$c,session_id:$s}' \
  | bash "$OH/config/hooks/intent-router.sh" | jq -r '.hookSpecificOutput.additionalContext // empty'; }
check "org repo: git phrase hints the org skill, not github-usage, and keeps the run command" 'out="$(oprompt "traete los cambios" "$W/acme-repo")"; grep -q "acme-github" <<<"$out" && grep -q "rules win" <<<"$out" && grep -q "git pull origin" <<<"$out" && ! grep -q "skill \`github-usage\`" <<<"$out"'
check "org repo: Bash git push hints the org skill" 'otool Bash "git push origin x" "$W/acme-repo" | grep -q "acme-github"'
check "org repo: replacement the org does not ship falls back to the hub skill" 'otool mcp__claude_ai_Atlassian_Rovo__getJiraIssue "" "$W/acme-repo" | grep -q "jira-usage"'
check "repo of another owner: still github-usage" 'out="$(oprompt "traete los cambios" "$W/other-repo")"; grep -q "github-usage" <<<"$out" && ! grep -q "acme-github" <<<"$out"'
check "repo without a remote: still github-usage" 'oprompt "traete los cambios" "$W/plain" | grep -q "github-usage"'
check "org with an unreadable org.json: falls back silently" 'echo "{" >"$OH/organizations/acme/org.json"; oprompt "traete los cambios" "$W/acme-repo" | grep -q "github-usage"'

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
check "loose folder without repos does not mention workspace mode" '! start "$W/ss/loose" | grep -q "workspace mode"'
mkdir -p "$W/ss/multi/front" "$W/ss/multi/back"; git -C "$W/ss/multi/front" init -q; git -C "$W/ss/multi/back" init -q
check "folder with 2 repos names them and offers workspace mode" 'out="$(start "$W/ss/multi")"; grep -q "holds 2 git repos (back, front)" <<<"$out" && grep -q "workspace mode" <<<"$out" && grep -q "unrelated projects" <<<"$out"'
mkdir -p "$W/fakehome/a" "$W/fakehome/b"; git -C "$W/fakehome/a" init -q; git -C "$W/fakehome/b" init -q
check "HOME itself never gets the workspace offer" '! HOME="$W/fakehome" start "$W/fakehome" | grep -q "workspace mode"'
check "SessionStart routing text points to CLAUDE.md and stays short" 'out="$(start "$W/ss/ready")"; grep -q "Agent routing" <<<"$out" && grep -q "scout" <<<"$out" && [ "${#out}" -lt 520 ]'
check "SessionStart names the one question Continuar / Plan S / Plan L (ADR 0022)" 'start "$W/ss/ready" | grep -q "Continuar / Plan S / Plan L"'

# --- CAO panes (caolg leader and workers): ADR 0020
check "CAO pane: SessionStart adds nothing (no routing, no project-init nudge)" '[ -z "$(CAO_TERMINAL_ID=t1 start "$W/ss/noagents")" ]'
check "CAO pane: phrases stay silent" '[ -z "$(CAO_TERMINAL_ID=t1 prompt "traete los cambios" "$W/plain")" ] && [ -n "$(prompt "traete los cambios" "$W/plain")" ]'
check "CAO pane: git/gh in Bash stays silent" '[ -z "$(CAO_TERMINAL_ID=t1 tool Bash "git commit -m x")" ] && [ -n "$(tool Bash "git commit -m x")" ]'
check "CAO pane: integration MCP tools are still routed" '[ -n "$(CAO_TERMINAL_ID=t1 tool mcp__claude_ai_Slack__slack_send_message)" ]'
check "task notifications are not read as phrases" '[ -z "$(prompt "<task-notification>traete los cambios</task-notification>" "$W/plain")" ]'

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
WSH="$HUB/skills/devops/project-init/scripts/workspace.sh"
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
