#!/usr/bin/env bash
# Build config/rulesync/.rulesync/ from this hub's canonical sources, so
# `rulesync generate` has something to read.
#
# .rulesync/ is a build artifact (gitignored), rebuilt every time:
#   - rules/overview.md   <- config/AGENTS.md            (root rule)
#   - rules/<name>.md     <- config/rules/<name>.md       (non-root rules;
#                            `paths:` frontmatter becomes rulesync `globs:`)
#   - skills/<name>       <- symlink to the hub skill dir (no transformation
#                            needed: SKILL.md frontmatter is already in the
#                            format rulesync/Claude Code skills expect)
#
# Run directly, or via `install.sh --with-rulesync`.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HUB="$(cd "$HERE/../.." && pwd)"
OUT="$HERE/.rulesync"

rm -rf "$OUT"
mkdir -p "$OUT/rules" "$OUT/skills"

# -- root rule: config/AGENTS.md -------------------------------------------
python3 - "$HUB/config/AGENTS.md" "$OUT/rules/overview.md" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
body = open(src, encoding="utf-8").read()
frontmatter = (
    "---\n"
    "root: true\n"
    'targets: ["*"]\n'
    'description: "Shared global agent instructions — applied by every coding agent"\n'
    'globs: ["**/*"]\n'
    "---\n\n"
)
open(dst, "w", encoding="utf-8").write(frontmatter + body)
PY

# -- non-root rules: config/rules/*.md --------------------------------------
for f in "$HUB"/config/rules/*.md; do
  name="$(basename "$f" .md)"
  python3 - "$f" "$OUT/rules/$name.md" "$name" <<'PY'
import re
import sys

src, dst, name = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(src, encoding="utf-8").read()

m = re.match(r"^---\n(.*?)\n---\n\n?(.*)$", text, re.DOTALL)
if not m:
    raise SystemExit(f"{src}: expected a --- frontmatter block")
frontmatter, body = m.group(1), m.group(2)

paths = re.findall(r'^\s*-\s*"(.*)"\s*$', frontmatter, re.MULTILINE)
if not paths:
    raise SystemExit(f"{src}: no `paths:` entries found in frontmatter")

title_match = re.search(r"^#\s+(.+)$", body, re.MULTILINE)
title = title_match.group(1).strip() if title_match else name

globs = ", ".join(f'"{p}"' for p in paths)
new_frontmatter = (
    "---\n"
    "root: false\n"
    'targets: ["*"]\n'
    f'description: "{title} conventions — applied when matching files are touched"\n'
    f"globs: [{globs}]\n"
    "---\n\n"
)
open(dst, "w", encoding="utf-8").write(new_frontmatter + body)
PY
done

# -- skills: symlink into .rulesync/skills (no content duplication) --------
for name in project-init typescript-code-quality react-component-validator; do
  src="$(find "$HUB/skills" -mindepth 2 -maxdepth 2 -type d -name "$name" | head -1)"
  if [ -z "$src" ]; then
    echo "build.sh: skill not found: $name" >&2
    exit 1
  fi
  ln -s "$src" "$OUT/skills/$name"
done

echo "built: $OUT"
