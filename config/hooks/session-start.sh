#!/usr/bin/env bash
# SessionStart: re-state the agent-routing rule (prose in CLAUDE.md loses to the harness
# default "don't spawn subagents unless asked") and, for large repos, nudge to create or
# refresh the codebase map (.agents/CONTEXT.md). Guidance only; always exits 0, fast.
set -uo pipefail

min_files="${AGENTS_MAP_MIN_FILES:-200}"
stale_commits="${AGENTS_MAP_STALE_COMMITS:-30}"

input="$(cat 2>/dev/null || true)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)"
[ -n "$cwd" ] && [ -d "$cwd" ] || cwd="$PWD"

msg='Agent routing (agents-config): open lookups (unknown paths, web, docs) -> `scout`; changes to >3 files or bulk writing -> `worker` with spec + acceptance command; `reasoner` (Opus, effort high) and plan mode decide and write specs; the main session (Opus, effort medium) executes, delegates and reports; costly-to-get-wrong decisions -> `reasoner`. Small edits to <=3 known files and single known-file reads stay inline. This is a standing user instruction.'

if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  n="$(git -C "$cwd" ls-files 2>/dev/null | wc -l | tr -d ' ')"
  if [ "${n:-0}" -ge "$min_files" ] 2>/dev/null; then
    root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)"
    ctx="$root/.agents/CONTEXT.md"
    if [ -z "$root" ]; then
      :
    elif [ ! -f "$ctx" ]; then
      msg="$msg"$'\n'"Large repo ($n files) with no .agents/CONTEXT.md: run the \`repository-context-maintainer\` skill (via a scout for the inventory) before exploring the code."
    else
      behind=0
      last="$(git -C "$root" log -1 --format=%H -- .agents/CONTEXT.md 2>/dev/null || true)"
      if [ -n "$last" ]; then
        behind="$(git -C "$root" rev-list --count "$last..HEAD" 2>/dev/null || echo 0)"
      elif [ -n "$(find "$ctx" -mtime +14 2>/dev/null)" ]; then
        behind="$stale_commits"  # untracked and older than 14 days: treat as stale
      fi
      if [ "${behind:-0}" -ge "$stale_commits" ] 2>/dev/null; then
        msg="$msg"$'\n'".agents/CONTEXT.md is $behind commits behind HEAD: refresh it with \`repository-context-maintainer\` before relying on it."
      else
        msg="$msg"$'\n'"Read .agents/CONTEXT.md before exploring the code."
      fi
    fi
  fi
fi

# Project setup state (guidance only; nothing is written without the user's OK).
HUB="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." 2>/dev/null && pwd || true)"
root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$root" ]; then
  if [ ! -f "$root/AGENTS.md" ]; then
    msg="$msg"$'\n'"This repo has no AGENTS.md (not set up with project-init): ask the user whether to run the \`project-init\` skill first (adopt mode if the repo already has code) before other work."
  elif [ ! -f "$root/.agents/project.json" ] && [ ! -d "$root/.claude/skills" ] && [ -x "$HUB/scripts/detect-stack.sh" ]; then
    stack="$(bash "$HUB/scripts/detect-stack.sh" "$root" 2>/dev/null || true)"
    if [ -n "$stack" ]; then
      msg="$msg"$'\n'"Stack skills are not installed here (detected stack: $stack). Propose to the user: \`bash $HUB/scripts/project-agents.sh --stack $stack --dry-run\` from the repo root, and apply it only with their OK."
    fi
  fi
elif [ -f "$cwd/AGENTS.md" ]; then
  msg="$msg"$'\n'"Workspace folder (not a git repo): read its AGENTS.md first. Each repo inside has its own AGENTS.md and stack skills; work inside the right repo for code changes."
else
  notice="Not inside a git repo or workspace: only global config is loaded (AGENTS.md, memory and stack skills are per repo). Open Claude inside the repo."
  # A folder that holds 2+ repos may be one product (frontend + backend): say so, never assume it.
  nrepos=0; names=""
  if [ "$cwd" != "$HOME" ]; then
    names="$(find "$cwd" -mindepth 2 -maxdepth 2 -name .git -printf '%h\n' 2>/dev/null | sort | xargs -r -n1 basename | head -n 6 | paste -sd, - | sed 's/,/, /g')"
    [ -n "$names" ] && nrepos="$(find "$cwd" -mindepth 2 -maxdepth 2 -name .git 2>/dev/null | wc -l | tr -d ' ')"
  fi
  if [ "${nrepos:-0}" -ge 2 ] 2>/dev/null; then
    notice="$notice This folder holds $nrepos git repos ($names). If they are one product, ask the user whether to create a workspace AGENTS.md with project-init's workspace mode (scripts/workspace.sh, dry-run first); if they are unrelated projects, ignore this."
  fi
  msg="$msg"$'\n'"$notice"
fi

jq -n --arg c "$msg" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}'
exit 0
