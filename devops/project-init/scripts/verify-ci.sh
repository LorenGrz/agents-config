#!/usr/bin/env bash
# verify-ci.sh - reproduce CI locally from a clean checkout of the project's
# committed HEAD. Catches what only passes on your machine: files that are
# gitignored/untracked, binaries that were never declared as dependencies,
# generated files (.next/types) that exist locally but not in a clone.
#
# Usage: verify-ci.sh --dir <path>
#
# Mirrors templates/common/.github/workflows/ci.yml: install --frozen-lockfile,
# then format:check, lint --max-warnings 0, typecheck, test, build (all
# --if-present). Exits non-zero on the first failing step, naming it.
set -euo pipefail

usage() { echo "Usage: verify-ci.sh --dir <path>"; }

DIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done
[ -n "$DIR" ] || { usage >&2; exit 1; }
[ -d "$DIR" ] || { echo "Error: $DIR is not a directory" >&2; exit 1; }

if ! git -C "$DIR" rev-parse --verify -q HEAD >/dev/null 2>&1; then
  echo "Error: $DIR has no commits. verify-ci.sh checks the committed HEAD; commit first (SKILL step 3)." >&2
  exit 1
fi
if [ -n "$(git -C "$DIR" status --porcelain)" ]; then
  echo "warning: $DIR has uncommitted changes; only the committed HEAD is verified" >&2
fi

# CI sets CI=true: tools switch to non-interactive/non-watch behavior.
export CI=true
# Forced-color shells (CLICOLOR_FORCE/FORCE_COLOR) only add noise to logs here.
export NO_COLOR=1

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
git clone -q "$(cd "$DIR" && pwd)" "$WORK/repo"
cd "$WORK/repo"

step() { # step <label> <command...>
  local label="$1"; shift
  echo "==> $label"
  if ! "$@"; then
    echo "FAILED step: $label" >&2
    exit 1
  fi
}

if [ -f .agents/stack.env ]; then
  # Non-node stack: same steps as its ci.yml, taken from .agents/stack.env.
  # shellcheck disable=SC1091
  . .agents/stack.env
  for pair in "install:$CMD_INSTALL" "format check:$CMD_FORMAT_CHECK" "lint:$CMD_LINT" \
              "typecheck:$CMD_TYPECHECK" "test:$CMD_TEST" "build:$CMD_BUILD"; do
    [ -n "${pair#*:}" ] && step "${pair%%:*}" bash -c "${pair#*:}"
  done
else
  step "pnpm install --frozen-lockfile" pnpm install --frozen-lockfile
  step "format:check" pnpm run --if-present format:check
  step "lint --max-warnings 0" pnpm run --if-present lint --max-warnings 0
  step "typecheck" pnpm run --if-present typecheck
  step "test" pnpm run --if-present test
  step "build" pnpm run --if-present build
fi
echo "verify-ci: all steps passed"
