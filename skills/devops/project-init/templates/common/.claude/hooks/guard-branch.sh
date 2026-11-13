#!/usr/bin/env bash
# PreToolUse(Bash) hook: block `git commit` and `git push` against dev/main
# directly. Everything else is allowed silently. Branch work must go through
# scripts/gh-flow.sh so issues/PRs/CI stay wired up.
set -uo pipefail

input="$(cat)"
cmd="$(jq -r '.tool_input.command // .toolCall.args.CommandLine // empty' <<<"$input" 2>/dev/null)"
cwd="$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)"
[ -z "$cmd" ] && exit 0
[ -z "$cwd" ] && cwd="$(pwd)"

REASON='Direct commits/pushes to dev or main are blocked. Use scripts/gh-flow.sh start|pr|merge (or release for main) instead.'

deny() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$REASON"
  exit 0
}

# Judge the repo the command actually targets, not the session's cwd:
# `git -C <dir> ...` or a leading `cd <dir> && ...` (else a commit in another
# repo is blocked whenever this one sits on dev, and `git -C` slips through).
GIT_C='git([[:space:]]+-C[[:space:]]+[^[:space:];&|]+)?[[:space:]]+'
target=""
if [[ "$cmd" =~ git[[:space:]]+-C[[:space:]]+([^[:space:];&|]+) ]]; then
  target="${BASH_REMATCH[1]}"
elif [[ "$cmd" =~ ^[[:space:]]*cd[[:space:]]+([^[:space:];&|]+) ]]; then
  target="${BASH_REMATCH[1]}"
fi
if [ -n "$target" ]; then
  target="${target//[\"\']/}"
  target="${target/#\~/$HOME}"
  [[ "$target" == /* ]] || target="$cwd/$target"
  cwd="$target"
fi

current_branch() {
  git -C "$cwd" branch --show-current 2>/dev/null
}

if [[ "$cmd" =~ (^|[[:space:];&|])${GIT_C}commit([[:space:]]|$) ]]; then
  # The very first commit (SKILL step 3) lands on main by design: with no
  # HEAD yet there is nothing to protect.
  git -C "$cwd" rev-parse --verify -q HEAD >/dev/null 2>&1 || exit 0
  branch="$(current_branch)"
  if [ "$branch" = "dev" ] || [ "$branch" = "main" ]; then deny; fi
  exit 0
fi

if [[ "$cmd" =~ (^|[[:space:];&|])${GIT_C}push([[:space:]]|$) ]]; then
  rest="${cmd#*push}"
  tokens=()
  for tok in $rest; do
    [[ "$tok" == -* ]] && continue
    tokens+=("$tok")
  done
  refspec="${tokens[1]:-}"
  if [ -n "$refspec" ]; then
    if [[ "$refspec" == *:* ]]; then
      target="${refspec#*:}"
    else
      target="$refspec"
    fi
  else
    target="$(current_branch)"
  fi
  target="${target#refs/heads/}"
  if [ "$target" = "dev" ] || [ "$target" = "main" ]; then deny; fi
  exit 0
fi

exit 0
