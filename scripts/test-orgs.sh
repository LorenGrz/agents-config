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
jq '.match.gh_owners = ["acme-inc"]' "$A/org.json" > "$W/a.json" && mv "$W/a.json" "$A/org.json"   # the template ships no owner on purpose
bash "$ORGS" index >/dev/null 2>&1
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
bash "$H/skills/devops/project-init/scripts/init.sh" --manifest "$W/init.json" --dir "$Q" --owner acme-inc >"$W/init.log" 2>&1
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

# --- replaced skills are also rewritten inside installed skills; a personal project has no org terms
mkorg rw; mkdir -p "$H/organizations/rw/skills/rw-hex"; printf -- '---\nname: rw-hex\ndescription: x\n---\n' > "$H/organizations/rw/skills/rw-hex/SKILL.md"
setj rw '.replaces = {"hexagonal-architecture":"rw-hex"}'
P7="$W/rw"; mkp "$P7"; man "$W/rw.json" '["java-spring"]' '[{"key":"backend-style","value":"hexagonal"}]'
bash "$PA" --stack java-spring --manifest "$W/rw.json" --org rw --dir "$P7" >/dev/null 2>&1
check "mentions of a replaced skill are rewritten inside installed skills" 'grep -q "\`rw-hex\`" "$P7/.claude/skills/new-bounded-context/SKILL.md" && ! grep -q "\`hexagonal-architecture\`" "$P7/.claude/skills/new-bounded-context/SKILL.md"'
P8="$W/personal"; mkp "$P8"
bash "$PA" --stack java-spring --manifest "$W/rw.json" --dir "$P8" >/dev/null 2>&1
check "a project without an org carries no org terms" '! grep -rqiE "acme|rw-hex|evil" "$P8"'

# --- re-review regressions
P9="$W/lifecycle"; mkp "$P9"; man "$W/lc.json" '["react-vite"]' '[{"key":"frontend-style","value":"feature-sliced"}]'
bash "$PA" --stack react-vite --manifest "$W/lc.json" --dir "$P9" >/dev/null 2>&1
bash "$PA" --stack react-vite --manifest "$W/lc.json" --org acme --dir "$P9" >"$W/lc2.log" 2>&1
check "adding an org does not delete freshly installed skills" '[ -d "$P9/.claude/skills/run-app" ] && ! grep -q "removed stale skill: run-app" "$W/lc2.log" && [ -d "$P9/.claude/skills/acme-ui-builder" ]'
check "skills.lock names are never glued together" '! jq -e "[.installed.skills[], .installed.commands[]] | any(test(\"run-app[a-z]\"))" "$P9/.agents/skills.lock" >/dev/null 2>&1'
bash "$PA" --stack react-vite --manifest "$W/lc.json" --dir "$P9" >/dev/null 2>&1
check "dropping the org removes its skills and policies and restores the base ones" '[ ! -d "$P9/.claude/skills/acme-ui-builder" ] && [ ! -f "$P9/.agents/POLICIES.md" ] && [ -d "$P9/.claude/skills/ui-builder" ] && [ -d "$P9/.claude/skills/run-app" ]'

# a same-named directory in the cwd must not be validated instead of the hub org
mkdir -p "$W/cwd"; cp -r "$H/organizations/acme" "$W/cwd/badpol"; jq '.name = "badpol"' "$W/cwd/badpol/org.json" > "$W/cwd/t.json" && mv "$W/cwd/t.json" "$W/cwd/badpol/org.json"
mkp "$W/n2"
(cd "$W/cwd" && bash "$PA" --stack react-vite --org badpol --dir "$W/n2" >/dev/null 2>&1); rc=$?
check "the org is validated from organizations/, not from a lookalike in the cwd" '[ $rc -ne 0 ] && [ ! -d "$W/n2/.claude/commands" ]'

# org.json shape checks
mkorg shp; cp "$H/organizations/shp/org.json" "$W/shp.bak"
shape() { cp "$W/shp.bak" "$H/organizations/shp/org.json"; setj shp "$1"; ! bash "$ORGS" validate shp >/dev/null 2>&1; }
check "critical stacks must be an array" 'shape ".critical = [{\"skill\":\"x\",\"stacks\":\"python\"}]"'
check "index use must be a string" 'shape ".index = [{\"when\":\"w\",\"use\":5}]"'
check "index when must not contain |" 'shape ".index = [{\"when\":\"a|b\",\"use\":\"x\"}]"'
check "asset stacks must be an array" 'shape ".assets = {\"skills/x\":{\"stacks\":\"python\"}}"'
check "replaces values must be strings" 'shape ".replaces = {\"ui-builder\":{\"a\":1}}"'
check "replaces targets must exist in the org" 'shape ".replaces = {\"ui-builder\":\"missing-skill\"}"'
mkorg nm; setj nm '.name = "other"'
check "org.json name must match the directory" '! bash "$ORGS" validate nm >/dev/null 2>&1'
check "the template has no placeholder owner either" '[ "$(jq ".match.gh_owners | length" "$H/organizations/_template/org.json")" -eq 0 ]'
check "a non-ascii org name is rejected" '! bash "$ORGS" add "é" --init >/dev/null 2>&1'
out="$(bash "$H/install.sh" --org foo 2>&1)"; rc=$?
check "install.sh --org without a url explains itself" '[ $rc -ne 0 ] && grep -q -- "--org needs" <<<"$out" && ! grep -q "unbound" <<<"$out"'

# org / owner mismatch
Q2="$W/app2"; mkdir -p "$Q2"
bash "$H/skills/devops/project-init/scripts/init.sh" --manifest "$W/init.json" --dir "$Q2" --owner someone-else </dev/null >"$W/mm.log" 2>&1; rc=$?
check "init.sh refuses an org/owner mismatch when non-interactive" '[ $rc -ne 0 ] && [ ! -f "$Q2/.agents/POLICIES.md" ]'
Q3="$W/app3"; mkdir -p "$Q3"
bash "$H/skills/devops/project-init/scripts/init.sh" --manifest "$W/init.json" --dir "$Q3" --owner someone-else --allow-org-mismatch </dev/null >/dev/null 2>&1
check "--allow-org-mismatch proceeds" '[ -f "$Q3/.agents/POLICIES.md" ]'

# workspace mode with an org: config lives in the org repo, the workspace folder gets symlinks
WSD="$W/wsorg"; mkdir -p "$WSD/front" "$WSD/back"; git -C "$WSD/front" init -q; git -C "$WSD/back" init -q
WSA=(--dir "$WSD" --name prod --org acme --repo front:frontend:react-vite --repo back:backend:java-spring)
bash "$H/skills/devops/project-init/scripts/workspace.sh" "${WSA[@]}" >/dev/null 2>&1
check "workspace --org writes the config inside the org repo" '[ -f "$A/workspaces/prod/AGENTS.md" ] && [ -f "$A/workspaces/prod/.agents/POLICIES.md" ] && [ -d "$A/workspaces/prod/.claude/skills/acme-ui-builder" ]'
check "workspace --org installs no pack commands" '[ ! -d "$A/workspaces/prod/.claude/commands" ] || [ -z "$(ls "$A/workspaces/prod/.claude/commands" 2>/dev/null)" ]'
check "workspace --org links the folder to the org copy" '[ "$(readlink "$WSD/AGENTS.md")" = "$A/workspaces/prod/AGENTS.md" ] && [ -L "$WSD/.claude" ] && [ -L "$WSD/.agents" ]'
check "workspace --org mentions the policies and does not git init the folder" 'grep -q "\.agents/POLICIES.md" "$A/workspaces/prod/AGENTS.md" && [ ! -d "$WSD/.git" ]'
bash "$H/skills/devops/project-init/scripts/workspace.sh" "${WSA[@]}" >/dev/null 2>&1
check "workspace --org re-run is safe and the org still validates" 'bash "$ORGS" validate acme >/dev/null 2>&1'
check "workspace --org refuses an org that is not installed" '! bash "$H/skills/devops/project-init/scripts/workspace.sh" --dir "$WSD" --name prod --org nope --repo front:frontend:- --repo back:backend:- >/dev/null 2>&1'

# products: one folder per product with its own skills/, commands/ and POLICIES.md
mkorg prd; PD="$H/organizations/prd"
for p in alpha beta; do
  mkdir -p "$PD/$p/skills/prd-$p" "$PD/$p/skills/prd-common"; cp "$PD/POLICIES.md" "$PD/$p/POLICIES.md"; echo "product $p" >> "$PD/$p/POLICIES.md"
  printf -- '---\nname: prd-%s\ndescription: x\n---\n' "$p" > "$PD/$p/skills/prd-$p/SKILL.md"
  printf -- '---\nname: prd-common\ndescription: x\n---\n' > "$PD/$p/skills/prd-common/SKILL.md"
done
setj prd '.products = {"alpha":{"remote_patterns":["prd-inc/alpha-"]},"beta":{"remote_patterns":["prd-inc/beta-"]}} | .replaces = {"ui-builder":"prd-alpha"}'
check "an org with products validates (replaces target in one product)" 'bash "$ORGS" validate prd >/dev/null 2>&1'
cp "$PD/org.json" "$W/prd.bak"
setj prd '.products.gamma = {"remote_patterns":["x"]}'
check "a product without its folder does not validate" '! bash "$ORGS" validate prd >/dev/null 2>&1'
cp "$W/prd.bak" "$PD/org.json"; setj prd '.products.alpha.remote_patterns = "x"'
check "product remote_patterns must be an array" '! bash "$ORGS" validate prd >/dev/null 2>&1'
cp "$W/prd.bak" "$PD/org.json"
PP="$W/prd-a"; mkp "$PP"
bash "$PA" --stack react-vite --org prd --product alpha --dir "$PP" >/dev/null 2>&1
check "--product installs that product's skills and POLICIES only" '[ -d "$PP/.claude/skills/prd-alpha" ] && [ -d "$PP/.claude/skills/prd-common" ] && [ ! -d "$PP/.claude/skills/prd-beta" ] && grep -q "product alpha" "$PP/.agents/POLICIES.md"'
PB="$W/prd-b"; mkp "$PB"; git -C "$PB" init -q; git -C "$PB" remote add origin https://github.com/prd-inc/beta-api.git
bash "$PA" --stack react-vite --org prd --dir "$PB" >/dev/null 2>&1
check "the product comes from the project's origin" '[ -d "$PB/.claude/skills/prd-beta" ] && [ ! -d "$PB/.claude/skills/prd-alpha" ]'
PW="$W/prd-ws"; mkdir -p "$PW/one"; git -C "$PW/one" init -q; git -C "$PW/one" remote add origin https://github.com/prd-inc/alpha-web.git
bash "$PA" --no-packs --org prd --dir "$PW" >/dev/null 2>&1
check "a workspace folder gets the product of its child repos" '[ -d "$PW/.claude/skills/prd-alpha" ]'
PN="$W/prd-none"; mkp "$PN"
check "no product match fails closed" '! bash "$PA" --stack react-vite --org prd --dir "$PN" >/dev/null 2>&1 && [ ! -d "$PN/.claude/skills/prd-common" ]'
check "--product on an org without products is an error" '! bash "$PA" --stack react-vite --org rw --product alpha --dir "$PN" >/dev/null 2>&1'

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
