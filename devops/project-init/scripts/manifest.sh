#!/usr/bin/env bash
# manifest.sh - validate a project manifest and apply it to a project directory.
#
# Usage: manifest.sh validate <manifest>
#        manifest.sh apply <manifest> <dir>
#
# apply = validate, then write <dir>/.agents/project.json, one ADR per decision in
# <dir>/docs/decisions/ (skipped when an ADR with that key already exists), and a
# "Pending decisions" section in <dir>/.agents/CONTEXT.md. Idempotent.
# Schema and interview: references/interview.md.
set -euo pipefail

BACKEND='["nestjs","java-spring","kotlin-spring","python"]'
FRONTEND='["react-vite","next","rn"]'
ALWAYS='["data","auth","testing","deploy","sdd"]'

command -v jq >/dev/null || { echo "Error: jq is required" >&2; exit 1; }
die() { echo "manifest: $*" >&2; exit 1; }

problems() { # problems <manifest> : one line per problem, none when valid
  jq -e . "$1" >/dev/null 2>&1 || { echo "not valid JSON: $1"; return; }
  jq -r --argjson be "$BACKEND" --argjson fe "$FRONTEND" --argjson always "$ALWAYS" '
    def ks: ([.decisions[]?.key] + [.pending[]?.key]);
    def has_stack($l): any((.stacks // [])[]; . as $s | $l | index($s) != null);
    [
      (if .version != 1 then "version must be 1" else empty end),
      (if (.name // "") == "" then "name is required" else empty end),
      (if ((.stacks // []) | length) == 0 then "stacks must be a non-empty array" else empty end),
      (if .org != null and (.org | type) != "string" then "org must be null or a string" else empty end),
      (.decisions[]? | select((.key // "") == "" or (.value // "") == "") | "decision needs key and value: \(.key // "?")"),
      (.pending[]? | select((.key // "") == "") | "pending item needs a key"),
      (ks | group_by(.)[] | select(length > 1) | "duplicate key: \(.[0])"),
      ($always[] as $k | select((ks | index($k)) == null) | "missing decision or pending: \($k)"),
      (if has_stack($be) and (ks | index("backend-style")) == null then "missing decision or pending: backend-style" else empty end),
      (if has_stack($fe) and (ks | index("frontend-style")) == null then "missing decision or pending: frontend-style" else empty end)
    ] | .[]' "$1"
}

validate() {
  local out; out="$(problems "$1")"
  [ -z "$out" ] || { echo "$out" | sed 's/^/manifest: /' >&2; return 1; }
}

next_adr_number() { # next_adr_number <decisions dir>
  local max
  max="$(ls "$1" 2>/dev/null | grep -oE '^[0-9]{4}' | sort -n | tail -1 || true)"
  [ -n "$max" ] || { echo 2; return; }
  echo $((10#$max + 1))
}

write_adr() { # write_adr <manifest> <decision json> <file> <number>
  local m="$1" d="$2" file="$3" num="$4" org
  org="$(jq -r '.org // empty' "$m")"
  {
    printf '# %s. %s\n\n## Status\n\nAccepted\n\n## Date\n\n%s\n\n' \
      "$(printf '%04d' "$num")" "$(jq -r '.title // .key' <<<"$d")" "$(date +%Y-%m-%d)"
    printf '## Context\n\nDecided in the project-init interview for %s.' "$(jq -r '.name' "$m")"
    if [ "$(jq -r '.source // "user"' <<<"$d")" = "org-policy" ]; then
      printf ' Source: policy of organization %s.' "${org:-unknown}"
    fi
    printf '\n\n## Decision\n\n%s' "$(jq -r '.value' <<<"$d")"
    jq -r 'if .why then ". " + .why else "" end' <<<"$d" | tr -d '\n'
    printf '\n\n## Alternatives considered\n\n'
    if [ "$(jq '(.alternatives // []) | length' <<<"$d")" -gt 0 ]; then
      jq -r '.alternatives[] | "- " + .' <<<"$d"
    else
      echo "- (not recorded)"
    fi
    printf '\n## Consequences\n\n<!-- Fill in: what gets easier or harder, and what to revisit. -->\n'
  } > "$file"
}

apply() { # apply <manifest> <dir>
  local m="$1" dir="$2" cur dest="$2/.agents/project.json" decisions="$2/docs/decisions"
  validate "$m" || exit 1
  mkdir -p "$dir/.agents" "$decisions"

  if [ ! -f "$dest" ] || [ "$(jq -S . "$m")" != "$(jq -S . "$dest")" ]; then
    jq . "$m" > "$dest"; echo "wrote .agents/project.json"
  else
    echo "skip .agents/project.json (same)"
  fi

  local n d key; n="$(next_adr_number "$decisions")"
  while IFS= read -r d; do
    key="$(jq -r '.key' <<<"$d")"
    if compgen -G "$decisions/*-$key.md" >/dev/null; then echo "skip ADR $key (exists)"; continue; fi
    write_adr "$m" "$d" "$decisions/$(printf '%04d' "$n")-$key.md" "$n"
    echo "wrote docs/decisions/$(printf '%04d' "$n")-$key.md"; n=$((n + 1))
  done < <(jq -c '.decisions[]?' "$m")

  cur="$dir/.agents/CONTEXT.md"
  if [ "$(jq '(.pending // []) | length' "$m")" -gt 0 ] && [ -f "$cur" ] && ! grep -q '^## Pending decisions' "$cur"; then
    local section tmp; tmp="$(mktemp)"
    section="$(jq -r '"## Pending decisions\n\n<!-- Ask the user before implementing anything that depends on these. -->\n\n" + ([.pending[] | "- \(.key): \(.title // .key)" + (if .note then " - " + .note else "" end)] | join("\n")) + "\n"' "$m")"
    if grep -q '^## Repo facts' "$cur"; then
      awk -v s="$section" '/^## Repo facts/ && !done { print s; print ""; done=1 } { print }' "$cur" > "$tmp"
    else
      { cat "$cur"; printf '\n%s\n' "$section"; } > "$tmp"
    fi
    mv "$tmp" "$cur"; echo "wrote pending decisions to .agents/CONTEXT.md"
  fi
}

case "${1:-}" in
  validate) [ $# -eq 2 ] || die "usage: manifest.sh validate <manifest>"; validate "$2" && echo "manifest: ok" ;;
  apply) [ $# -eq 3 ] || die "usage: manifest.sh apply <manifest> <dir>"; apply "$2" "$3" ;;
  *) sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
