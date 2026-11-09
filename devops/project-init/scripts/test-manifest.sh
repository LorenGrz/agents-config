#!/usr/bin/env bash
# test-manifest.sh - offline checks for manifest.sh and init.sh --manifest (no network, no GitHub).
# Usage: test-manifest.sh
set -uo pipefail

SD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
pass=0; failn=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
bad() { failn=$((failn + 1)); echo "FAIL $1"; }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }
# rejects <manifest> <text>: validate must fail and mention <text> (capture first: grep -q + pipefail = SIGPIPE).
rejects() { local out; out="$(bash "$SD/manifest.sh" validate "$1" 2>&1)" && return 1; grep -q "$2" <<<"$out"; }

# Fixture: a complete manifest for a backend stack (java-spring is filtered out of --with).
base='{
  "version": 1, "name": "shop-api", "org": null,
  "stacks": ["node-ts", "java-spring"], "extras": ["aws"],
  "decisions": [
    {"key":"backend-style","title":"Backend architecture","value":"hexagonal","why":"Keep the domain free of the framework.","alternatives":["modular monolith: weaker boundaries"]},
    {"key":"data","value":"postgres + flyway"},
    {"key":"testing","value":"unit + api e2e"},
    {"key":"deploy","value":"none"},
    {"key":"sdd","value":"required","source":"org-policy"}
  ],
  "pending": [{"key":"auth","title":"Auth strategy","note":"waiting on the client"}]
}'
echo "$base" > "$W/ok.json"

check "valid manifest passes" 'bash "$SD/manifest.sh" validate "$W/ok.json" >/dev/null 2>&1'

jq 'del(.pending)' "$W/ok.json" > "$W/no-auth.json"
check "missing auth is rejected" 'rejects "$W/no-auth.json" "missing decision or pending: auth"'

jq '.decisions |= map(select(.key != "backend-style"))' "$W/ok.json" > "$W/no-be.json"
check "backend stack without backend-style is rejected" 'rejects "$W/no-be.json" "backend-style"'

jq '.pending += [{"key":"data"}]' "$W/ok.json" > "$W/dup.json"
check "duplicate key is rejected" 'rejects "$W/dup.json" "duplicate key: data"'

# apply: ADRs, project.json, pending section, idempotency
P="$W/proj"; mkdir -p "$P/.agents" "$P/docs/decisions"
printf '# ctx\n\n## Repo facts\n\n- Owner: x\n' > "$P/.agents/CONTEXT.md"
touch "$P/docs/decisions/0000-template.md" "$P/docs/decisions/0001-record-architecture-decisions.md"
bash "$SD/manifest.sh" apply "$W/ok.json" "$P" >/dev/null
check "apply writes project.json" '[ -f "$P/.agents/project.json" ]'
check "apply writes one ADR per decision, numbered from 0002" '[ "$(ls "$P"/docs/decisions | grep -cE "^000[2-6]-")" -eq 5 ] && [ -f "$P/docs/decisions/0002-backend-style.md" ]'
check "ADR records decision, why and alternatives" 'grep -q "hexagonal. Keep the domain" "$P/docs/decisions/0002-backend-style.md" && grep -q "modular monolith" "$P/docs/decisions/0002-backend-style.md"'
check "org-policy source is recorded in the ADR" 'grep -q "policy of organization" "$P/docs/decisions/0006-sdd.md"'
check "pending decisions land before Repo facts" '[ "$(grep -n "^## Pending decisions" "$P/.agents/CONTEXT.md" | cut -d: -f1)" -lt "$(grep -n "^## Repo facts" "$P/.agents/CONTEXT.md" | cut -d: -f1)" ] && grep -q "^- auth:" "$P/.agents/CONTEXT.md"'
before="$(find "$P" -type f -exec sha1sum {} + | sort)"
bash "$SD/manifest.sh" apply "$W/ok.json" "$P" >/dev/null
check "second apply changes nothing" '[ "$before" = "$(find "$P" -type f -exec sha1sum {} + | sort)" ]'

# init.sh --manifest (node-ts, no --install: nothing is downloaded)
Q="$W/app"; mkdir -p "$Q"
bash "$SD/init.sh" --manifest "$W/ok.json" --dir "$Q" --owner e2e-owner >"$W/init.log" 2>&1
check "init.sh --manifest takes name and stack from the manifest" '[ -f "$Q/AGENTS.md" ] && grep -q "shop-api" "$Q/.agents/CONTEXT.md"'
check "init.sh --manifest writes project.json, ADRs and pending decisions" '[ -f "$Q/.agents/project.json" ] && [ -f "$Q/docs/decisions/0002-backend-style.md" ] && grep -q "^## Pending decisions" "$Q/.agents/CONTEXT.md"'
check "extras and known extra stacks reach project-agents" 'ls "$Q/.claude/skills" | grep -q "sam-deploy" && [ -f "$Q/.claude/rules/java.md" ]'
jq '.stacks = ["node-ts","zig"]' "$W/ok.json" > "$W/zig.json"; Z="$W/zig"; mkdir -p "$Z"
bash "$SD/init.sh" --manifest "$W/zig.json" --dir "$Z" --owner e2e-owner >"$W/zig.log" 2>&1
check "unknown extra stacks are filtered out" '[ -f "$Z/AGENTS.md" ] && ! grep -q "unknown stack" "$W/zig.log"'
check "JVM stack needs the generated project first" 'out="$(bash "$SD/init.sh" --stack java-spring --name x --dir "$W/j" --owner o 2>&1)"; grep -q "generate the project first" <<<"$out"'

# review regressions: enums, keys and special characters in names
jq '.decisions |= map(if .key == "backend-style" then .value = "hexagonal + DDD" else . end)' "$W/ok.json" > "$W/enum.json"
check "free-text backend-style is rejected (enum)" 'rejects "$W/enum.json" "backend-style must be one of"'
jq '.stacks = ["react-vite"] | .decisions += [{"key":"frontend-style","value":"feature sliced"}]' "$W/ok.json" > "$W/enum2.json"
check "free-text frontend-style is rejected (enum)" 'rejects "$W/enum2.json" "frontend-style must be one of"'
jq '.decisions += [{"key":"../x","value":"v"}]' "$W/ok.json" > "$W/key.json"
check "a decision key with path characters is rejected" 'rejects "$W/key.json" "invalid key"'
N="$W/special"; mkdir -p "$N"
bash "$SD/init.sh" --stack node-ts --name 'A&B|c/d' --dir "$N" --owner 'o&w|n' >"$W/sp.log" 2>&1
check "names with & | / are substituted literally" 'grep -q "A&B|c/d" "$N/AGENTS.md" && grep -q "o&w|n" "$N/.agents/CONTEXT.md"'

# --- sdd modes change the generated workflow
sddm() { jq --arg v "$1" '.stacks = ["node-ts"] | .decisions |= map(if .key == "sdd" then .value = $v else . end)' "$W/ok.json" > "$W/sdd-$1.json"; }
jq '.decisions |= map(if .key == "sdd" then .value = "none" else . end)' "$W/ok.json" > "$W/sdd-bad.json"
check "sdd outside required|light|off is rejected" 'rejects "$W/sdd-bad.json" "sdd must be one of"'
for mode in required light off; do
  sddm $mode; D="$W/sdd-app-$mode"; mkdir -p "$D"
  bash "$SD/init.sh" --manifest "$W/sdd-$mode.json" --dir "$D" --owner o >"$W/sdd-$mode.log" 2>&1
done
check "sdd=required keeps the spec-driven template text" 'grep -q "^2\. Non-trivial" "$W/sdd-app-required/AGENTS.md" && grep -q "spec-driven, with superpowers" "$W/sdd-app-required/AGENTS.md"'
check "sdd=light limits specs to big work" 'grep -q "Small changes skip the spec" "$W/sdd-app-light/AGENTS.md" && grep -q "specs for big work" "$W/sdd-app-light/AGENTS.md" && ! grep -q "^2\. Non-trivial" "$W/sdd-app-light/AGENTS.md"'
check "sdd=off drops the spec requirement" 'grep -q "not required in this project" "$W/sdd-app-off/AGENTS.md" && grep -q "issue-driven" "$W/sdd-app-off/AGENTS.md"'
check "the sdd ADR is still written" 'ls "$W/sdd-app-off/docs/decisions" | grep -q "sdd"'
before="$(sha1sum "$W/sdd-app-light/AGENTS.md")"
bash "$SD/init.sh" --manifest "$W/sdd-light.json" --dir "$W/sdd-app-light" --owner o >/dev/null 2>&1
check "a second run leaves the adjusted AGENTS.md alone" '[ "$before" = "$(sha1sum "$W/sdd-app-light/AGENTS.md")" ]'

# --- AGENTS.md is the single source: no CLAUDE.md by default (init), optional shim, adopt never touches one
check "fresh init has no CLAUDE.md and AGENTS.md carries both baseline markers" '[ ! -e "$Q/CLAUDE.md" ] && grep -q "<!-- baseline:start -->" "$Q/AGENTS.md" && grep -q "<!-- baseline:end -->" "$Q/AGENTS.md" && grep -q "^## Critical rules" "$Q/AGENTS.md"'
S="$W/shim"; mkdir -p "$S"
bash "$SD/init.sh" --stack node-ts --name shim --dir "$S" --owner o --claude-shim >"$W/shim.log" 2>&1
check "init.sh --claude-shim writes CLAUDE.md as the single line @AGENTS.md" '[ "$(cat "$S/CLAUDE.md")" = "@AGENTS.md" ]'

mkrepo() { # <dir>: a minimal git repo for adopt.sh
  mkdir -p "$1" && git -C "$1" init -q -b main && git -C "$1" config user.name t && git -C "$1" config user.email t@t.invalid
  echo "# repo" > "$1/README.md"; git -C "$1" add -A && git -C "$1" commit -q -m init
}
A="$W/adopt-a"; mkrepo "$A"; printf '# AGENTS.md\n\nmine\n' > "$A/AGENTS.md"
bash "$SD/adopt.sh" --dir "$A" >"$W/adopt-a.log" 2>&1
check "adopt appends the Critical rules block once to an AGENTS.md without markers" '[ "$(grep -c "baseline:start" "$A/AGENTS.md")" -eq 1 ] && [ "$(grep -c "baseline:end" "$A/AGENTS.md")" -eq 1 ] && head -n 3 "$A/AGENTS.md" | grep -q "^mine$"'
check "adopt creates no CLAUDE.md without --claude-shim" '[ ! -e "$A/CLAUDE.md" ]'
before="$(find "$A" -path "$A/.git" -prune -o -type f -exec sha1sum {} + | sort)"
bash "$SD/adopt.sh" --dir "$A" >"$W/adopt-a2.log" 2>&1
check "a second adopt run changes nothing" '[ "$before" = "$(find "$A" -path "$A/.git" -prune -o -type f -exec sha1sum {} + | sort)" ]'

B="$W/adopt-b"; mkrepo "$B"
bash "$SD/adopt.sh" --dir "$B" --claude-shim >"$W/adopt-b.log" 2>&1
check "adopt --claude-shim creates CLAUDE.md == @AGENTS.md; fresh AGENTS.md has the markers" '[ "$(cat "$B/CLAUDE.md")" = "@AGENTS.md" ] && grep -q "baseline:start" "$B/AGENTS.md"'
before="$(find "$B" -path "$B/.git" -prune -o -type f -exec sha1sum {} + | sort)"
bash "$SD/adopt.sh" --dir "$B" --claude-shim >"$W/adopt-b2.log" 2>&1
check "adopt on a fresh AGENTS.md is idempotent too" '[ "$before" = "$(find "$B" -path "$B/.git" -prune -o -type f -exec sha1sum {} + | sort)" ]'

C="$W/adopt-c"; mkrepo "$C"; printf '# AGENTS.md\n\nmine\n' > "$C/AGENTS.md"
printf '# Notes\n\nown line one\nown line two\n' > "$C/CLAUDE.md"; c_before="$(sha1sum "$C/CLAUDE.md")"
bash "$SD/adopt.sh" --dir "$C" --claude-shim >"$W/adopt-c.log" 2>&1
check "adopt never modifies an existing CLAUDE.md" '[ "$c_before" = "$(sha1sum "$C/CLAUDE.md")" ]'

echo; echo "$pass passed, $failn failed"
[ "$failn" -eq 0 ]
