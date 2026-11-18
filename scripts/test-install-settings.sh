#!/usr/bin/env bash
# test-install-settings.sh - the settings.json merge of install.sh keeps what other tools own: hook entries
# that do not run a hub hook (e.g. Orca's) and an existing theme (ADR 0038). HOME is a temp dir: nothing real is touched.
set -uo pipefail
HUB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
pass=0; failn=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"; else failn=$((failn + 1)); echo "FAIL $1"; fi; }
run() { env -u CLAUDE_DIR -u CODEX_DIR -u AGENTS_CONFIG_STATE_DIR -u AGENT_CONFIG_STATE_DIR -u CLAUDE_SKILLS_MIRROR -u CLAUDE_PLUGINS_DIR \
        HOME="$W/home" bash "$HUB/install.sh" --profile _template "$@" 2>&1; }
S="$W/home/.claude/settings.json"
BASE="$HUB/config/settings.base.json"
FOREIGN='bash ~/.orca/agent-hooks/claude-hook.sh'
STALE='bash ~/.claude/hooks/removed-from-hub.sh'
NEAR='bash ~/.orca/.claude/hooks/look-alike.sh' # mentions .claude/hooks but is not the installed folder
# number of entries on an event whose commands include $2
count() { jq --arg e "$1" --arg c "$2" '[(.hooks[$e] // [])[] | select(any((.hooks // [])[]; .command == $c))] | length' "$S"; }

run >/dev/null
check "a fresh HOME gets the base hooks" 'jq -e --slurpfile b "$BASE" ".hooks == \$b[0].hooks" "$S" >/dev/null'

# Simulate Orca: a foreign entry on an event the base uses, one on an event it does not, a custom theme;
# plus a stale entry of our own (a hook the base no longer has).
jq --arg f "$FOREIGN" --arg s "$STALE" --arg n "$NEAR" '
  .hooks.PreToolUse += [{"matcher": "*", "hooks": [{"type": "command", "command": $f}]},
                        {"matcher": "Bash", "hooks": [{"type": "command", "command": $n}]}]
  | .hooks.Elicitation = [{"hooks": [{"type": "command", "command": $f}]}]
  | .hooks.Stop += [{"hooks": [{"type": "command", "command": $s}]}]
  | .theme = "custom:orca"' "$S" >"$S.tmp" && mv "$S.tmp" "$S"
run >/dev/null

nbase="$(jq '.hooks.PreToolUse | length' "$BASE")"
check "a foreign entry on a base event survives" '[ "$(count PreToolUse "$FOREIGN")" -eq 1 ]'
check "a look-alike path outside ~/.claude/hooks is not taken as owned" '[ "$(count PreToolUse "$NEAR")" -eq 1 ]'
check "foreign entries come after the base entries, in their order" '[ "$(jq ".hooks.PreToolUse | length" "$S")" -eq $((nbase + 2)) ] && jq -e --arg f "$FOREIGN" --arg n "$NEAR" "[.hooks.PreToolUse[-2:][].hooks[0].command] == [\$f, \$n]" "$S" >/dev/null'
check "a foreign entry on an event the base lacks survives" '[ "$(count Elicitation "$FOREIGN")" -eq 1 ]'
check "an owned stale entry is removed" '[ "$(count Stop "$STALE")" -eq 0 ]'
check "every base hook entry is present" 'jq -e --slurpfile b "$BASE" ". as \$r | [\$b[0].hooks | to_entries[] | .key as \$e | .value[] as \$x | any((\$r.hooks[\$e] // [])[]; . == \$x)] | all" "$S" >/dev/null'
check "an existing theme is kept" 'jq -e ".theme == \"custom:orca\"" "$S" >/dev/null'

before="$(sha1sum "$S")"; run >/dev/null
check "a second run leaves settings.json byte-identical" '[ "$before" = "$(sha1sum "$S")" ]'
check "no duplicated foreign entries" '[ "$(count PreToolUse "$FOREIGN")" -eq 1 ] && [ "$(count Elicitation "$FOREIGN")" -eq 1 ]'

jq 'del(.theme)' "$S" >"$S.tmp" && mv "$S.tmp" "$S"; run >/dev/null
check "a file with no theme gets the base theme" 'jq -e --slurpfile b "$BASE" ".theme == \$b[0].theme" "$S" >/dev/null'

# A foreign entry written before the base ones, an entry that mixes a hub command with a foreign one, a
# malformed entry, and an event that only holds stale entries of our own.
MIXED='bash ~/.other-tool/hook.sh'
jq --arg f "$FOREIGN" --arg s "$STALE" --arg m "$MIXED" '
  .hooks.PostToolUse = ([{"hooks": [{"type": "command", "command": $f}]}] + (.hooks.PostToolUse // []))
  | .hooks.Stop += [{"hooks": [{"type": "command", "command": $s}, {"type": "command", "command": $m}]}]
  | .hooks.SessionEnd = [{"hooks": ["not-an-object"]}]
  | .hooks.Notification = [{"hooks": [{"type": "command", "command": $s}]}]' "$S" >"$S.tmp" && mv "$S.tmp" "$S"
before="$(sha1sum "$S")"; run --dry-run >/dev/null
check "--dry-run writes nothing" '[ "$before" = "$(sha1sum "$S")" ]'
run >/dev/null
check "a foreign entry written first ends after the base entries" 'jq -e --arg f "$FOREIGN" "(.hooks.PostToolUse | last | .hooks[0].command) == \$f" "$S" >/dev/null && [ "$(count PostToolUse "$FOREIGN")" -eq 1 ]'
check "a mixed entry keeps its foreign command and loses the hub one" '[ "$(count Stop "$MIXED")" -eq 1 ] && [ "$(count Stop "$STALE")" -eq 0 ]'
check "a malformed entry does not break the merge and is kept" 'jq -e ".hooks.SessionEnd == [{\"hooks\": [\"not-an-object\"]}]" "$S" >/dev/null'
check "an event holding only stale hub entries is removed" 'jq -e ".hooks | has(\"Notification\") | not" "$S" >/dev/null || jq -e --slurpfile b "$BASE" "\$b[0].hooks | has(\"Notification\")" "$S" >/dev/null'

echo; echo "passed $pass, failed $failn"
[ "$failn" -eq 0 ]
