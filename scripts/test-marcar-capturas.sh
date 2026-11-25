#!/usr/bin/env bash
# test-marcar-capturas.sh - offline checks for config/hooks/marcar-capturas.sh: after a
# `node pr-screenshots.mjs` it marks every before/after pair of the --out folder, lists what to upload
# and which pairs did not change, and stays silent otherwise. Uses a stub marker (no ImageMagick).
set -uo pipefail
HUB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$HUB/config/hooks/marcar-capturas.sh"
pass=0; failn=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"; else failn=$((failn + 1)); echo "FAIL $1"; fi; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
# Stub: same bytes -> sin-cambios; otherwise writes the .marcado/.completa files like the real one.
cat > "$T/marcar" <<'EOF'
#!/usr/bin/env bash
cmp -s "$1" "$2" && { echo sin-cambios; exit 0; }
for f in "$1" "$2"; do : > "${f%.png}.marcado.png"; : > "${f%.png}.completa.png"; done
echo "recorte 800x260+0+0 1 zonas"
EOF
chmod +x "$T/marcar"
seed() { # seed <dir>: one changed pair, one identical pair, one before without after
  rm -rf "$1"; mkdir -p "$1"
  echo a > "$1/before-cambia.png"; echo b > "$1/after-cambia.png"
  echo c > "$1/before-igual.png"; echo c > "$1/after-igual.png"
  echo d > "$1/before-solo.png"
}
# ran <command> [cwd] [agent_type] -> the hook's additionalContext ("" when it stays silent)
ran() { jq -n --arg c "$1" --arg w "${2:-$T}" --arg a "${3:-}" '{tool_name:"Bash",tool_input:{command:$c},cwd:$w}
  + (if $a == "" then {} else {agent_type:$a} end)' | MARCAR_CAPTURAS="$T/marcar" bash "$HOOK" | jq -r '.hookSpecificOutput.additionalContext // empty'; }

seed "$T/abs"
out="$(ran "node pr-screenshots.mjs --before http://a --after http://b --path / --out $T/abs > $T/s.json")"
check "absolute --out: lists the marked files to upload" '[[ "$out" == *"$T/abs/before-cambia.marcado.png"* && "$out" == *"after-cambia.completa.png"* ]]'
check "absolute --out: identical pair is reported as sin cambios" '[[ "$out" == *"Sin cambios, no van al PR: igual"* ]]'
check "a before without its after is ignored" '[[ "$out" != *before-solo* ]]'
check "raw PNGs are not offered for upload" '[[ "$out" != *"before-cambia.png"* ]]'

seed "$T/rel/shots"
out="$(ran "cd $T/rel && node pr-screenshots.mjs --path / --out shots" /nowhere)"
check "relative --out after cd resolves against the cd" '[[ "$out" == *"$T/rel/shots/after-cambia.marcado.png"* ]]'

seed "$T/pr-screenshots"
out="$(ran "node ~/x/pr-screenshots.mjs --path /")"
check "without --out uses pr-screenshots/ in the session cwd" '[[ "$out" == *"$T/pr-screenshots/before-cambia.marcado.png"* ]]'

check "other commands stay silent" '[ -z "$(ran "ls $T/abs")" ]'
check "--login stays silent" '[ -z "$(ran "node pr-screenshots.mjs --login --url http://a/login")" ]'
check "subagents stay silent" '[ -z "$(ran "node pr-screenshots.mjs --out $T/abs" "$T" worker)" ]'
check "missing --out folder stays silent" '[ -z "$(ran "node pr-screenshots.mjs --out $T/no-existe")" ]'
check "no marker installed stays silent" '[ -z "$(jq -n --arg c "node pr-screenshots.mjs --out $T/abs" "{tool_input:{command:\$c}}" | HOME="$T/vacio" MARCAR_CAPTURAS= bash "$HOOK" | jq -r ".hookSpecificOutput.additionalContext // empty")" ]'
check "settings.base.json wires the hook in PostToolUse (Bash)" 'jq -e ".hooks.PostToolUse[] | select(.matcher == \"Bash\") | .hooks[].command | select(test(\"marcar-capturas.sh\"))" "$HUB/config/settings.base.json" >/dev/null'

echo "$pass ok, $failn failed"
[ "$failn" -eq 0 ]
