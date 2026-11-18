#!/usr/bin/env bash
# test-install-settings.sh - the settings.json merge of install.sh keeps what other tools own: hook entries
# that do not run a hub hook (e.g. Orca's) and an existing theme (ADR 0038). HOME is a temp dir: nothing real is touched.
set -uo pipefail
HUB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
pass=0; failn=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"; else failn=$((failn + 1)); echo "FAIL $1"; fi; }
run() { HOME="$W/home" bash "$HUB/install.sh" --profile _template "$@" 2>&1; }
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

echo; echo "passed $pass, failed $failn"
[ "$failn" -eq 0 ]
