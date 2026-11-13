#!/usr/bin/env bash
# project-agents.sh - install the stack-specific skills, rules and MCP servers
# of one or more stacks into a project's .claude/ and .mcp.json.
#
# Usage: project-agents.sh --stack <name>[,<name>...] [--pack <name>[,...]] [--manifest <file>]
#                           [--plugin <name>[,...]] [--no-packs] [--org <name>] [--dir <path>] [--dry-run]
#
# --no-packs skips every pack, even the "always" ones (used for workspace folders, which have no repo flow).
#
# Plugins listed under a stack in config/scopes.json ("plugins") and those named with --plugin are
# enabled for this project only, in <dir>/.claude/settings.json (enabledPlugins, merged, never
# overwritten). --plugin takes a short name (vercel) or a full id (vercel@claude-plugins-official).
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
STACKS="" PACKS="" MANIFEST="" ORG="" PLUGINS="" NO_PACKS=0 DIR="$(pwd)" DRY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --stack) STACKS="$2"; shift 2 ;;
    --pack) PACKS="$2"; shift 2 ;;
    --plugin) PLUGINS="$2"; shift 2 ;;
    --no-packs) NO_PACKS=1; shift ;;
    --manifest) MANIFEST="$2"; shift 2 ;;
    --org) ORG="$2"; shift 2 ;;
    --dir) DIR="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done
[ -n "$STACKS$PACKS$MANIFEST$ORG$PLUGINS" ] || { echo "Error: --stack, --pack, --manifest or --plugin is required" >&2; exit 1; }
command -v jq >/dev/null || { echo "Error: jq is required" >&2; exit 1; }

run() { if [ "$DRY" -eq 1 ]; then echo "  [dry-run] $*"; else "$@"; fi; }
die() { echo "Error: $*" >&2; exit 1; }
valid_name() { local LC_ALL=C; [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]]; }
valid_file() { local LC_ALL=C; [[ "$1" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; }
# literal (non-regex) replacement of every occurrence of $1 by $2 in stdin
replace_literal() { F="$1" T="$2" awk '{ out = ""; line = $0; f = ENVIRON["F"]; t = ENVIRON["T"]
  while ((i = index(line, f)) > 0) { out = out substr(line, 1, i - 1) t; line = substr(line, i + length(f)) } print out line }'; }
PLUGIN_IDS=""
INST_S="" INST_C="" STACK_S=""   # skills/commands installed from packs and the org (tracked in skills.lock); stack skills
rec_s() { INST_S+="$1"$'\n'; }
rec_c() { INST_C+="$1"$'\n'; }
# $(...) strips the trailing newline, so put one back or the next rec_* glues two names together
unrec_s() { INST_S="$(grep -vxF -- "$1" <<<"$INST_S" || true)"$'\n'; }
unrec_c() { INST_C="$(grep -vxF -- "$1" <<<"$INST_C" || true)"$'\n'; }
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
  bash "$HUB/scripts/orgs.sh" validate "$OD" >/dev/null || die "organization '$ORG' does not validate (scripts/orgs.sh validate $ORG)"
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
  d="$(find "$HUB/skills" -mindepth 2 -maxdepth 2 -name "$name" \( -type d -o -type l \) | head -1)"
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
    STACK_S+="$skill"$'\n'
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

  while IFS= read -r pl; do
    [ -n "$pl" ] && PLUGIN_IDS+="$pl"$'\n'
  done < <(jq -r --arg s "$stack" '.stacks[$s].plugins[]?' "$SCOPES")
done

# ---------------------------------------------------------------- plugins (per project)
# Plugins are off globally (config/settings.base.json) when they only make sense for some stacks;
# turn them on here, in the project's own .claude/settings.json.
BASE_SETTINGS="$HUB/config/settings.base.json"
resolve_plugin() { # short name or full id -> full id (from settings.base.json), or the input if it has an @
  case "$1" in
    *@*) printf '%s' "$1" ;;
    *) jq -r --arg n "$1" '.enabledPlugins // {} | keys[] | select(startswith($n + "@"))' "$BASE_SETTINGS" 2>/dev/null | head -n 1 ;;
  esac
}
for _p in ${PLUGINS//,/ }; do
  _id="$(resolve_plugin "$_p")"
  [ -n "$_id" ] || die "unknown plugin '$_p' (not in config/settings.base.json; pass the full name@marketplace id)"
  PLUGIN_IDS+="$_id"$'\n'
done
PLUGIN_JSON="$(printf '%s' "$PLUGIN_IDS" | awk 'NF && !seen[$0]++' | jq -R . | jq -s .)"
if [ "$(jq 'length' <<<"$PLUGIN_JSON")" -gt 0 ]; then
  echo "plugins: .claude/settings.json enabledPlugins <- $(jq -r 'join(", ")' <<<"$PLUGIN_JSON")"
  if [ "$DRY" -eq 0 ]; then
    mkdir -p "$DIR/.claude"
    cur='{}'
    [ -f "$DIR/.claude/settings.json" ] && cur="$(cat "$DIR/.claude/settings.json")"
    jq --argjson ids "$PLUGIN_JSON" '.enabledPlugins = ((.enabledPlugins // {}) + ($ids | map({(.): true}) | add))' <<<"$cur" >"$DIR/.claude/settings.json.tmp"
    mv "$DIR/.claude/settings.json.tmp" "$DIR/.claude/settings.json"
  fi
fi


# ---------------------------------------------------------------- packs
# select_packs: "always" packs, packs named with --pack, and packs whose "when" matches the manifest.
MJSON='{}'; [ -n "$MANIFEST" ] && MJSON="$(cat "$MANIFEST")"
select_packs() {
  local d name
  for d in "$HUB"/packs/*/; do
    [ -f "$d/pack.json" ] || continue
    name="$(basename "$d")"
    if jq -e '.always == true' "$d/pack.json" >/dev/null; then echo "$name"; continue; fi
    if [ -n "$PACKS" ] && grep -qxF "$name" < <(tr ',' '\n' <<<"$PACKS"); then echo "$name"; continue; fi
    # stacks come from --stack and the manifest; decisions only from the manifest
    if jq -e --argjson m "$MJSON" --arg ls "$STACKS" '
        (.when // null) as $w
        | $w != null
        and (($w.stacks // null) == null or any($w.stacks[]; . as $s | (($ls | split(",")) + ($m.stacks // [])) | index($s) != null))
        and (($w.decisions // {}) | to_entries | all(.[]; . as $e | any($m.decisions[]?; .key == $e.key and .value == $e.value)))
      ' "$d/pack.json" >/dev/null; then echo "$name"; fi
  done
}

if [ "$NO_PACKS" -eq 1 ]; then SELECTED=(); else mapfile -t SELECTED < <(select_packs | sort -u); fi
# an architecture decision with no matching pack is not an error, but say it (free-text values never match)
if [ -n "$MANIFEST" ]; then
  for _k in backend-style frontend-style; do
    _v="$(jq -r --arg k "$_k" '[.decisions[]? | select(.key == $k) | .value][0] // empty' "$MANIFEST")"
    [ -n "$_v" ] || continue
    _hit=0
    for _p in "${SELECTED[@]}"; do jq -e --arg k "$_k" --arg v "$_v" '.when.decisions[$k] == $v' "$HUB/packs/$_p/pack.json" >/dev/null 2>&1 && _hit=1; done
    [ "$_hit" = 1 ] || echo "note: no pack matches $_k=$_v for these stacks (packs/*/pack.json)" >&2
  done
fi
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
    rec_s "$(basename "$sk")"
  done
  for cmd in "$src"/commands/*.md; do
    [ -f "$cmd" ] || continue
    echo "command: .claude/commands/$(basename "$cmd")"
    run mkdir -p "$DIR/.claude/commands"
    run cp "$cmd" "$DIR/.claude/commands/$(basename "$cmd")"
    rec_c "$(basename "$cmd")"
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
      /*) run rm -f "$DIR/.claude/commands/${from#/}.md"; unrec_c "${from#/}.md" ;;
      *) run rm -rf "$DIR/.claude/skills/$from"; unrec_s "$from"
         # commands and skills installed so far (packs, stacks) may point at the replaced skill
         if [ "$DRY" -eq 0 ]; then
           for c in "$DIR"/.claude/commands/*.md "$DIR"/.claude/skills/*/SKILL.md; do
             [ -f "$c" ] || continue
             replace_file "$c" ".claude/skills/$from/" ".claude/skills/$to/"
             replace_file "$c" "\`$from\`" "\`$to\`"
           done
         fi ;;
    esac
    ROWS="$(replace_literal "\`$from\`" "\`$to\`" <<<"$ROWS")"
    CRITICAL="$(jq -c --arg f "${from#/}" --arg t "${to#/}" 'map(if .skill == $f then .skill = $t else . end)' <<<"$CRITICAL")"
  done < <(jq -r '(.replaces // {}) | to_entries[] | [.key, .value] | @tsv' "$OJ")
  for sk in "$OD"/skills/*/; do
    [ -f "$sk/SKILL.md" ] || continue
    n="$(basename "$sk")"; wanted "skills/$n" || continue
    echo "skill:   .claude/skills/$n (org)"
    run mkdir -p "$DIR/.claude/skills"; run rm -rf "$DIR/.claude/skills/$n"; run cp -r "${sk%/}" "$DIR/.claude/skills/$n"; rec_s "$n"
  done
  for cmd in "$OD"/commands/*.md; do
    [ -f "$cmd" ] || continue
    wanted "commands/$(basename "$cmd")" || continue
    echo "command: .claude/commands/$(basename "$cmd") (org)"
    run mkdir -p "$DIR/.claude/commands"; run cp "$cmd" "$DIR/.claude/commands/$(basename "$cmd")"; rec_c "$(basename "$cmd")"
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
  # Stale cleanup (only with a manifest, which defines the full pack selection): remove what an earlier
  # run installed from packs or the org and is no longer selected. Only names listed in skills.lock
  # are touched, never a stack skill installed in this run, never anything else in .claude/.
  if [ -n "$MANIFEST" ] && [ -f "$DIR/.agents/skills.lock" ]; then
    while IFS= read -r n; do
      [ -n "$n" ] && valid_name "$n" && ! grep -qxF -- "$n" <<<"$INST_S" && ! grep -qxF -- "$n" <<<"$STACK_S" \
        && { echo "removed stale skill: $n"; rm -rf "$DIR/.claude/skills/$n"; }
    done < <(jq -r '.installed.skills[]?' "$DIR/.agents/skills.lock")
    while IFS= read -r n; do
      [ -n "$n" ] && valid_file "$n" && ! grep -qxF -- "$n" <<<"$INST_C" \
        && { echo "removed stale command: $n"; rm -f "$DIR/.claude/commands/$n"; }
    done < <(jq -r '.installed.commands[]?' "$DIR/.agents/skills.lock")
  fi
  if [ -n "$MANIFEST" ] && [ -z "$ORG" ] && [ -f "$DIR/.agents/skills.lock" ] \
     && [ -n "$(jq -r '.org.name // empty' "$DIR/.agents/skills.lock")" ] && [ -f "$DIR/.agents/POLICIES.md" ]; then
    rm -f "$DIR/.agents/POLICIES.md"; echo "removed stale .agents/POLICIES.md (the project no longer uses an org)"
  fi
  # critical.json: read by the critical-reasoning hook (keywords/paths -> skill hint).
  if [ "$CRITICAL" != "[]" ]; then jq . <<<"$CRITICAL" > "$DIR/.agents/critical.json"; echo "wrote .agents/critical.json"
  elif [ -n "$MANIFEST" ] && [ -f "$DIR/.agents/critical.json" ]; then rm -f "$DIR/.agents/critical.json"; echo "removed stale .agents/critical.json"; fi
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
        --arg org "$ORG" --arg orgver "$ORG_VER" --arg orgsha "$ORG_SHA" --arg is "$INST_S" --arg ic "$INST_C" \
    '{base: {version: $ver, sha: $hub}, stacks: ($stacks | split(",") | map(select(. != ""))), packs: ($packs | split(",") | map(select(. != ""))),
      org: (if $org == "" then null else {name: $org, version: $orgver, sha: $orgsha} end),
      installed: {skills: ($is | split("\n") | map(select(. != "")) | unique), commands: ($ic | split("\n") | map(select(. != "")) | unique)}}' > "$DIR/.agents/skills.lock"
  echo "wrote .agents/skills.lock"
fi
echo "done. Commit .claude/, .agents/ and .mcp.json; MCP servers still need /mcp auth on first use."
