#!/usr/bin/env bash
# e2e.sh - regression check for the skill itself. For each stack: generate the
# app non-interactively in a fresh temp dir, run init.sh --install, make the
# initial commit, then verify-ci.sh (a clean clone running CI's steps). Also
# re-runs init.sh and asserts the tree stays clean (idempotency). Run it after
# editing anything under this skill. Never touches GitHub.
#
# Usage: e2e.sh [--stack <react-vite|next|nestjs|node-ts|python|java-spring|java-spring-gradle|kotlin-spring|all>] [--keep]
#   --keep   keep the temp dirs (and print their path) for inspection
set -euo pipefail

usage() { echo "Usage: e2e.sh [--stack <react-vite|next|nestjs|node-ts|python|java-spring|java-spring-gradle|kotlin-spring|all>] [--keep]"; }

STACK="all"
KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --stack) STACK="$2"; shift 2 ;;
    --keep) KEEP=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

ALL_STACKS=(react-vite next nestjs node-ts python java-spring java-spring-gradle kotlin-spring)
case "$STACK" in
  all) STACKS=("${ALL_STACKS[@]}") ;;
  react-vite|next|nestjs|node-ts|python|java-spring|java-spring-gradle|kotlin-spring) STACKS=("$STACK") ;;
  *) echo "Error: --stack must be one of react-vite|next|nestjs|node-ts|all" >&2; exit 1 ;;
esac

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
if [ "$KEEP" = 1 ]; then
  echo "keeping temp dirs under $WORK"
else
  trap 'rm -rf "$WORK"' EXIT
fi

# Generators run non-interactively; the dir/package name is lowercase (npm
# rule) while --name to init.sh plays the GitHub repo name (capitalized here
# on purpose, to cover that distinction).
generate() { # generate <stack> <dir>
  local stack="$1" dir="$2" base
  base="$(basename "$dir")"
  case "$stack" in
    next)
      pnpm create next-app@latest "$dir" --yes --use-pnpm --disable-git ;;
    react-vite)
      # vite resolves its target relative to cwd (an absolute path nests).
      (cd "$(dirname "$dir")" && pnpm create vite@latest "$base" --template react-ts --no-interactive --no-immediate)
      pnpm -C "$dir" install ;;
    nestjs)
      (cd "$(dirname "$dir")" && pnpm dlx @nestjs/cli new "$base" --directory "$base" \
        --package-manager pnpm --skip-git --no-observe) ;;
    node-ts)
      mkdir -p "$dir" ;;
    python)
      uv init --package --vcs none "$dir" ;;
    java-spring|java-spring-gradle|kotlin-spring)
      # Spring Initializr; a lowercase artifact/package name derived from the dir.
      local type=maven-project lang=java
      [ "$stack" = java-spring-gradle ] && type=gradle-project
      [ "$stack" = kotlin-spring ] && { type=gradle-project-kotlin; lang=kotlin; }
      mkdir -p "$dir"
      curl -fsS https://start.spring.io/starter.zip -d type=$type -d language=$lang -d javaVersion=21 \
        -d groupId=com.example -d artifactId="$base" -d name="$base" -d packageName="com.example.${base//-/}" \
        -d dependencies=web,validation,actuator -o "$dir.zip"
      unzip -q "$dir.zip" -d "$dir" && rm -f "$dir.zip" ;;
  esac
}

# JVM edit hook: formatting the edited file must not touch any other file (Gradle once ignored
# the per-file flag and reformatted the whole project). Leaves the tree as it found it.
hook_check() { # hook_check <stack> <dir>
  local stack="$1" dir="$2" d ext
  case "$stack" in java-spring|java-spring-gradle|kotlin-spring) ;; *) return 0 ;; esac
  ext=java; [ "$stack" = kotlin-spring ] && ext=kt
  d="$(dirname "$(find "$dir/src/main" -name "*Application.$ext" | head -1)")"
  for n in One Two; do
    if [ "$ext" = java ]; then printf 'package x;\npublic class %s   {  int   a=1;\n\n\n void  m( ){ }  }\n' "$n" > "$d/$n.java"
    else printf 'package x\nclass %s(  val a:Int ){fun   m( ) =   1}\n' "$n" > "$d/$n.kt"; fi
  done
  local before; before="$(sha1sum "$d/Two.$ext")"
  printf '{"tool_input":{"file_path":"%s"}}' "$d/One.$ext" | bash "$dir/.claude/hooks/lint-on-edit.sh" || return 1
  local ok=1
  if [ "$ext" = java ]; then grep -q 'int a = 1;' "$d/One.java" || ok=0; else grep -q 'val a: Int' "$d/One.kt" || ok=0; fi
  [ "$(sha1sum "$d/Two.$ext")" = "$before" ] || ok=0
  rm -f "$d/One.$ext" "$d/Two.$ext"
  [ "$ok" = 1 ] || { echo "hook_check failed: the edit hook must format One and leave Two untouched" >&2; return 1; }
}

run_stack() { # run_stack <stack> <dir>
  local stack="$1" dir="$2"
  local -a init_args=(--stack "${stack%-gradle}" --name "E2e-$stack" --dir "$dir" --owner e2e-owner --install)

  # `|| return 1` everywhere: this function runs inside `if`, where set -e is off.
  generate "$stack" "$dir" || return 1
  bash "$SCRIPTS_DIR/init.sh" "${init_args[@]}" || return 1

  git -C "$dir" init -q -b main || return 1
  git -C "$dir" config core.hooksPath .githooks || return 1
  git -C "$dir" add -A || return 1
  git -C "$dir" -c user.name=e2e -c user.email=e2e@example.invalid commit -q -m "chore: initial project setup" || return 1

  bash "$SCRIPTS_DIR/verify-ci.sh" --dir "$dir" || return 1
  hook_check "$stack" "$dir" || return 1

  # Idempotency: a second run must change nothing.
  bash "$SCRIPTS_DIR/init.sh" "${init_args[@]}" || return 1
  if [ -n "$(git -C "$dir" status --porcelain)" ]; then
    echo "idempotency check failed: init.sh re-run changed files:" >&2
    git -C "$dir" status --porcelain >&2
    return 1
  fi
}

declare -A RESULT
overall=0
for s in "${STACKS[@]}"; do
  dir="$WORK/e2e-$s"
  log="$WORK/$s.log"
  echo "### $s (log: $log)"
  if run_stack "$s" "$dir" >"$log" 2>&1; then
    RESULT[$s]=PASS
  else
    RESULT[$s]=FAIL
    overall=1
    echo "--- last 40 lines of $s log ---"
    tail -n 40 "$log"
    # The log lives in WORK; keep it around so the failure can be inspected.
    if [ "$KEEP" != 1 ]; then cp "$log" "/tmp/project-init-e2e-$s.log" && echo "full log: /tmp/project-init-e2e-$s.log"; fi
  fi
done

echo
printf '%-12s %s\n' STACK RESULT
for s in "${STACKS[@]}"; do printf '%-12s %s\n' "$s" "${RESULT[$s]}"; done
exit "$overall"
