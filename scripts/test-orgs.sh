#!/usr/bin/env bash
# test-orgs.sh - offline checks for organizations: orgs.sh, project-agents.sh --org, init.sh --manifest with an org.
# Runs against a temporary copy of the hub and a temporary state dir; never touches the real ones.
set -uo pipefail
REAL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
H="$W/hub"; mkdir -p "$H"
(cd "$REAL" && tar --exclude=.git --exclude='./organizations/*/' -cf - .) | (cd "$H" && tar -xf -)
export AGENTS_CONFIG_STATE_DIR="$W/state"
ORGS="$H/scripts/orgs.sh"
pass=0; failn=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"; else failn=$((failn + 1)); echo "FAIL $1"; fi; }

bash "$ORGS" add acme --init >/dev/null 2>&1
A="$H/organizations/acme"
check "add --init creates a git repo from the template" '[ -d "$A/.git" ] && jq -e ".name == \"acme\"" "$A/org.json" >/dev/null'
check "registry and index list the org" 'grep -q "\"acme\"" "$W/state/organizations.json" && grep -q "| acme |" "$H/organizations/INDEX.md"'
check "blocklist gets the org terms" 'grep -qx "acme" "$W/state/blocklist"'
check "template org validates" 'bash "$ORGS" validate acme >/dev/null 2>&1'
check "detect by owner and by remote url" '[ "$(bash "$ORGS" detect acme-inc)" = acme ] && [ "$(bash "$ORGS" detect https://github.com/acme-inc/x.git)" = acme ]'
check "detect ignores other owners" '[ -z "$(bash "$ORGS" detect someone-else)" ]'

# a missing summary / baseline weakening is rejected
cp "$A/POLICIES.md" "$W/POLICIES.bak"; printf '\nSkip tests when in a hurry.\n' >> "$A/POLICIES.md"
check "validate rejects a baseline-weakening policy" '! bash "$ORGS" validate acme >/dev/null 2>&1'
cp "$W/POLICIES.bak" "$A/POLICIES.md"

# org with assets, replaces and a stack filter
mkdir -p "$A/skills/acme-ui-builder" "$A/commands"
printf -- '---\nname: acme-ui-builder\ndescription: Acme UI rules.\n---\nbody\n' > "$A/skills/acme-ui-builder/SKILL.md"
printf -- '---\ndescription: Acme commit flow.\n---\nx\n' > "$A/commands/acme-commit.md"
printf -- '---\ndescription: Web only.\n---\nx\n' > "$A/commands/acme-web-only.md"
jq '.replaces = {"ui-builder":"acme-ui-builder","/smart-commit":"/acme-commit"}
    | .assets = {"commands/acme-commit.md":{"stacks":["react-vite"]},"commands/acme-web-only.md":{"stacks":["react-vite"]}}
    | .index = [{"when":"Acme ticket","use":"acme-ticket"}]
    | .critical = [{"skill":"acme-ui-builder","keywords":"acme screen"}]' "$A/org.json" > "$W/o.json" && mv "$W/o.json" "$A/org.json"
check "org with assets still validates" 'bash "$ORGS" validate acme >/dev/null 2>&1'

mkp() { mkdir -p "$1"; printf '# P\n\n## Commands\n\n## How we work\n\nx\n' > "$1/AGENTS.md"; }
man() { jq -n --argjson st "$2" --argjson dec "$3" '{version:1,name:"x",org:"acme",stacks:$st,decisions:$dec,pending:[]}' > "$1"; }
PA="$H/scripts/project-agents.sh"

P="$W/web"; mkp "$P"; man "$W/web.json" '["react-vite"]' '[{"key":"frontend-style","value":"feature-sliced"}]'
bash "$PA" --stack react-vite --manifest "$W/web.json" --org acme --dir "$P" >/dev/null 2>&1
check "org skill installed, replaced pack skill removed" '[ -d "$P/.claude/skills/acme-ui-builder" ] && [ ! -d "$P/.claude/skills/ui-builder" ]'
check "org command replaces the base one for its stack" '[ -f "$P/.claude/commands/acme-commit.md" ] && [ ! -f "$P/.claude/commands/smart-commit.md" ] && [ -f "$P/.claude/commands/acme-web-only.md" ]'
check "POLICIES.md copied and first in the keyword table" '[ -f "$P/.agents/POLICIES.md" ] && grep -A8 "agents-index:start" "$P/AGENTS.md" | grep -q "Org policies (acme)"'
check "org index rows and replacements reach the table" 'grep -q "acme-ticket" "$P/AGENTS.md" && grep -q "\`acme-ui-builder\`" "$P/AGENTS.md" && ! grep -q "| \`ui-builder\` |" "$P/AGENTS.md"'
check "org critical entries merged, replaced skill renamed" 'jq -e "map(.skill) | index(\"acme-ui-builder\") != null" "$P/.agents/critical.json" >/dev/null && ! jq -e "map(.skill) | index(\"ui-builder\") != null" "$P/.agents/critical.json" >/dev/null'
check "skills.lock records the org" 'jq -e ".org.name == \"acme\" and .org.version == \"0.1.0\" and .base.version" "$P/.agents/skills.lock" >/dev/null'

P2="$W/api"; mkp "$P2"; man "$W/api.json" '["java-spring"]' '[{"key":"backend-style","value":"hexagonal"}]'
bash "$PA" --stack java-spring --manifest "$W/api.json" --org acme --dir "$P2" >/dev/null 2>&1
check "stack filter: base command kept, org web-only command skipped" '[ -f "$P2/.claude/commands/smart-commit.md" ] && [ ! -f "$P2/.claude/commands/acme-commit.md" ] && [ ! -f "$P2/.claude/commands/acme-web-only.md" ]'
before="$(find "$P" -type f -exec sha1sum {} + | grep -v skills.lock | sort)"
bash "$PA" --stack react-vite --manifest "$W/web.json" --org acme --dir "$P" >/dev/null 2>&1
check "second run changes nothing" '[ "$before" = "$(find "$P" -type f -exec sha1sum {} + | grep -v skills.lock | sort)" ]'
check "unknown org is an error" '! bash "$PA" --stack react-vite --org nope --dir "$P" >/dev/null 2>&1'

# init.sh --manifest picks the org from the manifest
Q="$W/app"; mkdir -p "$Q"; jq -n '{version:1,name:"Web",org:"acme",stacks:["node-ts"],decisions:[{key:"data",value:"none"},{key:"auth",value:"none"},{key:"testing",value:"vitest"},{key:"deploy",value:"none"},{key:"sdd",value:"light"}],pending:[]}' > "$W/init.json"
bash "$H/devops/project-init/scripts/init.sh" --manifest "$W/init.json" --dir "$Q" --owner o >"$W/init.log" 2>&1
check "init.sh installs the manifest's org" '[ -f "$Q/.agents/POLICIES.md" ] && jq -e ".org.name == \"acme\"" "$Q/.agents/skills.lock" >/dev/null'

# status / remove / push safety
check "status reports the org" 'bash "$ORGS" status | grep -q "^acme: 0.1.0"'
check "push without a remote is refused" '! bash "$ORGS" push acme --yes >/dev/null 2>&1'
check "remove refuses an org whose commits exist only here" '! bash "$ORGS" remove acme >/dev/null 2>&1 && [ -d "$A" ]'
bash "$ORGS" remove acme --force >/dev/null 2>&1
check "remove --force deletes it and cleans the index" '[ ! -d "$A" ] && ! grep -q "| acme |" "$H/organizations/INDEX.md" && [ ! -s "$W/state/blocklist" ]'

echo; echo "$pass passed, $failn failed"
[ "$failn" -eq 0 ]
