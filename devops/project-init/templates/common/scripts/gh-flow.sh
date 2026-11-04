#!/usr/bin/env bash
# gh-flow.sh - the only supported way to move an issue through branch, PR,
# and merge. Keeps dev/main protected and the Project board in sync.
#
# Usage: gh-flow.sh <command> [args]
#
# Commands:
#   issue   <feat|fix|refactor|chore> "<title>"
#   start   <feat|fix|refactor> <slug> [--issue N]
#   pr      [--title "<title>"]
#   merge
#   release
#
# Env:
#   DRY_RUN=1   print commands instead of running them.
set -euo pipefail

# A shell exporting CLICOLOR_FORCE=1 makes gh emit ANSI codes even when piped,
# which breaks `gh ... --format json | jq`. Only CLICOLOR_FORCE=0 turns it off.
export CLICOLOR_FORCE=0 NO_COLOR=1

usage() {
  cat <<'EOF'
Usage: gh-flow.sh <command> [args]

Commands:
  issue   <feat|fix|refactor|chore> "<title>"
  start   <feat|fix|refactor> <slug> [--issue N]
  pr      [--title "<title>"]
  merge
  release

Env:
  DRY_RUN=1   print commands instead of running them.
EOF
}

run() {
  if [ "${DRY_RUN:-0}" = "1" ]; then
    printf '+ %s\n' "$*"
  else
    "$@"
  fi
}

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

pkg_has_script() {
  [ -f package.json ] || return 1
  jq -e --arg s "$1" '.scripts[$s] != null' package.json >/dev/null 2>&1
}

cmd_issue() {
  [ $# -ge 2 ] || { echo "issue: usage: gh-flow.sh issue <feat|fix|refactor|chore> \"<title>\"" >&2; exit 1; }
  local type="$1" title="$2"
  case "$type" in
    feat|fix|refactor|chore) ;;
    *) echo "issue: type must be feat|fix|refactor|chore" >&2; exit 1 ;;
  esac
  run gh issue create --title "$title" --label "$type" --project "{{PROJECT}}" \
    --body "Created via scripts/gh-flow.sh issue $type."
}

cmd_start() {
  [ $# -ge 2 ] || { echo "start: usage: gh-flow.sh start <feat|fix|refactor> <slug> [--issue N]" >&2; exit 1; }
  local type="$1" raw_slug="$2" issue=""
  shift 2
  case "$type" in
    feat|fix|refactor) ;;
    *) echo "start: type must be feat|fix|refactor" >&2; exit 1 ;;
  esac
  while [ $# -gt 0 ]; do
    case "$1" in
      --issue) issue="$2"; shift 2 ;;
      *) echo "start: unknown arg $1" >&2; exit 1 ;;
    esac
  done

  local slug branch
  slug="$(slugify "$raw_slug")"
  if [ -n "$issue" ]; then
    branch="${type}/${issue}-${slug}"
  else
    branch="${type}/${slug}"
  fi

  run git checkout dev
  # --autostash: with pull.rebase set, a dirty tree makes a plain pull fail;
  # stash/pop carries the uncommitted work onto the new branch.
  run git pull --autostash
  run git checkout -b "$branch"
  echo "Created branch $branch"
}

cmd_pr() {
  local title_override=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --title) title_override="$2"; shift 2 ;;
      *) echo "pr: unknown arg $1" >&2; exit 1 ;;
    esac
  done

  local branch
  branch="$(git branch --show-current)"
  case "$branch" in
    dev|main) echo "pr: refusing to open a PR from $branch" >&2; exit 1 ;;
  esac

  if [ -f .agents/stack.env ]; then
    # Non-node stack: commands live in .agents/stack.env (written by project-init).
    # shellcheck disable=SC1091
    . .agents/stack.env
    for c in "$CMD_LINT" "$CMD_TYPECHECK" "$CMD_TEST"; do
      [ -n "$c" ] && run bash -c "$c"
    done
  else
    for script in lint typecheck test; do
      if pkg_has_script "$script"; then
        run pnpm "$script"
      fi
    done
  fi

  run git push -u origin "$branch"

  local type="" issue="" slug="$branch"
  if [[ "$branch" =~ ^(feat|fix|refactor)/([0-9]+)-(.+)$ ]]; then
    type="${BASH_REMATCH[1]}"; issue="${BASH_REMATCH[2]}"; slug="${BASH_REMATCH[3]}"
  elif [[ "$branch" =~ ^(feat|fix|refactor)/(.+)$ ]]; then
    type="${BASH_REMATCH[1]}"; slug="${BASH_REMATCH[2]}"
  fi

  local title="$title_override"
  if [ -z "$title" ]; then
    local words
    words="$(printf '%s' "$slug" | tr '-' ' ')"
    if [ -n "$type" ]; then title="${type}: ${words}"; else title="$words"; fi
  fi

  local body_file
  body_file="$(mktemp)"
  if [ -f .github/PULL_REQUEST_TEMPLATE.md ]; then
    cp .github/PULL_REQUEST_TEMPLATE.md "$body_file"
  fi
  if [ -n "$issue" ]; then
    sed -i "s/<issue-number>/$issue/g" "$body_file"
  fi

  run gh pr create --base dev --title "$title" --body-file "$body_file"
  rm -f "$body_file"
}

cmd_merge() {
  run gh pr checks --watch
  run gh pr merge --squash --delete-branch
  run git checkout dev
  run git pull
}

cmd_release() {
  local today
  today="$(date +%Y-%m-%d)"
  run gh pr create --base main --head dev --title "release: $today"
}

[ $# -ge 1 ] || { usage; exit 1; }
sub="$1"; shift
case "$sub" in
  issue) cmd_issue "$@" ;;
  start) cmd_start "$@" ;;
  pr) cmd_pr "$@" ;;
  merge) cmd_merge "$@" ;;
  release) cmd_release "$@" ;;
  -h|--help) usage ;;
  *) echo "Unknown command: $sub" >&2; usage; exit 1 ;;
esac
