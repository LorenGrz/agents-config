#!/usr/bin/env bash
# Regenerate the flat symlink mirror that Claude Code reads
# (~/.claude/skills) from the categorised skill tree.
#
# Claude Code only discovers ~/.claude/skills/<name>/SKILL.md (direct children),
# so category folders live in the source tree and the mirror stays flat.
#
# Source of truth: this repo's own root (override with SKILLS_HUB)
# Mirror:           ~/.claude/skills  (override with CLAUDE_SKILLS_MIRROR)
#
# Safe to run repeatedly. Step 1 repoints any mirror symlink whose target no
# longer matches the hub copy — this also catches mirror links that used to
# point straight at a sibling `aws-skills` checkout and repoints them at
# aws/<skill> once that skill exists in the hub. Links that have no matching
# <category>/<skill>/SKILL.md in the hub (omarchy, diagnose-crash, apexlang)
# and real dirs are left alone.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HUB="${SKILLS_HUB:-$HERE}"
MIRROR="${CLAUDE_SKILLS_MIRROR:-$HOME/.claude/skills}"

[ -d "$HUB" ] || { echo "hub not found: $HUB" >&2; exit 1; }
mkdir -p "$MIRROR"

created=0 updated=0 pruned=0

# Skills listed under a stack in config/scopes.json are project-scoped: they are
# installed per project by scripts/project-agents.sh, never in the global mirror.
SCOPES="$HUB/config/scopes.json"
PROJECT_SKILLS=""
[ -f "$SCOPES" ] && PROJECT_SKILLS="$(jq -r '[.stacks[].skills[]] | unique[]' "$SCOPES")"
is_project_skill() { grep -qxF -- "$1" <<<"$PROJECT_SKILLS"; }

# 1. Link every skill found two levels deep in the hub (<category>/<skill>/SKILL.md).
#    This includes aws/<skill>/SKILL.md (cost-optimizer, iam-least-privilege,
#    lambda-patterns, sam-deploy, serverless-scanner) now that aws/ is folded
#    into the hub via git subtree.
while IFS= read -r skill_md; do
  dir="$(dirname "$skill_md")"
  name="$(basename "$dir")"
  link="$MIRROR/$name"

  is_project_skill "$name" && continue

  if [ -L "$link" ]; then
    [ "$(readlink "$link")" = "$dir" ] && continue
    rm -f "$link"; ln -s "$dir" "$link"; updated=$((updated+1))
  elif [ -e "$link" ]; then
    echo "skip $name: $link exists and is not a symlink" >&2
  else
    ln -s "$dir" "$link"; created=$((created+1))
  fi
done < <(find "$HUB" -mindepth 3 -maxdepth 3 -name SKILL.md)

# 2. Prune mirror symlinks that point into the hub but no longer resolve.
for link in "$MIRROR"/*; do
  [ -L "$link" ] || continue
  case "$(readlink "$link")" in
    "$HUB"/*) [ -e "$link" ] || { rm -f "$link"; pruned=$((pruned+1)); } ;;
  esac
done

# 2b. Remove mirror symlinks of project-scoped skills (e.g. left from when
#     everything was global, or external ones like apexlang).
for name in $PROJECT_SKILLS; do
  link="$MIRROR/$name"
  [ -L "$link" ] && { rm -f "$link"; pruned=$((pruned+1)); }
done

# 3. Ensure Antigravity config has access to the mirror.
GEMINI_SKILLS="$HOME/.gemini/config/skills"
if [ ! -e "$GEMINI_SKILLS" ]; then
  mkdir -p "$HOME/.gemini/config"
  ln -s "$MIRROR" "$GEMINI_SKILLS"
fi

echo "hub:    $HUB"
echo "mirror: $MIRROR"
echo "created $created, updated $updated, pruned $pruned"
