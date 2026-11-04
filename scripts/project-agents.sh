#!/usr/bin/env bash
# project-agents.sh - install the stack-specific skills, rules and MCP servers
# of one or more stacks into a project's .claude/ and .mcp.json.
#
# Usage: project-agents.sh --stack <name>[,<name>...] [--pack <name>[,...]] [--manifest <file>]
#                           [--org <name>] [--dir <path>] [--dry-run]
#
# --org installs an organization (organizations/<name>, see organizations/README.md) on top of the
# packs: its skills and commands (per-stack filters and "replaces" from org.json), its index and
# critical entries, and POLICIES.md as .agents/POLICIES.md. Same-name org files win over packs.
#
# Packs (packs/<name>/: pack.json, skills/, commands/) bundle skills and slash commands by
# architecture. "always" packs are installed with any run; others when the project manifest
# (.agents/project.json schema) matches pack.json "when" (stack AND decisions), or via --pack.
# Packs also write .agents/critical.json (keyword/path -> skill, read by the critical-reasoning
# hook), a keyword table in AGENTS.md (between agents-index markers) and .agents/skills.lock.
#
# Stacks come from config/scopes.json (react-vite, next, nestjs, node-ts, rn,
# aws, python, kotlin, apex, docker, llm, supabase, jira). Everything not listed
# there is global and already installed by install.sh.
#
# Files are copied (not symlinked) so the repo stays portable for CI and other
# clones. Re-running refreshes the managed copies. .mcp.json is merged, never
# overwritten; no secrets are written.
set -euo pipefail

HUB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCOPES="$HUB/config/scopes.json"
STACKS="" PACKS="" MANIFEST="" ORG="" DIR="$(pwd)" DRY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --stack) STACKS="$2"; shift 2 ;;
    --pack) PACKS="$2"; shift 2 ;;
    --manifest) MANIFEST="$2"; shift 2 ;;
    --org) ORG="$2"; shift 2 ;;
    --dir) DIR="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done
[ -n "$STACKS$PACKS$MANIFEST$ORG" ] || { echo "Error: --stack, --pack or --manifest is required" >&2; exit 1; }
command -v jq >/dev/null || { echo "Error: jq is required" >&2; exit 1; }

run() { if [ "$DRY" -eq 1 ]; then echo "  [dry-run] $*"; else "$@"; fi; }
die() { echo "Error: $*" >&2; exit 1; }
valid_name() { [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]]; }
valid_file() { [[ "$1" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; }
# literal (non-regex) replacement of every occurrence of $1 by $2 in stdin
replace_literal() { F="$1" T="$2" awk '{ out = ""; line = $0; f = ENVIRON["F"]; t = ENVIRON["T"]
  while ((i = index(line, f)) > 0) { out = out substr(line, 1, i - 1) t; line = substr(line, i + length(f)) } print out line }'; }
replace_file() { local tmp; tmp="$(mktemp)"; replace_literal "$2" "$3" < "$1" > "$tmp" && cat "$tmp" > "$1"; rm -f "$tmp"; }

# ---------------------------------------------------------------- preflight
# Everything that comes from outside (org name, org.json keys, asset names, symlinks) is checked
# before a single file is touched: a bad org fails closed and installs nothing.
if [ -n "$PACKS" ]; then
  for _p in ${PACKS//,/ }; do valid_name "$_p" || die "invalid pack name '$_p'"; done
fi
if [ -n "$ORG" ]; then
  valid_name "$ORG" || die "invalid organization name '$ORG'"
  OD="$HUB/organizations/$ORG"; OJ="$OD/org.json"
  [ -f "$OJ" ] || die "organization '$ORG' is not installed (scripts/orgs.sh add)"
  bash "$HUB/scripts/orgs.sh" validate "$ORG" >/dev/null || die "organization '$ORG' does not validate (scripts/orgs.sh validate $ORG)"
  [ -z "$(find "$OD" -path "$OD/.git" -prune -o -type l -print -quit)" ] || die "organization '$ORG' contains symlinks"
  while IFS=$'\t' read -r from to; do
    [ -n "$from" ] || continue
    valid_name "${from#/}" && valid_name "${to#/}" || die "invalid replaces entry '$from' -> '$to' in organization '$ORG'"
    # a command ("/name") can only be replaced by a command, a skill by a skill
    [ "${from#/}" = "$from" ] && [ "${to#/}" = "$to" ] || { [ "${from#/}" != "$from" ] && [ "${to#/}" != "$to" ]; } \
      || die "replaces entry '$from' -> '$to' mixes a skill and a command in organization '$ORG'"
  done < <(jq -r '(.replaces // {}) | to_entries[] | [.key, .value] | @tsv' "$OJ")
  for _s in "$OD"/skills/*/; do [ -d "$_s" ] && { valid_name "$(basename "$_s")" || die "invalid skill name '$(basename "$_s")' in '$ORG'"; }; done
  for _c in "$OD"/commands/*.md; do [ -f "$_c" ] && { valid_file "$(basename "$_c")" || die "invalid command name '$(basename "$_c")' in '$ORG'"; }; done
fi

find_skill() {
  local name="$1" d
  d="$(find "$HUB" -mindepth 2 -maxdepth 2 -name "$name" \( -type d -o -type l \) -not -path "$HUB/config/*" -not -path "$HUB/.git/*" | head -1)"
  [ -n "$d" ] || { [ -e "$HUB/$name/SKILL.md" ] && d="$HUB/$name"; }
  printf '%s' "$d"
}

IFS=',' read -r -a LIST <<<"$STACKS"
[ -n "$STACKS" ] || LIST=()
for stack in "${LIST[@]}"; do
  jq -e --arg s "$stack" '.stacks[$s]' "$SCOPES" >/dev/null \
    || { echo "unknown stack '$stack' (see $SCOPES)" >&2; exit 1; }
  echo "== stack: $stack =="

  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    src="$(find_skill "$skill")"
    if [ -z "$src" ]; then echo "skip skill $skill (not found in hub)" >&2; continue; fi
    echo "skill:   .claude/skills/$skill"
    run mkdir -p "$DIR/.claude/skills"
    run rm -rf "$DIR/.claude/skills/$skill"
    run cp -rL "$src" "$DIR/.claude/skills/$skill"
  done < <(jq -r --arg s "$stack" '.stacks[$s].skills[]?' "$SCOPES")

  while IFS= read -r rule; do
    [ -n "$rule" ] || continue
    echo "rule:    .claude/rules/$rule.md"
    run mkdir -p "$DIR/.claude/rules"
    run cp "$HUB/config/rules/$rule.md" "$DIR/.claude/rules/$rule.md"
  done < <(jq -r --arg s "$stack" '.stacks[$s].rules[]?' "$SCOPES")

  mcp="$(jq -c --arg s "$stack" '.stacks[$s].mcp // empty' "$SCOPES")"
  if [ -n "$mcp" ]; then
    echo "mcp:     .mcp.json <- $(jq -r 'keys|join(",")' <<<"$mcp")"
    if [ "$DRY" -eq 0 ]; then
      cur='{"mcpServers":{}}'
      [ -f "$DIR/.mcp.json" ] && cur="$(cat "$DIR/.mcp.json")"
      jq --argjson add "$mcp" '.mcpServers = ((.mcpServers // {}) + $add)' <<<"$cur" >"$DIR/.mcp.json.tmp"
      mv "$DIR/.mcp.json.tmp" "$DIR/.mcp.json"
    fi
  fi
done


# ---------------------------------------------------------------- packs
# select_packs: "always" packs, packs named with --pack, and packs whose "when" matches the manifest.
select_packs() {
  local d name
  for d in "$HUB"/packs/*/; do
    [ -f "$d/pack.json" ] || continue
    name="$(basename "$d")"
    if jq -e '.always == true' "$d/pack.json" >/dev/null; then echo "$name"; continue; fi
    if [ -n "$PACKS" ] && grep -qxF "$name" < <(tr ',' '\n' <<<"$PACKS"); then echo "$name"; continue; fi
    if [ -n "$MANIFEST" ] && jq -e --slurpfile m "$MANIFEST" '
        (.when // null) as $w
        | $w != null
        and (($w.stacks // null) == null or any($w.stacks[]; . as $s | ($m[0].stacks // []) | index($s) != null))
        and (($w.decisions // {}) | to_entries | all(.[]; . as $e | any($m[0].decisions[]?; .key == $e.key and .value == $e.value)))
      ' "$d/pack.json" >/dev/null; then echo "$name"; fi
  done
}

mapfile -t SELECTED < <(select_packs | sort -u)
CRITICAL="[]" ROWS=""
for pack in "${SELECTED[@]}"; do
  src="$HUB/packs/$pack"
  echo "== pack: $pack =="
  for sk in "$src"/skills/*/; do
    [ -f "$sk/SKILL.md" ] || continue
    echo "skill:   .claude/skills/$(basename "$sk")"
    run mkdir -p "$DIR/.claude/skills"
    run rm -rf "$DIR/.claude/skills/$(basename "$sk")"
    run cp -r "${sk%/}" "$DIR/.claude/skills/$(basename "$sk")"
  done
  for cmd in "$src"/commands/*.md; do
    [ -f "$cmd" ] || continue
    echo "command: .claude/commands/$(basename "$cmd")"
    run mkdir -p "$DIR/.claude/commands"
    run cp "$cmd" "$DIR/.claude/commands/$(basename "$cmd")"
  done
  CRITICAL="$(jq -c --slurpfile c "$src/pack.json" '. + ($c[0].critical // [])' <<<"$CRITICAL")"
  ROWS+="$(jq -r '.index[]? | "| \(.when) | `\(.use)` |"' "$src/pack.json")"$'\n'
done

# ---------------------------------------------------------------- organization
ORG_VER="" ORG_SHA=""
if [ -n "$ORG" ]; then
  ORG_VER="$(jq -r .version "$OJ")"; ORG_SHA="$(git -C "$OD" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  echo "== org: $ORG $ORG_VER =="
  ALL=""
  [ "${#LIST[@]}" -gt 0 ] && ALL="$(printf '%s\n' "${LIST[@]}")"
  if [ -n "$MANIFEST" ]; then ALL="$(printf '%s\n%s' "$ALL" "$(jq -r '.stacks[]?' "$MANIFEST")" | sed '/^$/d')"; fi
  wanted() { # wanted <asset-key>: installed unless org.json restricts it to other stacks
    local st; st="$(jq -c --arg k "$1" '.assets[$k].stacks // empty' "$OJ")"
    [ -z "$st" ] && return 0
    jq -e --argjson st "$st" --arg all "$ALL" '$all | split("\n") | any(. as $s | $st | index($s) != null)' <<<null >/dev/null
  }
  asset_key() { case "$1" in /*) echo "commands/${1#/}.md" ;; *) echo "skills/$1" ;; esac; }
  # replaced base items are removed only when the org's replacement applies to this project
  while IFS=$'\t' read -r from to; do
    [ -n "$from" ] || continue
    wanted "$(asset_key "$to")" || continue
    case "$from" in
      /*) run rm -f "$DIR/.claude/commands/${from#/}.md" ;;
      *) run rm -rf "$DIR/.claude/skills/$from"
         # commands installed from packs may point at the replaced skill
         [ "$DRY" -eq 1 ] || for c in "$DIR"/.claude/commands/*.md; do [ -f "$c" ] && replace_file "$c" ".claude/skills/$from/" ".claude/skills/$to/"; done ;;
    esac
    ROWS="$(replace_literal "\`$from\`" "\`$to\`" <<<"$ROWS")"
    CRITICAL="$(jq -c --arg f "${from#/}" --arg t "${to#/}" 'map(if .skill == $f then .skill = $t else . end)' <<<"$CRITICAL")"
  done < <(jq -r '(.replaces // {}) | to_entries[] | [.key, .value] | @tsv' "$OJ")
  for sk in "$OD"/skills/*/; do
    [ -f "$sk/SKILL.md" ] || continue
    n="$(basename "$sk")"; wanted "skills/$n" || continue
    echo "skill:   .claude/skills/$n (org)"
    run mkdir -p "$DIR/.claude/skills"; run rm -rf "$DIR/.claude/skills/$n"; run cp -r "${sk%/}" "$DIR/.claude/skills/$n"
  done
  for cmd in "$OD"/commands/*.md; do
    [ -f "$cmd" ] || continue
    wanted "commands/$(basename "$cmd")" || continue
    echo "command: .claude/commands/$(basename "$cmd") (org)"
    run mkdir -p "$DIR/.claude/commands"; run cp "$cmd" "$DIR/.claude/commands/$(basename "$cmd")"
  done
  # rows may carry "stacks": [...]; without it they apply to every stack of the project
  APPLIES='def applies: select((.stacks // null) == null or any(.stacks[]; . as $s | ($all | split("\n") | index($s)) != null));'
  CRITICAL="$(jq -c --slurpfile o "$OJ" --arg all "$ALL" "$APPLIES"' ($o[0].critical // [] | map(applies) | map(del(.stacks))) + .' <<<"$CRITICAL")"
  ORG_ROWS="$(jq -r --arg all "$ALL" --arg bt '`' "$APPLIES"' .index[]? | applies | "| " + .when + " | " + $bt + .use + $bt + " |"' "$OJ")"
  ROWS="| Org policies ($ORG): workflow, architecture, UI, integrations | \`.agents/POLICIES.md\` |"$'\n'"${ORG_ROWS:+$ORG_ROWS$'\n'}$ROWS"
  if [ "$DRY" -eq 0 ] && [ -f "$OD/POLICIES.md" ]; then mkdir -p "$DIR/.agents"; cp "$OD/POLICIES.md" "$DIR/.agents/POLICIES.md"; echo "wrote .agents/POLICIES.md"; fi
fi

if [ "${#SELECTED[@]}" -gt 0 ] && [ "$DRY" -eq 0 ]; then
  mkdir -p "$DIR/.agents"
  # critical.json: read by the critical-reasoning hook (keywords/paths -> skill hint).
  if [ "$CRITICAL" != "[]" ]; then jq . <<<"$CRITICAL" > "$DIR/.agents/critical.json"; echo "wrote .agents/critical.json"; fi
  # AGENTS.md keyword table: replace the marked block, else insert it before "## How we work", else append.
  if [ -f "$DIR/AGENTS.md" ] && [ -n "${ROWS//[$'\n']/}" ]; then
    [ "$(grep -c . <<<"$ROWS")" -gt 14 ] && echo "warning: more than 14 keyword rows; AGENTS.md table keeps the first 14" >&2
    block="$(printf '<!-- agents-index:start -->\n## Skills and commands by keyword\n\nBefore implementing, read the skill for what you are touching.\n\n| When | Use |\n|---|---|\n%s<!-- agents-index:end -->\n' "$(head -n 14 <<<"$ROWS")"$'\n')"
    tmp="$(mktemp)"
    if grep -q 'agents-index:start' "$DIR/AGENTS.md"; then
      B="$block" awk '/agents-index:start/ {print ENVIRON["B"]; skip=1} !skip {print} /agents-index:end/ {skip=0}' "$DIR/AGENTS.md" > "$tmp"
    elif grep -q '^## How we work' "$DIR/AGENTS.md"; then
      B="$block" awk '/^## How we work/ && !d {print ENVIRON["B"]; print ""; d=1} {print}' "$DIR/AGENTS.md" > "$tmp"
    else
      { cat "$DIR/AGENTS.md"; printf '\n%s\n' "$block"; } > "$tmp"
    fi
    mv "$tmp" "$DIR/AGENTS.md"; echo "updated AGENTS.md keyword table"
  fi
  # skills.lock: what was installed from which hub revision (updates are always explicit).
  jq -n --arg hub "$(git -C "$HUB" rev-parse --short HEAD 2>/dev/null || echo unknown)" --arg ver "$(cat "$HUB/VERSION" 2>/dev/null || echo 0)" \
        --arg packs "$(IFS=,; echo "${SELECTED[*]}")" --arg stacks "$STACKS" \
        --arg org "$ORG" --arg orgver "$ORG_VER" --arg orgsha "$ORG_SHA" \
    '{base: {version: $ver, sha: $hub}, stacks: ($stacks | split(",") | map(select(. != ""))), packs: ($packs | split(",") | map(select(. != ""))),
      org: (if $org == "" then null else {name: $org, version: $orgver, sha: $orgsha} end)}' > "$DIR/.agents/skills.lock"
  echo "wrote .agents/skills.lock"
fi
echo "done. Commit .claude/, .agents/ and .mcp.json; MCP servers still need /mcp auth on first use."
