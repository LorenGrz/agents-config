#!/usr/bin/env bash
# lint-docs.sh - check the markdown templates of skills, rules and pack commands (ADR 0026).
#
# Usage: lint-docs.sh [--strict] [--files <path>...]
#   (default)   print every violation, then a summary; exit 0 (warn mode)
#   --strict    exit 1 when there is any violation
#   --files     lint only these paths instead of the whole tree
#
# Checked (default scope):
#   skills/*/*/SKILL.md and packs/*/skills/*/SKILL.md (skills/external is skipped)
#     - frontmatter present, `name` equal to the folder, non-empty `description`
#     - `##` headings only from: Objective, When to use, Prerequisites, Workflow, Rules, Reference,
#       Output, Verification, Claude Code, Shortcuts - in that order, none repeated
#     - at least one of Workflow or Rules; Shortcuts is the last `##` heading
#     - EXEMPT skills (frontmatter only): orca-cli, orchestration, frontend-design
#   config/rules/*.md       frontmatter with `paths:`
#   packs/*/commands/*.md   frontmatter with a non-empty `description`
#
# Rule ids in the output: frontmatter, name, description, heading, order, workflow-or-rules,
# shortcuts-last, paths, missing.
set -uo pipefail

HUB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXEMPT=" orca-cli orchestration frontend-design "
STRICT=0
FILES=()

while [ $# -gt 0 ]; do
  case "$1" in
    --strict) STRICT=1; shift ;;
    --files) shift; while [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; do FILES+=("$1"); shift; done
             [ "${#FILES[@]}" -gt 0 ] || { echo "lint-docs: --files needs at least one path" >&2; exit 2; } ;;
    -h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "lint-docs: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

if [ "${#FILES[@]}" -eq 0 ]; then
  shopt -s nullglob
  for f in "$HUB"/skills/*/*/SKILL.md "$HUB"/packs/*/skills/*/SKILL.md "$HUB"/config/rules/*.md "$HUB"/packs/*/commands/*.md; do
    case "$f" in "$HUB"/skills/external/*) continue ;; esac
    FILES+=("$f")
  done
  shopt -u nullglob
fi

# lint_file <kind> <path> <exempt 0|1> -> prints "rule<TAB>message" lines.
lint_file() {
  awk -v kind="$1" -v folder="$(basename "$(dirname "$2")")" -v exempt="$3" '
    BEGIN {
      n = split("Objective|When to use|Prerequisites|Workflow|Rules|Reference|Output|Verification|Claude Code|Shortcuts", W, "|")
      for (i = 1; i <= n; i++) idx[W[i]] = i
      state = 0   # 0 = expecting line 1, 1 = inside frontmatter, 2 = body
      fence = 0; last = 0; lastname = ""; shortcuts = 0; hasname = 0; hasdesc = 0; indesc = 0
    }
    function v(rule, msg) { printf "%s\t%s\n", rule, msg }
    { sub(/\r$/, "") }
    NR == 1 {
      if ($0 == "---") { state = 1; next }
      v("frontmatter", "missing frontmatter (the file must start with ---)")
      state = 2; nofm = 1
    }
    state == 1 {
      if ($0 == "---") { state = 2; closed = 1; if (indesc == 1) v("description", "description block is empty"); next }
      if ($0 ~ /^name:/) {
        indesc = 0; hasname = 1; val = $0; sub(/^name:[ \t]*/, "", val); gsub(/^["\047]|["\047]$/, "", val)
        if (val != folder) v("name", "name \"" val "\" differs from folder \"" folder "\"")
      } else if ($0 ~ /^description:/) {
        hasdesc = 1; val = $0; sub(/^description:[ \t]*/, "", val); sub(/[ \t]+$/, "", val)
        if (val ~ /^[>|][+-]?[0-9]*$/) indesc = 1
        else { indesc = 0; if (val == "" || val == "\"\"" || val == "\047\047") v("description", "description is empty") }
      } else if ($0 ~ /^paths:/) { indesc = 0; haspaths = 1 }
      else if (indesc == 1) {
        if ($0 ~ /^[ \t]+[^ \t]/) indesc = 2
        else if ($0 ~ /^[^ \t]/) { v("description", "description block is empty"); indesc = 0 }
      } else if ($0 ~ /^[^ \t]/) indesc = 0
      next
    }
    state == 2 {
      if ($0 ~ /^[ \t]*(```|~~~)/) { fence = !fence; next }
      if (fence || kind != "skill" || exempt == 1) next
      if ($0 ~ /^## /) {
        t = substr($0, 4); sub(/[ \t]+$/, "", t)
        if (shortcuts == 1) { v("shortcuts-last", "\"## " t "\" comes after Shortcuts, which must be last"); next }
        if (!(t in idx)) { v("heading", "\"## " t "\" is not an allowed heading"); next }
        if (idx[t] < last) v("order", "\"## " t "\" must come before \"## " lastname "\"")
        else if (idx[t] == last) v("order", "\"## " t "\" is repeated")
        else { last = idx[t]; lastname = t }
        seen[t] = 1
        if (t == "Shortcuts") shortcuts = 1
      }
    }
    END {
      if (!nofm && state == 1) v("frontmatter", "frontmatter is not closed (missing the second ---)")
      if (kind == "skill") {
        if (!nofm && !hasname) v("name", "frontmatter has no name")
        if (!nofm && !hasdesc) v("description", "frontmatter has no description")
        if (exempt != 1 && !(seen["Workflow"] || seen["Rules"])) v("workflow-or-rules", "needs a Workflow or a Rules section")
      } else if (kind == "rule") {
        if (!nofm && !haspaths) v("paths", "frontmatter has no paths:")
      } else if (kind == "command") {
        if (!nofm && !hasdesc) v("description", "frontmatter has no description")
      }
    }
  ' "$2"
}

declare -A COUNT=()
total=0 bad_files=0 checked=0
for f in "${FILES[@]}"; do
  rel="${f#"$HUB"/}"
  if [ ! -f "$f" ]; then
    echo "$rel: [missing] file not found"; COUNT[missing]=$(( ${COUNT[missing]:-0} + 1 )); total=$((total + 1)); bad_files=$((bad_files + 1)); continue
  fi
  case "$rel" in
    */SKILL.md) kind=skill ;;
    config/rules/*.md|*/config/rules/*.md) kind=rule ;;
    packs/*/commands/*.md|*/packs/*/commands/*.md) kind=command ;;
    *) echo "lint-docs: skipping $rel (not a skill, rule or pack command)" >&2; continue ;;
  esac
  ex=0
  if [ "$kind" = skill ]; then
    case "$EXEMPT" in *" $(basename "$(dirname "$f")") "*) ex=1 ;; esac
  fi
  checked=$((checked + 1))
  n=0
  while IFS=$'\t' read -r rule msg; do
    [ -n "$rule" ] || continue
    echo "$rel: [$rule] $msg"
    COUNT[$rule]=$(( ${COUNT[$rule]:-0} + 1 )); n=$((n + 1))
  done < <(lint_file "$kind" "$f" "$ex")
  total=$((total + n)); [ "$n" -gt 0 ] && bad_files=$((bad_files + 1))
done

echo
for rule in frontmatter name description heading order workflow-or-rules shortcuts-last paths missing; do
  [ "${COUNT[$rule]:-0}" -gt 0 ] && echo "  $rule: ${COUNT[$rule]}"
done
echo "lint-docs: $total violation(s) in $bad_files of $checked file(s)"

if [ "$STRICT" -eq 1 ] && [ "$total" -gt 0 ]; then exit 1; fi
exit 0
