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
check "extras reach project-agents; unknown stacks are filtered" 'ls "$Q/.claude/skills" | grep -q "sam-deploy" && ! grep -q "unknown stack" "$W/init.log"'
check "init.sh refuses a stack without template" '! bash "$SD/init.sh" --stack java-spring --name x --dir "$W/j" --owner o >/dev/null 2>&1'

echo; echo "$pass passed, $failn failed"
[ "$failn" -eq 0 ]
