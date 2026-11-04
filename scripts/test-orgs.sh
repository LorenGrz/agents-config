#!/usr/bin/env bash
# test-orgs.sh - offline checks for organizations: orgs.sh, project-agents.sh --org, init.sh --manifest with an org.
# Runs against a temporary copy of the hub and a temporary state dir; never touches the real ones.
set -uo pipefail
REAL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
H="$W/hub"; mkdir -p "$H"
(cd "$REAL" && tar --exclude=.git --exclude='./organizations' -cf - .) | (cd "$H" && tar -xf -)
mkdir -p "$H/organizations" && cp -r "$REAL/organizations/_template" "$REAL/organizations/README.md" "$H/organizations/"
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
    | .index = [{"when":"Acme ticket","use":"acme-ticket"},{"when":"Acme backend only","use":"acme-erp","stacks":["java-spring"]}]
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
check "org rows honor their stack filter" 'grep -q "acme-ticket" "$P/AGENTS.md" && ! grep -q "acme-erp" "$P/AGENTS.md" && grep -q "acme-erp" "$P2/AGENTS.md"'
check "pack commands are rewritten to the replacing skill" 'grep -q ".claude/skills/acme-ui-builder/" "$P/.claude/commands/ui-build.md" && ! grep -q ".claude/skills/ui-builder/" "$P/.claude/commands/ui-build.md"'
check "second run changes nothing" '[ "$before" = "$(find "$P" -type f -exec sha1sum {} + | grep -v skills.lock | sort)" ]'
check "unknown org is an error" '! bash "$PA" --stack react-vite --org nope --dir "$P" >/dev/null 2>&1'

# init.sh --manifest picks the org from the manifest
Q="$W/app"; mkdir -p "$Q"; jq -n '{version:1,name:"Web",org:"acme",stacks:["node-ts"],decisions:[{key:"data",value:"none"},{key:"auth",value:"none"},{key:"testing",value:"vitest"},{key:"deploy",value:"none"},{key:"sdd",value:"light"}],pending:[]}' > "$W/init.json"
bash "$H/devops/project-init/scripts/init.sh" --manifest "$W/init.json" --dir "$Q" --owner o >"$W/init.log" 2>&1
check "init.sh installs the manifest's org" '[ -f "$Q/.agents/POLICIES.md" ] && jq -e ".org.name == \"acme\"" "$Q/.agents/skills.lock" >/dev/null'


# --- review regressions: hostile or broken orgs must fail closed and touch nothing
mkorg() { bash "$ORGS" add "$1" --init >/dev/null 2>&1; jq --arg n "$1" '.match.gh_owners = [$n + "-inc"]' "$H/organizations/$1/org.json" > "$W/t.json" && mv "$W/t.json" "$H/organizations/$1/org.json"; }
setj() { jq "$2" "$H/organizations/$1/org.json" > "$W/t.json" && mv "$W/t.json" "$H/organizations/$1/org.json"; }
hostile() { # hostile <org> : project with a src/keep.txt that must survive
  local d="$W/h-$1"; rm -rf "$d"; mkp "$d"; mkdir -p "$d/src"; echo keep > "$d/src/keep.txt"
  bash "$PA" --stack react-vite --org "$1" --dir "$d" >/dev/null 2>&1; HRC=$?; HD="$d"
}
mkorg evil; setj evil '.replaces = {"../../src":"x"}'
hostile evil
check "replaces key with ../ is rejected and src/ survives" '[ "$HRC" -ne 0 ] && [ -f "$HD/src/keep.txt" ]'
setj evil '.replaces = {"/../../src/keep":"/x"}'; hostile evil
check "replaces command key with ../ is rejected" '[ "$HRC" -ne 0 ] && [ -f "$HD/src/keep.txt" ]'
setj evil '.replaces = {"ui-builder":"a|b&c"}'; hostile evil
check "replaces value with sed metacharacters is rejected" '[ "$HRC" -ne 0 ]'
mkorg linky; mkdir -p "$H/organizations/linky/skills/linky-skill"; printf -- '---\nname: linky-skill\ndescription: x\n---\n' > "$H/organizations/linky/skills/linky-skill/SKILL.md"
echo "TOPSECRET" > "$W/secret.txt"; ln -s "$W/secret.txt" "$H/organizations/linky/skills/linky-skill/leak.txt"
hostile linky
check "org with a symlink is rejected and nothing is copied" '[ "$HRC" -ne 0 ] && ! grep -rqs TOPSECRET "$HD/.claude" 2>/dev/null'
mkorg badpol; printf '# Bad\n\n- Skip the tests when in a hurry.\n\n## A\n' > "$H/organizations/badpol/POLICIES.md"
hostile badpol
check "project-agents --org fails closed when the org does not validate" '[ "$HRC" -ne 0 ] && [ ! -d "$HD/.claude/commands" ]'
P3="$W/nomf"; mkp "$P3"
bash "$PA" --stack react-vite --org acme --dir "$P3" >/dev/null 2>&1
check "--org works without --manifest" '[ $? -eq 0 ] && [ -f "$P3/.agents/POLICIES.md" ]'

# orgs.sh name safety
bash "$ORGS" remove "" --force >/dev/null 2>&1; bash "$ORGS" remove ../config --force >/dev/null 2>&1; bash "$ORGS" remove ../../hub --force >/dev/null 2>&1
check "remove with an empty or traversing name deletes nothing" '[ -d "$H/organizations/_template" ] && [ -d "$H/organizations/acme" ] && [ -d "$H/config" ]'
mkorg plc; setj plc '.blocklist_terms = ["acme"]'
check "validate rejects the acme placeholder term in another org" '! bash "$ORGS" validate plc >/dev/null 2>&1'
mkorg multi; rm -f "$H/organizations/multi/POLICIES.md"; mkdir -p "$H/organizations/multi/skills/nodesc"; printf -- '---\nname: nodesc\n---\n' > "$H/organizations/multi/skills/nodesc/SKILL.md"
out="$(bash "$ORGS" validate multi 2>&1)"
check "validate reports every failing check, not just the first" '[ "$(grep -c "^orgs:" <<<"$out")" -ge 2 ]'
mkorg fresh
check "a fresh --init org has no placeholder blocklist term" '[ "$(jq ".blocklist_terms | length" "$H/organizations/fresh/org.json")" -eq 0 ]'
bash "$ORGS" index >/dev/null 2>&1
check "blocklist includes the match owners" 'grep -qx "fresh-inc" "$W/state/blocklist"'

# status / remove / push safety
st="$(bash "$ORGS" status 2>&1)"
check "status reports the org" 'grep -q "^acme: 0.1.0" <<<"$st"'
check "push without a remote is refused" '! bash "$ORGS" push acme --yes >/dev/null 2>&1'
check "remove refuses an org whose commits exist only here" '! bash "$ORGS" remove acme >/dev/null 2>&1 && [ -d "$A" ]'
bash "$ORGS" remove plc --force >/dev/null 2>&1   # plc deliberately carries the placeholder term
bash "$ORGS" remove acme --force >/dev/null 2>&1
check "remove --force deletes it and cleans the index and blocklist" '[ ! -d "$A" ] && ! grep -q "| acme |" "$H/organizations/INDEX.md" && ! grep -qx acme "$W/state/blocklist"'

echo; echo "$pass passed, $failn failed"
[ "$failn" -eq 0 ]
