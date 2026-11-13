#!/usr/bin/env bash
# init.sh - overlay project-init's templates onto a project directory.
#
# Usage: init.sh --stack <react-vite|next|nestjs|node-ts|python|java-spring|kotlin-spring> --name <name>
#                 [--dir <path>] [--owner <owner>] [--project-number N]
#                 [--force] [--install] [--manifest <file>] [--claude-shim]
#
# AGENTS.md is the single source for agents; no CLAUDE.md is generated (Claude
# Code >= 2.1.277 reads AGENTS.md natively when no CLAUDE.md exists in the cwd
# or any parent directory). --claude-shim writes a CLAUDE.md that only says
# `@AGENTS.md`, for older Claude Code versions.
#
# Also installs the stack's skills/rules/MCP into .claude/ via
# scripts/project-agents.sh; --with adds extra stacks (rn,aws,python,kotlin,
# apex,docker,llm,supabase,jira).
#
# --owner defaults to `gh api user --jq .login` (if gh is authenticated),
# else `git config github.user`, else it is required.
#
# Idempotent: never overwrites an existing file unless --force. Prints
# "skip <path> (exists)" for anything it leaves alone. (.gitignore is merged
# instead of skipped, see merge_gitignore.)
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: init.sh --stack <react-vite|next|nestjs|node-ts|python|java-spring|kotlin-spring> --name <name>
               [--dir <path>] [--owner <owner>] [--project-number N]
               [--force] [--install] [--claude-shim]

  --stack            react-vite | next | nestjs | node-ts | python | java-spring |
                     kotlin-spring (required). JVM stacks: generate the project first
                     (pom.xml or build.gradle[.kts] decides Maven/Gradle)
  --name             project name, used as {{PROJECT}} (required)
  --dir              target directory (default: cwd)
  --owner            GitHub owner, used as {{OWNER}} (default: `gh api user
                     --jq .login` if gh is authenticated, else `git config
                     github.user`; required if neither resolves)
  --project-number   GitHub Project number, used as {{PROJECT_NUMBER}} (default: TBD)
  --with             extra stacks for skills/rules/MCP, comma-separated
                     (rn,aws,python,kotlin,apex,docker,llm,supabase,jira)
  --manifest         interview result (.agents/project.json schema, see
                     references/interview.md): fills --name/--stack/--with
                     when not given, writes project.json, ADRs and pending
                     decisions. --stack and --name become optional
  --claude-shim      also write CLAUDE.md containing only `@AGENTS.md` (default: no
                     CLAUDE.md; Claude Code >= 2.1.277 reads AGENTS.md natively, and a
                     CLAUDE.md in any parent directory disables that)
  --force           overwrite files that already exist
  --install          actually install the missing devDependencies (ESLint plus
                     any prettier/vitest/tsx the scripts use), write missing
                     package.json scripts, create package.json for node-ts,
                     and finish with `pnpm run format`, instead of just
                     printing the commands needed
EOF
}

# resolve_owner: gh (if authenticated) -> git config github.user -> empty.
resolve_owner() {
  local login
  if command -v gh >/dev/null 2>&1; then
    login="$(gh api user --jq .login 2>/dev/null || true)"
    [ -n "$login" ] && { printf '%s' "$login"; return; }
  fi
  login="$(git config --get github.user 2>/dev/null || true)"
  [ -n "$login" ] && { printf '%s' "$login"; return; }
  printf ''
}

STACK=""
NAME=""
DIR="$(pwd)"
OWNER=""
PROJECT_NUMBER="TBD"
WITH=""
MANIFEST=""
ORG=""
ORG_MISMATCH_OK=0
FORCE=0
INSTALL=0
CLAUDE_SHIM=0

while [ $# -gt 0 ]; do
  case "$1" in
    --stack) STACK="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --dir) DIR="$2"; shift 2 ;;
    --owner) OWNER="$2"; shift 2 ;;
    --project-number) PROJECT_NUMBER="$2"; shift 2 ;;
    --with) WITH="$2"; shift 2 ;;
    --manifest) MANIFEST="$2"; shift 2 ;;
    --org) ORG="$2"; shift 2 ;;
    --allow-org-mismatch) ORG_MISMATCH_OK=1; shift ;;
    --force) FORCE=1; shift ;;
    --install) INSTALL=1; shift ;;
    --claude-shim) CLAUDE_SHIM=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [ -n "$MANIFEST" ]; then
  # Flags win; the manifest fills what is missing. Extra stacks are passed to
  # project-agents.sh only if config/scopes.json knows them.
  _sd="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  bash "$_sd/scripts/manifest.sh" validate "$MANIFEST" >/dev/null || exit 1
  NAME="${NAME:-$(jq -r '.name' "$MANIFEST")}"
  ORG="${ORG:-$(jq -r '.org // empty' "$MANIFEST")}"
  STACK="${STACK:-$(jq -r '.stacks[0]' "$MANIFEST")}"
  if [ -z "$WITH" ]; then
    WITH="$(jq -r --slurpfile sc "$_sd/../../../config/scopes.json" \
      '[(.stacks[1:][]?), (.extras[]?)] | map(select($sc[0].stacks[.] != null)) | join(",")' "$MANIFEST")"
  fi
fi

case "$STACK" in
  react-vite|next|nestjs|node-ts|python|java-spring|kotlin-spring) ;;
  *) echo "Error: --stack must be one of react-vite|next|nestjs|node-ts|python|java-spring|kotlin-spring" >&2; exit 1 ;;
esac
[ -n "$NAME" ] || { echo "Error: --name is required" >&2; exit 1; }

if [ -z "$OWNER" ]; then
  OWNER="$(resolve_owner)"
fi
[ -n "$OWNER" ] || { echo "Error: --owner is required (gh is not authenticated and git config github.user is not set)" >&2; exit 1; }

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMON_DIR="$SKILL_DIR/templates/common"
STACK_DIR="$SKILL_DIR/templates/$STACK"
DATE="$(date +%Y-%m-%d)"

# The org's POLICIES.md is private: never copy it into a repo owned by someone else by accident.
if [ -n "$ORG" ]; then
  [[ "$ORG" =~ ^[a-z0-9][a-z0-9-]*$ ]] || { echo "Error: invalid organization name '$ORG'" >&2; exit 1; }
  _oj="$SKILL_DIR/../../../organizations/$ORG/org.json"
  if [ -f "$_oj" ] && ! jq -e --arg o "$OWNER" '(.match.gh_owners // []) | any(ascii_downcase == ($o | ascii_downcase))' "$_oj" >/dev/null; then
    echo "warning: project owner '$OWNER' is not one of organization '$ORG' GitHub owners ($(jq -r '(.match.gh_owners // []) | join(", ")' "$_oj"))." >&2
    echo "         Its private POLICIES.md would be copied into this project." >&2
    if [ "$ORG_MISMATCH_OK" != 1 ]; then
      if [ -t 0 ]; then read -r -p "Continue? [y/N] " _a; [ "${_a:-}" = y ] || { echo "aborted" >&2; exit 1; }
      else echo "Error: refusing in non-interactive mode; pass --allow-org-mismatch to proceed" >&2; exit 1; fi
    fi
  fi
fi

mkdir -p "$DIR"

# --- stack profile -----------------------------------------------------------
# Node stacks use these defaults (pnpm). Other stacks ship templates/<stack>/stack.env
# (sourced below) and may ship @<variant>/ overlays (java-spring: @maven, @gradle),
# each with its own stack.env, files and setup.sh. The variant is detected from the
# project the generator already created (pom.xml / build.gradle[.kts]).
RUNTIME=node
PKG_MANAGER="pnpm"
CMD_INSTALL="pnpm install --frozen-lockfile"
CMD_DEV="pnpm dev"; CMD_TEST="pnpm test"; CMD_LINT="pnpm lint"; CMD_TYPECHECK="pnpm typecheck"
CMD_FORMAT="pnpm format"; CMD_FORMAT_CHECK="pnpm format:check"; CMD_BUILD="pnpm build"
LINT_DESC='Lint (`--max-warnings 0` in CI)'
LINT_NOTE=' with `--max-warnings 0`'
ENFORCEMENT_FILES='`eslint.config.*`, `tsconfig*.json`, and `.github/workflows/ci.yml`'
LANG_STANDARD='- **TypeScript**: strict mode, no `any` (`unknown` + narrow at untrusted boundaries); discriminated unions for state/result variants; keep DTOs separate from domain types. Deeper: `typescript-code-quality`.'
LINT_HOOK_DESC='ESLint on every edited `.ts`/`.tsx`/`.js`/`.jsx` file'
ALLOW_CMDS=$'"Bash(pnpm lint)",\n      "Bash(pnpm typecheck)",\n      "Bash(pnpm test)",\n      "Bash(pnpm test *)",'
SKIP_COMMON=""   # common-template files this stack does not want (space-separated)
PY_PACKAGE=""    # python: importable package name (used by the smoke test template)
VARIANT=""

# shellcheck disable=SC1091
[ -f "$STACK_DIR/stack.env" ] && . "$STACK_DIR/stack.env"

variants=()
for _v in maven gradle; do [ -d "$STACK_DIR/@$_v" ] && variants+=("$_v"); done
if [ ${#variants[@]} -gt 0 ]; then
  if [ -f "$DIR/pom.xml" ]; then VARIANT=maven
  elif [ -f "$DIR/build.gradle" ] || [ -f "$DIR/build.gradle.kts" ]; then VARIANT=gradle
  else echo "Error: no pom.xml or build.gradle[.kts] in $DIR: generate the project first (SKILL step 2)" >&2; exit 1; fi
  case " ${variants[*]} " in
    *" $VARIANT "*) ;;
    *) echo "Error: $STACK supports only: ${variants[*]} (found $VARIANT)" >&2; exit 1 ;;
  esac
  # shellcheck disable=SC1091
  [ -f "$STACK_DIR/@$VARIANT/stack.env" ] && . "$STACK_DIR/@$VARIANT/stack.env"
  echo "variant: $VARIANT"
fi

# sed-safe replacement text: escape \ & and the | delimiter, newlines -> \n
sed_esc() { # escape \ & and the | delimiter, newlines -> \n (pure bash: a one-line sed with N exits before the s///)
  local v="$1"; v="${v//\\/\\\\}"; v="${v//&/\\&}"; v="${v//|/\\|}"; v="${v//$'\n'/\\n}"; printf '%s' "$v"
}
SUBS=()
PROJECT="$NAME"
for _k in PROJECT OWNER PROJECT_NUMBER STACK DATE PKG_MANAGER CMD_DEV CMD_TEST CMD_LINT CMD_TYPECHECK CMD_FORMAT CMD_FORMAT_CHECK CMD_BUILD \
          LINT_DESC LINT_NOTE ENFORCEMENT_FILES LANG_STANDARD LINT_HOOK_DESC ALLOW_CMDS PY_PACKAGE; do
  SUBS+=(-e "s|{{$_k}}|$(sed_esc "${!_k}")|g")
done

substitute() { sed "${SUBS[@]}"; }

# Copy every file under $1 (templates/common or templates/<stack>) into $DIR,
# substituting placeholders. Skips AGENTS.md and AGENTS.stack.md - those are
# assembled separately by generate_agents_md.
#
# eslint.config.js/.mjs gets one more check before the normal skip-if-exists:
# `pnpm create vite`/`pnpm create next-app` run *before* this script and may
# already have written their own eslint.config.* at the same path (vite's
# ships oxlint instead so this never collides there in practice; next's
# --eslint flag does collide). If that file doesn't carry this skill's own
# marker comment yet, it's still the generator's untouched default - overlay
# it. If it does carry the marker, a previous `init.sh` run (or the user)
# already owns it, so the normal "exists -> skip" rule applies.
# Generators (create-next-app, vite, nest) write their own .gitignore, so a
# plain skip-if-exists left the baseline entries (*.key, *secret*.json,
# .superpowers/, .env.* ...) missing. Append every template line that isn't
# already present verbatim, under one header. Idempotent: a second run finds
# every line present and adds nothing.
merge_gitignore() {
  local src="$1" dest="$2" line added=0
  local -a missing=()
  while IFS= read -r line || [ -n "$line" ]; do
    [ -z "$line" ] && continue
    [[ "$line" == \#* ]] && continue
    grep -qxF -- "$line" "$dest" || missing+=("$line")
  done < "$src"
  if [ ${#missing[@]} -eq 0 ]; then
    echo "skip .gitignore (complete)"
    return
  fi
  # Make sure the header doesn't glue onto a final line lacking a newline.
  [ -n "$(tail -c1 "$dest")" ] && printf '\n' >> "$dest"
  { printf '\n# project-init baseline\n'; printf '%s\n' "${missing[@]}"; } >> "$dest"
  added=${#missing[@]}
  echo "merged .gitignore (+$added lines)"
}

copy_template_tree() {
  local src_root="$1" skip="${2:-}"
  [ -d "$src_root" ] || return 0
  local file rel dest
  while IFS= read -r -d '' file; do
    rel="${file#"$src_root"/}"
    [ "$rel" = "AGENTS.md" ] && continue
    [ "$rel" = "AGENTS.stack.md" ] && continue
    # stack-profile files are consumed by init.sh itself, never copied as-is
    case "$rel" in stack.env|setup.sh|@*) continue ;; esac
    case " $skip " in *" $rel "*) continue ;; esac
    dest="$DIR/$rel"
    if [ -e "$dest" ] && [ "$FORCE" != 1 ]; then
      if [ "$rel" = ".gitignore" ]; then
        merge_gitignore "$file" "$dest"
        continue
      fi
      if { [ "$rel" = "eslint.config.js" ] || [ "$rel" = "eslint.config.mjs" ]; } \
        && ! grep -q "Written by the project-init skill" "$dest" 2>/dev/null; then
        : # generator's untouched default - fall through and overlay it
      else
        echo "skip $rel (exists)"
        continue
      fi
    fi
    mkdir -p "$(dirname "$dest")"
    substitute < "$file" > "$dest"
    [ -x "$file" ] && chmod +x "$dest"
    echo "wrote $rel"
  done < <(find "$src_root" -type f -print0)
}

# Build AGENTS.md from templates/common/AGENTS.md, inserting
# templates/<stack>/AGENTS.stack.md at the {{STACK_CONVENTIONS}} marker line.
#
# `create-next-app` (Next 16+) writes its own short AGENTS.md with a
# nextjs-agent-rules block before this script ever runs. That block's own
# comment says `next dev` re-adds it automatically, so overlaying this
# skill's AGENTS.md on top of it loses nothing - the block comes back the
# first time the generated project is run. Only skip if the existing file is
# already this skill's own AGENTS.md (same marker string as the template).
generate_agents_md() {
  local dest="$DIR/AGENTS.md"
  if [ -e "$dest" ] && [ "$FORCE" != 1 ] && grep -q "Single source of truth for humans and AI agents" "$dest" 2>/dev/null; then
    echo "skip AGENTS.md (exists)"
    return
  fi
  local stack_conv="$STACK_DIR/AGENTS.stack.md"
  {
    while IFS= read -r line || [ -n "$line" ]; do
      if [ "$line" = "{{STACK_CONVENTIONS}}" ]; then
        [ -f "$stack_conv" ] && cat "$stack_conv"
      else
        printf '%s\n' "$line"
      fi
    done < "$COMMON_DIR/AGENTS.md"
  } | substitute > "$dest"
  echo "wrote AGENTS.md"
}

# Optional CLAUDE.md shim (--claude-shim): the whole file is `@AGENTS.md`.
generate_claude_shim() {
  [ "$CLAUDE_SHIM" = 1 ] || return 0
  local dest="$DIR/CLAUDE.md"
  if [ -e "$dest" ] && [ "$FORCE" != 1 ]; then
    echo "skip CLAUDE.md (exists)"
    return
  fi
  printf '@AGENTS.md\n' > "$dest"
  echo "wrote CLAUDE.md"
}

# devDependencies the stack's eslint.config.*/tsconfig.json need. react-vite
# and next get the same oxlint-override treatment `pnpm create vite` already
# needed: the generator's own lint default (oxlint, or next's own
# eslint-config-next) is superseded by a flat config carrying the
# typescript-code-quality rules. `nest new` now also defaults to oxlint with
# no eslint.config.mjs at all, so nestjs gets the same override. node-ts has
# no generator, so it additionally needs a pinned `typescript` (react-vite pins
# it too: `pnpm create vite` now installs TS 7, which typescript-eslint rejects)
# (typescript-eslint doesn't support >=6.1 yet) and `@types/node` for the
# tsconfig.json this skill ships for that stack.
eslint_deps() {
  case "$STACK" in
    react-vite)
      echo eslint @eslint/js globals typescript-eslint eslint-plugin-react-hooks eslint-plugin-react-refresh eslint-plugin-react-you-might-not-need-an-effect eslint-plugin-jsx-a11y "typescript@^5" ;;
    next)
      echo eslint-plugin-react-hooks eslint-plugin-react-you-might-not-need-an-effect eslint-plugin-jsx-a11y "typescript@^5" ;;
    nestjs)
      echo eslint @eslint/js globals typescript-eslint ;;
    node-ts)
      echo eslint @eslint/js globals typescript-eslint "typescript@^5" @types/node ;;
  esac
}

# Tool binaries the settled package.json scripts call that the project doesn't
# declare yet. init.sh sets format/format:check (prettier), test (vitest) and
# node-ts's dev (tsx) but generators install none of them, so CI died on a
# missing binary. Without --install the scripts aren't written yet, so fall
# back to the canonical value for any script that's missing.
missing_tool_deps() {
  local pkg="$DIR/package.json" tool name val all=""
  for name in "${!SCRIPTS[@]}"; do
    val=""
    [ -f "$pkg" ] && val="$(jq -r --arg n "$name" '.scripts[$n] // empty' "$pkg")"
    [ -n "$val" ] || val="${SCRIPTS[$name]}"
    all+="$val"$'\n'
  done
  for tool in prettier vitest tsx; do
    grep -qE "(^|[^[:alnum:]_@/-])$tool([^[:alnum:]_-]|$)" <<<"$all" || continue
    if [ -f "$pkg" ] && jq -e --arg t "$tool" '((.dependencies // {}) + (.devDependencies // {})) | has($t)' "$pkg" >/dev/null; then
      continue
    fi
    echo "$tool"
  done
}

# pnpm >=10 fails `add`/`install` with ERR_PNPM_IGNORED_BUILDS when a
# dependency has an unreviewed build script. tsx pulls in esbuild, whose
# postinstall is only an optimization (the platform binary arrives as an
# optional dependency), so record "esbuild: false" explicitly - the same
# outcome pnpm defaults to, just acknowledged. Existing entries are kept.
ensure_esbuild_build_policy() {
  local ws="$DIR/pnpm-workspace.yaml"
  if [ ! -f "$ws" ]; then
    printf 'allowBuilds:\n  esbuild: false\n' > "$ws"
  elif grep -qE '^[[:space:]]+esbuild:' "$ws"; then
    return 0
  elif grep -q '^allowBuilds:' "$ws"; then
    sed -i 's/^allowBuilds:.*/&\n  esbuild: false/' "$ws"
  else
    printf '\nallowBuilds:\n  esbuild: false\n' >> "$ws"
  fi
  echo "set allowBuilds.esbuild = false in pnpm-workspace.yaml"
}

# One `pnpm add -D` for ESLint deps + missing tool deps (or print it).
print_or_install_deps() {
  local -a deps tools
  read -r -a deps <<<"$(eslint_deps)"
  mapfile -t tools < <(missing_tool_deps)
  deps+=("${tools[@]}")
  local cmd="pnpm add -D ${deps[*]}"
  if [ "$INSTALL" = 1 ]; then
    [[ " ${tools[*]} " == *" tsx "* ]] && ensure_esbuild_build_policy
    echo "Installing devDependencies: $cmd"
    (cd "$DIR" && pnpm add -D "${deps[@]}")
  else
    echo "Run this to install the devDependencies the generated config and scripts need:"
    echo "  $cmd"
  fi
}

# node-ts has no generator, so there may be no package.json at all. Create a
# minimal ESM one (the tsconfig is nodenext) so pnpm add and the scripts work.
ensure_node_ts_package() {
  [ "$STACK" = "node-ts" ] && [ "$INSTALL" = 1 ] && [ ! -f "$DIR/package.json" ] || return 0
  jq -n --arg n "$(printf '%s' "$NAME" | tr '[:upper:]' '[:lower:]')" \
    '{name: $n, version: "0.0.0", private: true, type: "module"}' > "$DIR/package.json"
  echo "wrote package.json"
}

# Canonical dev/test/lint/typecheck/format/format:check commands per stack.
declare -A SCRIPTS
case "$STACK" in
  react-vite)
    SCRIPTS=( [dev]="vite" [test]="vitest run --passWithNoTests" [lint]="eslint ." [typecheck]="tsc -b --noEmit" [format]="prettier --write ." ["format:check"]="prettier --check ." )
    ;;
  next)
    SCRIPTS=( [dev]="next dev" [test]="vitest run --passWithNoTests" [lint]="eslint ." [typecheck]="next typegen && tsc --noEmit" [format]="prettier --write ." ["format:check"]="prettier --check ." )
    ;;
  nestjs)
    SCRIPTS=( [dev]="nest start --watch" [test]="vitest run --passWithNoTests" [lint]='eslint "{src,apps,libs,test}/**/*.ts" --fix' [typecheck]="tsc --noEmit" [format]='prettier --write "src/**/*.ts"' ["format:check"]='prettier --check "src/**/*.ts"' )
    ;;
  node-ts)
    SCRIPTS=( [dev]="tsx src/index.ts" [test]="vitest run --passWithNoTests" [lint]="eslint ." [typecheck]="tsc --noEmit" [format]="prettier --write ." ["format:check"]="prettier --check ." )
    ;;
esac

# Report which of the six canonical scripts are missing from package.json.
# A `test` that is exactly bare `vitest` (watch mode: hangs under gh-flow.sh pr
# and exits 1 with no test files) and, for next, a `typecheck` that is exactly
# `tsc --noEmit` (misses .next/types globals like LayoutProps in CI) also
# count as needing an update.
# For react-vite/next/nestjs, a "lint" script that doesn't invoke eslint (e.g.
# the vite/nest scaffolds' default `oxlint`) counts as needing an update,
# since the generated eslint.config.js/.mjs only takes effect through eslint.
report_scripts() {
  local pkg="$DIR/package.json"
  [ -f "$pkg" ] || { echo "no package.json found at $pkg, skipping script check"; return; }

  local -a needs=()
  local name current
  for name in "${!SCRIPTS[@]}"; do
    current="$(jq -r --arg n "$name" '.scripts[$n] // empty' "$pkg")"
    if [ -z "$current" ]; then
      needs+=("$name")
    elif [ "$name" = "lint" ] && { [ "$STACK" = "react-vite" ] || [ "$STACK" = "next" ] || [ "$STACK" = "nestjs" ]; } && [[ "$current" != *eslint* ]]; then
      needs+=("$name")
    elif [ "$name" = "test" ] && [ "$current" = "vitest" ]; then
      needs+=("$name")
    elif [ "$name" = "typecheck" ] && [ "$STACK" = "next" ] && [ "$current" = "tsc --noEmit" ]; then
      needs+=("$name")
    fi
  done

  if [ ${#needs[@]} -eq 0 ]; then
    echo "package.json scripts: dev/test/lint/typecheck/format/format:check all present"
    return
  fi

  if [ "$INSTALL" = 1 ]; then
    # jq rather than `pnpm pkg set`: pnpm's property-path parser rejects the
    # colon in "format:check" (ERR_PNPM_PKG_INVALID_PROPERTY_PATH).
    local tmp
    for name in "${needs[@]}"; do
      tmp="$(mktemp)"
      jq --arg n "$name" --arg v "${SCRIPTS[$name]}" '.scripts[$n] = $v' "$pkg" > "$tmp"
      mv "$tmp" "$pkg"
      echo "set scripts.$name = ${SCRIPTS[$name]}"
    done
  else
    echo "package.json is missing (or needs eslint for) these scripts:"
    for name in "${needs[@]}"; do
      # npm pkg set, not pnpm pkg set: pnpm's property-path parser rejects
      # the colon in "format:check".
      echo "  npm pkg set \"scripts.$name=${SCRIPTS[$name]}\""
    done
  fi
}

# CI's pnpm/action-setup reads the pnpm version from "packageManager"; without
# it the action fails. Pin to the local pnpm when the field is missing.
ensure_package_manager() {
  local pkg="$DIR/package.json"
  [ -f "$pkg" ] || return 0
  [ -n "$(jq -r '.packageManager // empty' "$pkg")" ] && return 0
  local ver
  ver="$(pnpm --version 2>/dev/null)" || { echo "pnpm not found: add \"packageManager\": \"pnpm@<version>\" to package.json for CI"; return 0; }
  local tmp
  tmp="$(mktemp)"
  jq --arg v "pnpm@$ver" '.packageManager = $v' "$pkg" > "$tmp" && mv "$tmp" "$pkg"
  echo "set packageManager = pnpm@$ver"
}

# Ensure strict/noUncheckedIndexedAccess/noImplicitOverride/noFallthroughCasesInSwitch
# are set in the project's tsconfig. Delegates the actual edit to
# ensure-tsconfig-strict.js, which uses the project's own `typescript` package
# to parse the (possibly JSONC, comment-carrying) file safely and only inserts
# flags that are missing - see that script for why. node-ts isn't listed:
# templates/node-ts/tsconfig.json already ships every flag turned on.
ensure_tsconfig_strict() {
  local -a paths=()
  case "$STACK" in
    # vite's tsconfig.node.json covers vite.config.ts, which eslint lints too;
    # newer templates omit strict there (TS 6+ defaults it on) but the
    # type-aware rules still require it explicitly.
    react-vite) paths=("$DIR/tsconfig.app.json" "$DIR/tsconfig.node.json") ;;
    next|nestjs) paths=("$DIR/tsconfig.json") ;;
    node-ts) return 0 ;;
  esac

  local tsconfig_path
  for tsconfig_path in "${paths[@]}"; do
    if [ ! -f "$tsconfig_path" ]; then
      echo "no tsconfig found at $tsconfig_path, skipping strictness check"
      continue
    fi

    if [ "$INSTALL" != 1 ]; then
      echo "Run with --install to ensure strict/noUncheckedIndexedAccess/noImplicitOverride/noFallthroughCasesInSwitch are set in $(basename "$tsconfig_path")."
      continue
    fi

    node "$SKILL_DIR/scripts/ensure-tsconfig-strict.js" "$tsconfig_path" "$DIR"
  done
}

# Last step: generator output plus this skill's templates won't match
# prettier's style, and CI runs format:check - so format once now.
run_format() {
  [ "$INSTALL" = 1 ] || { echo "Run with --install to finish with 'pnpm run format' (so CI's format:check passes)."; return; }
  [ -f "$DIR/package.json" ] || return 0
  jq -e '.scripts.format != null' "$DIR/package.json" >/dev/null || return 0
  (cd "$DIR" && pnpm run format)
}

# The interview's `sdd` decision (required | light | off) changes the workflow AGENTS.md describes.
# `required` (and pending/absent) keeps the template's spec-driven text untouched.
apply_sdd() {
  [ -n "$MANIFEST" ] || return 0
  local v dest="$DIR/AGENTS.md" heading tmp
  v="$(jq -r '[.decisions[]? | select(.key == "sdd") | .value][0] // empty' "$MANIFEST")"
  case "$v" in
    light) heading='## How we work (specs for big work, with superpowers)' ;;
    off) heading='## How we work (issue-driven, with superpowers)' ;;
    *) return 0 ;;
  esac
  # only patch the template's own step 2 (a second run or a hand-edited file is left alone)
  [ -f "$dest" ] && grep -q '^2\. Non-trivial `feat`/`refactor` work' "$dest" || return 0
  tmp="$(mktemp)"
  S="$(cat "$SKILL_DIR/references/sdd/$v.md")" H="$heading" awk '
    /^2\. Non-trivial `feat`\/`refactor` work/ { print ENVIRON["S"]; next }
    /^## How we work \(spec-driven, with superpowers\)$/ { print ENVIRON["H"]; next }
    { print }' "$dest" > "$tmp" && cat "$tmp" > "$dest"; rm -f "$tmp"
  echo "AGENTS.md: workflow adjusted for sdd=$v"
}

# Interview result (references/interview.md): project.json, ADRs, pending decisions.
# Runs before run_format so the generated files get formatted with the rest.
apply_manifest() {
  [ -n "$MANIFEST" ] || return 0
  bash "$SKILL_DIR/scripts/manifest.sh" apply "$MANIFEST" "$DIR"
}

# Non-node stacks: the commands scripts/gh-flow.sh pr and verify-ci.sh run, kept in
# one place inside the project (.agents/stack.env). Node projects use package.json.
write_stack_env() {
  local dest="$DIR/.agents/stack.env"
  if [ -e "$dest" ] && [ "$FORCE" != 1 ]; then echo "skip .agents/stack.env (exists)"; return; fi
  mkdir -p "$DIR/.agents"
  {
    echo "# Written by project-init. Commands for scripts/gh-flow.sh pr and verify-ci.sh."
    for k in RUNTIME CMD_INSTALL CMD_FORMAT_CHECK CMD_LINT CMD_TYPECHECK CMD_TEST CMD_BUILD; do
      printf '%s=%q\n' "$k" "${!k}"
    done
  } > "$dest"
  echo "wrote .agents/stack.env"
}

# Stack-specific build-file patching (formatter/linter config): setup.sh at the stack
# level, then the variant's. They get DIR and INSTALL; without --install they only print.
run_stack_setup() {
  local s
  for s in "$STACK_DIR/setup.sh" "${VARIANT:+$STACK_DIR/@$VARIANT/setup.sh}"; do
    [ -n "$s" ] && [ -f "$s" ] && DIR="$DIR" INSTALL="$INSTALL" SKILL_DIR="$SKILL_DIR" bash "$s"
  done
  return 0
}

run_stack_format() {
  [ "$INSTALL" = 1 ] || { echo "Run with --install to finish with '$CMD_FORMAT' (so CI's format check passes)."; return 0; }
  (cd "$DIR" && bash -c "$CMD_FORMAT")
}

# Skills, rules, MCP and packs (commands, keyword table, critical.json) from the hub.
# Runs before the formatters so the copied markdown gets formatted with the rest.
install_agent_scope() {
  local hub; hub="$(cd "$SKILL_DIR/../../.." && pwd)"
  [ -x "$hub/scripts/project-agents.sh" ] || return 0
  bash "$hub/scripts/project-agents.sh" --stack "$STACK${WITH:+,$WITH}" ${MANIFEST:+--manifest "$MANIFEST"} ${ORG:+--org "$ORG"} --dir "$DIR"
}

[ "$RUNTIME" = node ] && ensure_node_ts_package
[ -n "$VARIANT" ] && copy_template_tree "$STACK_DIR/@$VARIANT"
copy_template_tree "$STACK_DIR"
copy_template_tree "$COMMON_DIR" "$SKIP_COMMON"
generate_agents_md
generate_claude_shim
apply_sdd
if [ "$RUNTIME" = node ]; then
  report_scripts
  ensure_package_manager
  print_or_install_deps
  ensure_tsconfig_strict
else
  write_stack_env
  run_stack_setup
fi
install_agent_scope
apply_manifest
if [ "$RUNTIME" = node ]; then run_format; else run_stack_format; fi
