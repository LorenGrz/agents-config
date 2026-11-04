#!/usr/bin/env bash
# orgs.sh - manage private organization repos under organizations/ (see organizations/README.md).
#
# Usage: orgs.sh add <name> <git-url>   clone into organizations/<name> and register
#        orgs.sh add <name> --init      create a local org from organizations/_template
#        orgs.sh list | status | pull | index
#        orgs.sh push [<name>] [--yes]  push one org repo (asks first)
#        orgs.sh validate <name|path>   check org.json / POLICIES.md
#        orgs.sh detect <owner|remote>  print the org that matches
#        orgs.sh remove <name> [--force]  refuses a dirty or unpushed repo without --force
#
# State (never in this repo): ~/.config/agents-config/organizations.json (name + remote) and
# ~/.config/agents-config/blocklist (terms from each org.json, used by leak-guard.sh).
set -euo pipefail

HUB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ORGS="$HUB/organizations"
STATE="${AGENTS_CONFIG_STATE_DIR:-$HOME/.config/agents-config}"
REG="$STATE/organizations.json"
BL="$STATE/blocklist"
command -v jq >/dev/null || { echo "Error: jq is required" >&2; exit 1; }
die() { echo "orgs: $*" >&2; exit 1; }

mkdir -p "$STATE"
[ -f "$REG" ] || echo '{"orgs":[]}' > "$REG"

names() { jq -r '.orgs[].name' "$REG"; }
org_dir() { printf '%s/%s' "$ORGS" "$1"; }

resolve() { # resolve <name|path> -> directory
  if [ -d "$1" ] && [ -f "$1/org.json" ]; then (cd "$1" && pwd); elif [ -d "$(org_dir "$1")" ]; then org_dir "$1"; else die "no such org: $1"; fi
}

register() { # register <name> <remote>
  local tmp; tmp="$(mktemp)"
  jq --arg n "$1" --arg r "$2" '.orgs = ([.orgs[] | select(.name != $n)] + [{name:$n, remote:$r}])' "$REG" > "$tmp" && mv "$tmp" "$REG"
}

sync_blocklist() { # rebuild the local blocklist from every registered org
  local n; : > "$BL.tmp"
  for n in $(names); do
    [ -f "$(org_dir "$n")/org.json" ] && jq -r '.blocklist_terms[]?, .name' "$(org_dir "$n")/org.json" >> "$BL.tmp"
  done
  sort -u "$BL.tmp" | sed '/^$/d' > "$BL"; rm -f "$BL.tmp"
}

cmd_index() {
  local n d
  {
    echo "# Organizations (local, not tracked)"
    echo
    echo "If the current repo's GitHub owner or remote matches an org below, read its POLICIES.md summary before working there. If it is ambiguous, ask which org applies. Personal repos have no org."
    echo
    echo "| Org | Recognize by | Policies |"
    echo "|---|---|---|"
    for n in $(names); do
      d="$(org_dir "$n")"; [ -f "$d/org.json" ] || continue
      echo "| $n | $(jq -r '(.match.gh_owners // []) as $o | (.match.remote_patterns // []) as $p | "owners: " + ($o | join(", ")) + (if ($p|length)>0 then "; remote: " + ($p | join(", ")) else "" end)' "$d/org.json") | organizations/$n/POLICIES.md |"
    done
  } > "$ORGS/INDEX.md"
  sync_blocklist
  if ! grep -qs "organizations/INDEX.md" "$HOME/.claude/CLAUDE.md" 2>/dev/null; then
    echo "note: run ./install.sh so ~/.claude/CLAUDE.md imports organizations/INDEX.md" >&2
  fi
}

cmd_validate() {
  local d bad=0; d="$(resolve "$1")"
  chk() { if ! eval "$2"; then echo "orgs: $1" >&2; bad=1; fi; }
  chk "org.json is not valid JSON" 'jq -e . "$d/org.json" >/dev/null 2>&1'
  chk "org.json needs name, version and match" 'jq -e ".name and .version and .match" "$d/org.json" >/dev/null 2>&1'
  chk "org.json match needs gh_owners or remote_patterns" 'jq -e "((.match.gh_owners // []) + (.match.remote_patterns // [])) | length > 0" "$d/org.json" >/dev/null 2>&1'
  chk "POLICIES.md is missing" '[ -f "$d/POLICIES.md" ]'
  chk "POLICIES.md must start with a summary of 15 lines or fewer before the first ## section" '[ -f "$d/POLICIES.md" ] && [ "$(awk "/^## /{exit} END{print NR}" "$d/POLICIES.md")" -le 17 ] || [ "$(grep -c "^## " "$d/POLICIES.md" 2>/dev/null)" -eq 0 ]'
  chk "every skill needs SKILL.md with name and description" 'for s in "$d"/skills/*/; do [ -d "$s" ] || continue; [ -f "$s/SKILL.md" ] && grep -q "^name: " "$s/SKILL.md" && grep -q "^description: " "$s/SKILL.md" || exit 1; done'
  chk "every command needs a description" 'for c in "$d"/commands/*.md; do [ -f "$c" ] || continue; grep -q "^description: " "$c" || exit 1; done'
  chk "a baseline weakening is not allowed: POLICIES.md must not tell agents to skip verification or commit secrets" '! grep -qiE "skip (the )?(tests|verification)|commit (the )?\.env|force.push to (main|dev|master)" "$d/POLICIES.md" 2>/dev/null'
  [ "$bad" -eq 0 ] && echo "orgs: $(jq -r .name "$d/org.json") ok"
  return "$bad"
}

cmd_add() {
  local name="$1" src="${2:-}" d; d="$(org_dir "$name")"
  [ -n "$src" ] || die "usage: orgs.sh add <name> <git-url|--init>"
  case "$name" in *[!a-z0-9-]*|"") die "name must be lowercase letters, digits and dashes" ;; esac
  if [ "$src" = "--init" ]; then
    [ ! -e "$d" ] || die "$d already exists"
    cp -r "$ORGS/_template" "$d"; sed -i "s/\"name\": \"acme\"/\"name\": \"$name\"/" "$d/org.json"
    git -C "$d" init -q -b main; register "$name" ""
    echo "created $d (local only: edit org.json/POLICIES.md, validate, commit, then create its private remote)"
  else
    [ -e "$d" ] && echo "skip clone: $d exists" || git clone -q "$src" "$d"
    register "$name" "$src"
  fi
  cmd_index; echo "registered $name"
}

cmd_status() {
  local n d ver ext cur dirty ahead
  cur="$(cat "$HUB/VERSION" 2>/dev/null || echo 0)"
  echo "base: $cur ($(git -C "$HUB" rev-parse --short HEAD 2>/dev/null || echo unknown))"
  for n in $(names); do
    d="$(org_dir "$n")"; [ -d "$d" ] || { echo "$n: missing ($d)"; continue; }
    ver="$(jq -r .version "$d/org.json")"; ext="$(jq -r '.extends // empty' "$d/org.json" | sed 's/.*>=//')"
    dirty=""; [ -n "$(git -C "$d" status --porcelain 2>/dev/null)" ] && dirty=" dirty"
    ahead=""; if git -C "$d" rev-parse '@{u}' >/dev/null 2>&1; then ahead=" ahead $(git -C "$d" rev-list --count '@{u}..HEAD') behind $(git -C "$d" rev-list --count 'HEAD..@{u}')"; else ahead=" no upstream"; fi
    warn=""; [ -n "$ext" ] && [ "$(printf '%s\n%s\n' "$ext" "$cur" | sort -V | head -1)" != "$ext" ] && warn=" WARNING needs base >= $ext"
    echo "$n: $ver$dirty$ahead$warn"
  done
}

cmd_pull() { local n; for n in $(names); do [ -d "$(org_dir "$n")/.git" ] && git -C "$(org_dir "$n")" pull --ff-only 2>&1 | sed "s/^/$n: /" || true; done; cmd_index; }

cmd_push() {
  local n="" yes=0 a; for a in "$@"; do [ "$a" = "--yes" ] && yes=1 || n="$a"; done
  [ -n "$n" ] || die "usage: orgs.sh push <name> [--yes]"
  local d; d="$(org_dir "$n")"; [ -d "$d/.git" ] || die "$n is not a git repo"
  git -C "$d" remote get-url origin >/dev/null 2>&1 || die "$n has no remote yet (create the private repo first)"
  if [ "$yes" -ne 1 ]; then
    printf 'Push %s to %s? [y/N] ' "$n" "$(git -C "$d" remote get-url origin)" >&2; read -r a
    [ "$a" = "y" ] || { echo "aborted"; return 1; }
  fi
  git -C "$d" push
}

cmd_detect() { # detect <owner|remote-url>
  local n d
  for n in $(names); do
    d="$(org_dir "$n")"; [ -f "$d/org.json" ] || continue
    if jq -e --arg s "$1" '((.match.gh_owners // []) | any(. as $o | ($s | ascii_downcase) == ($o | ascii_downcase) or ($s | ascii_downcase | test("github\\.com[:/]" + ($o | ascii_downcase) + "/")))) or ((.match.remote_patterns // []) | any(. as $p | $s | test($p)))' "$d/org.json" >/dev/null; then echo "$n"; fi
  done
}

cmd_remove() {
  local n="$1" force="${2:-}" d; d="$(org_dir "$n")"
  if [ -d "$d/.git" ] && [ "$force" != "--force" ]; then
    [ -z "$(git -C "$d" status --porcelain)" ] || die "$n has uncommitted changes (use --force)"
    if git -C "$d" rev-parse '@{u}' >/dev/null 2>&1; then
      [ "$(git -C "$d" rev-list --count '@{u}..HEAD')" -eq 0 ] || die "$n has unpushed commits (use --force)"
    else die "$n has no upstream, its commits exist only here (use --force)"; fi
  fi
  rm -rf "$d"; local tmp; tmp="$(mktemp)"; jq --arg n "$n" '.orgs |= map(select(.name != $n))' "$REG" > "$tmp" && mv "$tmp" "$REG"
  cmd_index; echo "removed $n"
}

case "${1:-}" in
  add) [ $# -ge 3 ] || die "usage: orgs.sh add <name> <git-url|--init>"; cmd_add "$2" "$3" ;;
  list) names ;;
  status) cmd_status ;;
  pull) cmd_pull ;;
  push) shift; cmd_push "$@" ;;
  index) cmd_index ;;
  validate) [ $# -eq 2 ] || die "usage: orgs.sh validate <name|path>"; cmd_validate "$2" ;;
  detect) [ $# -eq 2 ] || die "usage: orgs.sh detect <owner|remote>"; cmd_detect "$2" ;;
  remove) [ $# -ge 2 ] || die "usage: orgs.sh remove <name> [--force]"; cmd_remove "$2" "${3:-}" ;;
  *) sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
