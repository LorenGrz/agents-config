#!/usr/bin/env bash
# approve-claude-imports.sh <folder>... (ADR 0039): pre-approves the external CLAUDE.md imports of a
# folder in ~/.claude.json, the same as answering «Yes» to «Allow external CLAUDE.md file imports?».
# A leader session started in a new worktree (Orca, T3 Code) otherwise stops on that dialog, and
# --dangerously-skip-permissions does not skip it. The user approved this for every new worktree
# on 2026-11-19.
#
# Not documented by Claude Code (checked 2026-11-19): the key is internal and may change. Measured on
# 2.1.327: for a git worktree the approval is read from the MAIN checkout's root, not from the
# worktree folder; marking only the worktree did not stop the dialog. So this marks both.
# Writes through a temp file and renames it, so a reader never sees half a file.
set -euo pipefail

CONFIG="${CLAUDE_CONFIG_JSON:-$HOME/.claude.json}"
[ "$#" -gt 0 ] || { echo "uso: $0 <carpeta>..." >&2; exit 2; }
[ -f "$CONFIG" ] || { echo "no existe $CONFIG" >&2; exit 1; }

approve() {
  local tmp
  tmp=$(mktemp "${CONFIG}.XXXXXX")
  jq --arg p "$1" '
    .projects[$p] = ((.projects[$p] // {}) + {
      hasTrustDialogAccepted: true,
      hasClaudeMdExternalIncludesApproved: true,
      hasClaudeMdExternalIncludesWarningShown: true
    })' "$CONFIG" >"$tmp"
  mv "$tmp" "$CONFIG"
  echo "aprobado: $1"
}

for dir in "$@"; do
  path=$(cd "$dir" && pwd -P)
  approve "$path"
  # In a worktree, the common git dir belongs to the main checkout: its parent is that checkout's root.
  if common=$(git -C "$path" rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
    main=$(dirname "$common")
    [ "$main" != "$path" ] && approve "$main"
  fi
done
