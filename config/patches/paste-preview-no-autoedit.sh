#!/usr/bin/env bash
# paste-preview-no-autoedit.sh - stop paste-preview from opening its editor on every paste.
# The "Edit" button next to each pasted image still opens it on demand.
#
# paste-preview (alan890104/claude-code-paste-preview) has no setting for this, so we comment the one
# line that queues the editor in `capture()` (hooks/register.tsx). Idempotent; a plugin update
# overwrites the file, so install.sh re-runs this after installing plugins.
#
# Usage: paste-preview-no-autoedit.sh [--dry-run]
set -euo pipefail

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

LINE="  if (file !== '') enqueue(\$, n, file)"
MARK="  // local patch (agents-config): the editor no longer opens on paste; the Edit button still does."
PLUGINS="${CLAUDE_PLUGINS_DIR:-$HOME/.claude/plugins}"

patched=0
while IFS= read -r f; do
  if grep -qF -- "local patch (agents-config)" "$f" || grep -qF -- "local patch (Loren)" "$f"; then
    echo "ok:      already patched: ${f#"$HOME"/}"
    continue
  fi
  if ! grep -qxF -- "$LINE" "$f"; then
    echo "warn:    target line not found (plugin changed?): ${f#"$HOME"/}" >&2
    continue
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] would patch ${f#"$HOME"/}"
    continue
  fi
  tmp="$(mktemp)"
  awk -v line="$LINE" -v mark="$MARK" '$0 == line { print mark; print "  //" substr($0, 2); next } { print }' "$f" >"$tmp"
  cat "$tmp" >"$f" && rm -f "$tmp"
  echo "patched: ${f#"$HOME"/}"
  patched=$((patched + 1))
done < <(find "$PLUGINS/cache/paste-preview" "$PLUGINS/marketplaces/paste-preview" -name register.tsx -path '*hooks*' -not -path '*/node_modules/*' 2>/dev/null)

[ "$patched" -gt 0 ] && echo "restart Claude Code or run /reload-plugins for the patch to take effect"
exit 0
