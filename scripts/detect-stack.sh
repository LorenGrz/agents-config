#!/usr/bin/env bash
# detect-stack.sh - guess the config/scopes.json stack(s) of a repo from its manifest files.
#
# Usage: detect-stack.sh [dir]     (default: current directory)
# Prints a comma-separated list (e.g. "next" or "nestjs,aws"), or nothing when no stack is recognised.
# Read-only, fast, never fails: it is called from the SessionStart hook.
set -uo pipefail

dir="${1:-.}"
[ -d "$dir" ] || exit 0
cd "$dir" || exit 0

found=()
add() { local s; for s in "${found[@]:-}"; do [ "$s" = "$1" ] && return; done; found+=("$1"); }

if [ -f package.json ] && command -v jq >/dev/null 2>&1; then
  deps="$(jq -r '[(.dependencies // {}), (.devDependencies // {})] | add | keys[]' package.json 2>/dev/null || true)"
  has() { grep -qxF -- "$1" <<<"$deps"; }
  if has next; then add next
  elif has @nestjs/core; then add nestjs
  elif has react-native; then add rn
  elif has vite && has react; then add react-vite
  elif has typescript || [ -f tsconfig.json ]; then add node-ts
  fi
fi

if [ -f pyproject.toml ] || [ -f requirements.txt ] || [ -f setup.py ]; then add python; fi

for f in pom.xml build.gradle build.gradle.kts; do
  if [ -f "$f" ] && grep -qi 'spring' "$f" 2>/dev/null; then
    if grep -qiE 'kotlin' "$f" 2>/dev/null; then add kotlin-spring; else add java-spring; fi
    break
  fi
done

if [ -f template.yaml ] || [ -f template.yml ] || [ -f samconfig.toml ]; then add aws; fi
if [ -f supabase/config.toml ]; then add supabase; fi

[ "${#found[@]}" -gt 0 ] || exit 0
(IFS=,; echo "${found[*]}")
