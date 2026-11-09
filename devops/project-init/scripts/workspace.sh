#!/usr/bin/env bash
# workspace.sh - set up the agent layer of a multi-repo workspace: a plain folder (not a git repo)
# that holds several repos side by side (e.g. a frontend and a backend of one product).
#
# Usage: workspace.sh --dir <workspace> --name <slug> --repo <dir>:<role>:<stack> [--repo ...]
#                     [--org <name>] [--comm "<how the repos talk>"] [--cross "<cross-repo flow>"]
#                     [--dry-run]
#
#   --repo   a child repo of the workspace: directory name, role (frontend, backend, ...) and stack
#            (a config/scopes.json stack or "-"). At least 2.
#   --org    organization (organizations/<name>, see organizations/README.md). The workspace config then
#            lives in that private repo at organizations/<name>/workspaces/<slug>/ and the workspace gets
#            symlinks to it, so nothing company-specific enters this public repo and the config is
#            versioned. Org skills and POLICIES.md are installed there via project-agents.sh --no-packs.
#   without --org: the files are written in the workspace folder itself, which becomes its own local git
#            repo (the child repos are git-ignored). No remote, no commit: the user decides those.
#
# Writes AGENTS.md (marker "<!-- workspace-init -->"), CLAUDE.md (@AGENTS.md). Never overwrites a file
# that has real content: an existing AGENTS.md without the marker is left alone and reported.
# The interview (repos, roles, how they talk, cross-repo flow, org) is done by the project-init skill;
# this script only receives the answers.
set -euo pipefail

HUB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DIR="" NAME="" ORG="" COMM="" CROSS="" DRY=0
REPOS=()
die() { echo "Error: $*" >&2; exit 1; }
valid_name() { local LC_ALL=C; [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]]; }
valid_dir() { local LC_ALL=C; [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; }

while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIR="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --repo) REPOS+=("$2"); shift 2 ;;
    --org) ORG="$2"; shift 2 ;;
    --comm) COMM="$2"; shift 2 ;;
    --cross) CROSS="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown flag: $1" ;;
  esac
done

# ---------------------------------------------------------------- preflight
[ -n "$DIR" ] && [ -d "$DIR" ] || die "--dir must be an existing directory"
DIR="$(cd "$DIR" && pwd)"
valid_name "$NAME" || die "--name must be lowercase letters, digits and dashes"
[ "${#REPOS[@]}" -ge 2 ] || die "a workspace needs at least 2 --repo entries"
# A git repo is only acceptable when it is our own workspace repo (re-run): AGENTS.md carries the marker.
if [ "$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null || true)" = "$DIR" ] \
   && ! grep -q 'workspace-init' "$DIR/AGENTS.md" 2>/dev/null; then
  die "$DIR is itself a git repo: workspace mode is for a folder that holds repos"
fi

ROWS=""
REPO_DIRS=()
for r in "${REPOS[@]}"; do
  IFS=: read -r rd role stack <<<"$r"
  valid_dir "${rd:-}" || die "invalid repo directory in --repo '$r'"
  [ -n "${role:-}" ] || die "--repo '$r' needs a role (<dir>:<role>:<stack>)"
  [ -e "$DIR/$rd/.git" ] || die "$DIR/$rd is not a git repo"
  parts=()
  [ -f "$DIR/$rd/AGENTS.md" ] && parts+=("AGENTS.md")
  [ -f "$DIR/$rd/CLAUDE.md" ] && parts+=("CLAUDE.md")
  [ -d "$DIR/$rd/.claude/skills" ] && parts+=(".claude/skills")
  own="-"
  [ "${#parts[@]}" -gt 0 ] && own="$(printf '%s, ' "${parts[@]}")" && own="${own%, }"
  ROWS+="| \`$rd\` | $role | ${stack:--} | $own |"$'\n'
  REPO_DIRS+=("$rd")
done

if [ -n "$ORG" ]; then
  valid_name "$ORG" || die "invalid organization name '$ORG'"
  OD="$HUB/organizations/$ORG"
  [ -f "$OD/org.json" ] || die "organization '$ORG' is not installed (scripts/orgs.sh add)"
  bash "$HUB/scripts/orgs.sh" validate "$OD" >/dev/null || die "organization '$ORG' does not validate"
  SRC="$OD/workspaces/$NAME"
else
  SRC="$DIR"
fi

say() { if [ "$DRY" -eq 1 ]; then echo "[dry-run] $*"; else echo "$*"; fi; }
run() { if [ "$DRY" -eq 1 ]; then echo "  [dry-run] $*"; else "$@"; fi; }

# ---------------------------------------------------------------- AGENTS.md / CLAUDE.md
[ -n "$COMM" ] || COMM="_Not described yet: say how the repos talk (HTTP API, events, shared types) and where the contract lives._"
if [ -z "$CROSS" ]; then
  CROSS="1. Settle the contract change first (API, events, shared types) and write it down in one place.
2. One branch per repo, same slug, each cut from that repo's own base branch (never commit on a base branch).
3. Change the provider first (usually the backend), then the consumer; keep both PRs linked.
4. Each repo's own rules (AGENTS.md / CLAUDE.md, CI, PR flow) apply when you work inside it."
fi
POL=""
if [ -n "$ORG" ]; then
  POL="## Policies

Organization \`$ORG\`: read \`.agents/POLICIES.md\` before working in any repo here. Its skills are in \`.claude/skills\`;
the stack skills of each repo stay inside that repo.

"
fi

agents_md="<!-- workspace-init -->
# $NAME workspace

A folder that holds ${#REPOS[@]} repos side by side; it is not a code repo. Open Claude here for work that crosses repos;
for code changes, work inside the right repo and follow that repo's own AGENTS.md / CLAUDE.md.

## Repos

| Repo | Role | Stack | Own agent config |
|---|---|---|---|
${ROWS%$'\n'}

## How they talk

$COMM

## Cross-repo changes

$CROSS

${POL}## Notes

- Stack skills and rules belong to each repo (installed by \`project-agents.sh\` there), not to this folder.
- Never commit secrets; each repo keeps its own \`.env\` ignored."

write_guarded() { # <path> <content> <marker>: create, refresh our own file, never clobber real content
  local f="$1" content="$2" marker="$3"
  if [ -e "$f" ] && ! grep -q "$marker" "$f" 2>/dev/null; then
    say "skip $f (exists with its own content; merge by hand)"; return 0
  fi
  say "write $f"
  if [ "$DRY" -eq 0 ]; then mkdir -p "$(dirname "$f")"; printf '%s\n' "$content" >"$f"; fi
}

say "workspace: $NAME ($DIR) repos: ${REPO_DIRS[*]}${ORG:+ org: $ORG}"
write_guarded "$SRC/AGENTS.md" "$agents_md" 'workspace-init'
write_guarded "$SRC/CLAUDE.md" "<!-- workspace-init -->
@AGENTS.md" 'workspace-init'

# ---------------------------------------------------------------- org skills / policies
if [ -n "$ORG" ]; then
  say "org: installing skills and POLICIES.md into $SRC (no packs, no stack filter)"
  run bash "$HUB/scripts/project-agents.sh" --org "$ORG" --no-packs --dir "$SRC" $([ "$DRY" -eq 1 ] && echo --dry-run)
  # link the versioned source into the workspace folder (never over a real file)
  for item in AGENTS.md CLAUDE.md .claude .agents; do
    [ -e "$SRC/$item" ] || [ "$DRY" -eq 1 ] || continue
    if [ -L "$DIR/$item" ] && [ "$(readlink "$DIR/$item")" = "$SRC/$item" ]; then say "ok   $DIR/$item (already linked)"; continue; fi
    if [ -e "$DIR/$item" ] || [ -L "$DIR/$item" ]; then say "skip $DIR/$item (exists; not replaced)"; continue; fi
    say "link $DIR/$item -> $SRC/$item"
    run ln -s "$SRC/$item" "$DIR/$item"
  done
  say "next: review $SRC, then commit it in the organization repo (private) with the user's OK:"
  say "  git -C $OD add workspaces/$NAME && git -C $OD commit -m 'feat: workspace $NAME'"
else
  # personal workspace: its own local repo, child repos ignored. No commit, no remote.
  if [ ! -d "$DIR/.git" ]; then say "git init $DIR"; run git -C "$DIR" init -q; fi
  gi="$DIR/.gitignore"
  for rd in "${REPO_DIRS[@]}"; do
    if ! grep -qxF "/$rd/" "$gi" 2>/dev/null; then say "ignore /$rd/ in .gitignore"; [ "$DRY" -eq 1 ] || printf '/%s/\n' "$rd" >>"$gi"; fi
  done
  say "next: review the files, then commit locally; create a remote only with the user's OK."
fi
say "done."
