#!/usr/bin/env bash
# Update the roadmap "Current stage" line in the active profile (the single source
# of truth), regenerate ~/.codex/AGENTS.md, then commit, merge and push the change.
#
# Usage: update-stage.sh "<stage text>"   (without the "as of" date; added automatically)
#        update-stage.sh --dry-run "<stage text>"
set -euo pipefail

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && { DRY_RUN=1; shift; }
stage="${1:-}"
[[ -n "$stage" ]] || { echo "usage: $0 [--dry-run] \"<stage text>\"" >&2; exit 2; }

hub=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)
cfg_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
profile_file="$cfg_dir/agents-config/profile"
[[ -f "$profile_file" ]] || profile_file="$cfg_dir/agent-config/profile" # legacy path
profile_name=$(cat "$profile_file" 2>/dev/null || true)
[[ -n "$profile_name" ]] || { echo "no active profile; run install.sh --profile <name> first" >&2; exit 1; }
profile_rel="config/profiles/${profile_name}.md"
profile="$hub/$profile_rel"
grep -q '^- Current stage (as of ' "$profile" || { echo "no '- Current stage (as of ...)' line in $profile_rel" >&2; exit 1; }

new_line="- Current stage (as of $(date +%F)): ${stage}"
if (( DRY_RUN )); then
  echo "would replace in $profile_rel:"
  grep '^- Current stage (as of ' "$profile"
  echo "$new_line"
  exit 0
fi

cd "$hub"
default=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
default=${default:-main}
[[ "$(git branch --show-current)" == "$default" ]] || { echo "not on $default; aborting" >&2; exit 1; }
git diff --quiet -- "$profile_rel" && git diff --cached --quiet || { echo "uncommitted changes in $profile_rel or index; aborting" >&2; exit 1; }
git pull -q origin "$default"

# awk via ENVIRON (not sed or -v) so the stage text needs no escaping.
tmp=$(mktemp)
NEW_LINE="$new_line" awk '/^- Current stage \(as of /{print ENVIRON["NEW_LINE"]; next} {print}' "$profile" > "$tmp"
cat "$tmp" > "$profile"; rm -f "$tmp"
git diff --quiet -- "$profile_rel" && { echo "stage already up to date"; exit 0; }

"$hub/install.sh" --profile "$profile_name" >/dev/null

branch="fix/roadmap-stage-$(date +%Y%m%d-%H%M%S)"
git checkout -q -b "$branch"
git add -- "$profile_rel"
git commit -q -m "docs(profile): update roadmap stage" -m "$stage"
git checkout -q "$default"
git merge -q --no-ff "$branch" -m "Merge $branch"
git branch -q -d "$branch"
git push -q origin "$default"

# Mirror clones listed in the profile ("mirror clones ... `~/path`") get a pull.
grep -i 'mirror clones' "$profile" | grep -o '`~/[^`]*`' | tr -d '`' | while read -r p; do
  dir="${p/#\~/$HOME}"
  if [[ -d "$dir/.git" ]]; then git -C "$dir" pull -q && echo "pulled $p"; fi
done

echo "stage updated: $new_line"
