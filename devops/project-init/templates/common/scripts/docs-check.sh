#!/usr/bin/env bash
# docs-check.sh - advisory reminder, run from CI's `ci` job.
#
# If this PR changes something that usually needs a docs update (dependencies in
# package.json, pom.xml, build.gradle[.kts], libs.versions.toml, pyproject.toml or
# requirements*.txt, an env example file, docker/compose, a workflow file, or a
# new/removed top-level folder) without touching AGENTS.md, .agents/CONTEXT.md,
# or docs/, print a `::warning::` annotation. Non-blocking: always exits 0.
#
# Base ref comes from (in order): $1, $BASE_REF, $GITHUB_BASE_REF. Needs
# `origin/<base_ref>` to exist, so the workflow checks out with fetch-depth: 0.
# Safe to run outside a PR (push, local, no base ref) - it just has nothing to
# compare against and exits quietly.
set -uo pipefail

BASE_REF="${1:-${BASE_REF:-${GITHUB_BASE_REF:-}}}"

if [ -z "$BASE_REF" ]; then
  echo "docs-check: no base ref (not a pull request), skipping"
  exit 0
fi

if ! git rev-parse --verify "origin/$BASE_REF" >/dev/null 2>&1; then
  echo "docs-check: origin/$BASE_REF not found (shallow clone?), skipping"
  exit 0
fi

CHANGED="$(git diff --name-only "origin/$BASE_REF...HEAD" 2>/dev/null || true)"
if [ -z "$CHANGED" ]; then
  echo "docs-check: no changed files against origin/$BASE_REF, skipping"
  exit 0
fi

# Already documented in this PR - nothing more to check.
while IFS= read -r f; do
  case "$f" in
    AGENTS.md | .agents/CONTEXT.md | docs/*)
      echo "docs-check: docs were updated in this PR"
      exit 0
      ;;
  esac
done <<EOF
$CHANGED
EOF

reasons=()

# package.json dependency changes (dependencies/devDependencies/peerDependencies
# only - a scripts-only edit doesn't need a docs update).
if command -v jq >/dev/null 2>&1; then
  while IFS= read -r f; do
    case "$f" in
      package.json | */package.json) ;;
      *) continue ;;
    esac
    old_deps="$(git show "origin/$BASE_REF:$f" 2>/dev/null | jq -S '{dependencies, devDependencies, peerDependencies}' 2>/dev/null || echo '{}')"
    new_deps="$(jq -S '{dependencies, devDependencies, peerDependencies}' "$f" 2>/dev/null || echo '{}')"
    if [ "$old_deps" != "$new_deps" ]; then
      reasons+=("dependency change in $f")
    fi
  done <<EOF
$CHANGED
EOF
fi

# Dependency changes in the other ecosystems (Maven, Gradle, Python). Each file is reduced to a
# normalized "dependency signature" so a project version bump, a new task or a formatting edit
# does not warn, and the signature at the base is compared with the one at HEAD.
dep_signature() { # dep_signature <kind> : reads the file on stdin
  case "$1" in
    pom) sed 's/>[[:space:]]*</>\n</g' | awk '   # one tag per line, so a minified pom works too
      /<dependency>/ { d = 1; coord = ""; next }
      /<\/dependency>/ { if (d) print coord; d = 0; next }
      d { l = $0; gsub(/^[ \t]+|[ \t]+$/, "", l); if (l ~ /^<(groupId|artifactId|version|scope|classifier|type)>/) coord = coord l }' ;;
    gradle) awk '{ l = $0; gsub(/^[ \t]+|[ \t]+$/, "", l)
      if (l ~ /^(implementation|api|compileOnly|runtimeOnly|testImplementation|testRuntimeOnly|testCompileOnly|annotationProcessor|developmentOnly|kapt|ksp|classpath|id|alias|kotlin)[ (\x27"]/) print l }' ;;
    catalog) sed -e 's/^[[:space:]]*//' -e '/^#/d' -e '/^$/d' ;;
    py) awk '
      /^\[/ { t = $0; next }
      t ~ /^\[(project|dependency-groups|tool\.uv|build-system)\]/ || t ~ /^\[project\.optional-dependencies\]/ {
        l = $0; gsub(/^[ \t]+|[ \t]+$/, "", l)
        if (l ~ /^"/ || l ~ /^(dependencies|dev-dependencies|requires)[ \t]*=/ || (t ~ /dependency-groups|optional-dependencies/ && l ~ /^[A-Za-z0-9_-]+[ \t]*=/)) print l
      }' ;;
    req) sed -e 's/^[[:space:]]*//' -e '/^#/d' -e '/^$/d' ;;
  esac
}
while IFS= read -r f; do
  case "$f" in
    pom.xml | */pom.xml) kind=pom ;;
    build.gradle | build.gradle.kts | */build.gradle | */build.gradle.kts) kind=gradle ;;
    libs.versions.toml | */libs.versions.toml) kind=catalog ;;
    pyproject.toml | */pyproject.toml) kind=py ;;
    requirements*.txt | */requirements*.txt) kind=req ;;
    *) continue ;;
  esac
  old_sig="$(git show "origin/$BASE_REF:$f" 2>/dev/null | dep_signature "$kind" | sort)"
  new_sig=""; [ -f "$f" ] && new_sig="$(dep_signature "$kind" < "$f" | sort)"
  [ "$old_sig" = "$new_sig" ] || reasons+=("dependency change in $f")
done <<EOF
$CHANGED
EOF

# Env example files.
while IFS= read -r f; do
  case "$f" in
    *.env.example | *env.example) reasons+=("env example changed: $f") ;;
  esac
done <<EOF
$CHANGED
EOF

# Docker / compose files.
while IFS= read -r f; do
  case "$f" in
    docker-compose*.yml | docker-compose*.yaml | */docker-compose*.yml | */docker-compose*.yaml | Dockerfile | */Dockerfile | docker/* | */docker/*)
      reasons+=("docker/compose changed: $f")
      ;;
  esac
done <<EOF
$CHANGED
EOF

# Workflow files.
while IFS= read -r f; do
  case "$f" in
    .github/workflows/*) reasons+=("workflow changed: $f") ;;
    scripts/gh-flow.sh | .githooks/* | .claude/hooks/* | .claude/settings.json | .github/ISSUE_TEMPLATE/* | .github/PULL_REQUEST_TEMPLATE.md)
      reasons+=("workflow contract file changed: $f (update the Workflow contract in AGENTS.md)") ;;
  esac
done <<EOF
$CHANGED
EOF

# New or removed top-level folder.
old_dirs="$(git ls-tree -d --name-only "origin/$BASE_REF" 2>/dev/null | sort)"
new_dirs="$(git ls-tree -d --name-only HEAD 2>/dev/null | sort)"
if [ "$old_dirs" != "$new_dirs" ]; then
  reasons+=("top-level folders changed")
fi

if [ "${#reasons[@]}" -eq 0 ]; then
  echo "docs-check: nothing that usually needs a docs update"
  exit 0
fi

printf -v joined '%s; ' "${reasons[@]}"
echo "::warning::docs-check: this PR looks like it needs a docs update (${joined%; }) but doesn't touch AGENTS.md, .agents/CONTEXT.md, or docs/ - update them if this changes what a new session needs to know."
exit 0
