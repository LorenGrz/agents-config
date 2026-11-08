---
name: project-init
description: Use this skill when starting a new project or repo, or when adopting an existing one that this skill didn't generate. For new repos, scaffolds a repository that works with any AI agent (Codex, Cursor, Claude) and humans - a single AGENTS.md source of truth, CLAUDE.md as a thin pointer, .claude/ with the superpowers plugin and project hooks, a spec-driven workflow, branch flow feat|fix|refactor/<issue>-<slug> to dev with squash merge, a GitHub Project v2 per repo, and real enforcement via ESLint, a git pre-push hook, and CI. For existing repos, scripts/adopt.sh documents their current git workflow (branch/merge/CI reality, docs-only, no new hooks/CI/enforcement) and fills in the same AGENTS.md/CLAUDE.md/.agents/CONTEXT.md/docs/decisions documentation layer. For a plain folder that groups several repos of one product (e.g. frontend + backend), workspace mode (scripts/workspace.sh) creates the workspace-level AGENTS.md.
---

# Project Init

Scaffold a new repo once, correctly, instead of re-deciding workflow per project.

## Workflow

1. **Interview**: follow `references/interview.md` (org, stack, backend/frontend architecture, data and auth, testing and deploy, SDD), plus project name and visibility (default `public`). Critical answers are never defaulted: "no sé" goes to `pending`. Write the answers as a manifest (schema in that file) outside the target dir, e.g. in the session scratchpad, and check it with `bash scripts/manifest.sh validate <manifest>`. Remind the user: never commit secrets.

2. **Generate the app, if the target dir is empty**, with the stack's own official generator in its non-interactive form, then overlay this skill's templates. The dir/package name must be lowercase (npm rule) and may differ from the GitHub repo name (repo `Disfrazate`, dir/package `disfrazate`); `--name` below is the **GitHub repo name**:
   - react-vite: `pnpm create vite@latest <dir> --template react-ts --no-interactive --no-immediate`, then `pnpm -C <dir> install` (run from the parent dir; vite resolves `<dir>` relative to cwd)
   - next: `pnpm create next-app@latest <dir> --yes --use-pnpm --disable-git`
   - nestjs: `pnpm dlx @nestjs/cli new <dir> --directory <dir> --package-manager pnpm --skip-git --no-observe`
   - node-ts: just `mkdir <dir>`; `init.sh --install` creates `package.json` and `src/index.ts`
   - python: `uv init --package --vcs none <dir>`
   - java-spring / kotlin-spring: Spring Initializr (`curl -fsS https://start.spring.io/starter.zip -d type=<t> -d language=<l> -d javaVersion=21 -d groupId=<g> -d artifactId=<dir> -d name=<dir> -d packageName=<g>.<pkg> -d dependencies=<deps> -o x.zip && unzip -q x.zip -d <dir>`). `type`: `maven-project` or `gradle-project` (Java), `gradle-project-kotlin` with `language=kotlin` (Kotlin supports Gradle only). `dependencies` comes from the interview (e.g. `web,validation,actuator`; `data-jpa,postgresql,flyway` for Postgres + Flyway). `init.sh` picks Maven or Gradle from the generated project (`pom.xml` / `build.gradle[.kts]`) and adds Spotless.
   Then run:
   ```
   bash scripts/init.sh --manifest <manifest> --dir <path> [--owner <owner>] [--project-number N] --install
   ```
   `--manifest` supplies `--name`, `--stack` (its first stack) and `--with`, and writes `.agents/project.json`, one ADR per decision and the pending decisions into `.agents/CONTEXT.md`. Without a manifest, pass `--stack <stack> --name <repo-name> [--with aws,llm,supabase,...]` as before.
   `--owner` defaults to `gh api user --jq .login` (if `gh` is authenticated), then `git config github.user`; pass it explicitly if neither resolves.
   Without `--install`, `init.sh` only prints the commands needed (devDependencies, missing package.json scripts); nothing is installed or written to `package.json` scripts.
   **Stack profiles.** Node stacks use pnpm defaults inside `init.sh`. Other stacks ship `templates/<stack>/stack.env` (commands, lint/format text, allowed commands), optional `@maven/` / `@gradle/` variant overlays and a `setup.sh` that patches the build file (Spotless, ruff/mypy/pytest). Stack files win over `templates/common` (`SKIP_COMMON` drops the ones that don't apply). For non-node stacks `init.sh` writes `.agents/stack.env`, which `scripts/gh-flow.sh pr` and `verify-ci.sh` use instead of `package.json` scripts.

3. **Local git setup** (do this, do not delegate it):
   - `git init -b main` if the directory is not already a repo.
   - Confirm `.gitignore` exists and covers: `node_modules/`, `.pnp*`, `.venv/`, `__pycache__/`, `*.py[cod]`, `.env` and `.env.*` (keep `!.env.example`), `*.pem`, `*.key`, `*credentials*.json`, `*secret*.json`, `dist/`, `build/`, `out/`, `.next/`, `.turbo/`, `coverage/`, `*.tsbuildinfo`, `*.log`, `.cache/`, `tmp/`, `.DS_Store`, `Thumbs.db`, `.idea/`, `.vscode/*` (keep `!.vscode/extensions.json`), `.superpowers/`. `init.sh` merges any missing baseline lines into the generator's `.gitignore`; only fix it if something is still missing.
   - `git config core.hooksPath .githooks`
   - `git add -A && git commit -m "chore: initial project setup"`
   - `bash scripts/verify-ci.sh --dir <path>` - clones the committed HEAD and runs CI's steps (install --frozen-lockfile, format:check, lint, typecheck, test, build). Fix anything red before step 4.

4. **External steps, one at a time, each confirmed by the user before running.** Never hand these to a background agent - they touch GitHub and real resources. `--owner` defaults the same way as `init.sh`'s (gh login, then `git config github.user`); pass it explicitly if neither resolves.
   ```
   bash scripts/bootstrap-github.sh repo     [--owner <owner>] --name <name> --visibility public
   bash scripts/bootstrap-github.sh dev      [--owner <owner>] --name <name>
   bash scripts/bootstrap-github.sh settings [--owner <owner>] --name <name>
   bash scripts/bootstrap-github.sh labels   [--owner <owner>] --name <name>
   bash scripts/bootstrap-github.sh project  [--owner <owner>] --name <name>
   bash scripts/bootstrap-github.sh protect  [--owner <owner>] --name <name>
   ```
   `project` creates the Project, then replaces `TBD`/`{{PROJECT_NUMBER}}` in the repo (`.github/ISSUE_TEMPLATE/*.yml`, `AGENTS.md`, `.agents/CONTEXT.md`), commits it (`chore: set project number to N`) and pushes the current branch itself - no manual commit.
   Run with `--dry-run` first any time you want to preview the exact `gh`/`git` commands without touching GitHub.

5. **Verify and report**: repo URL, dev as default branch, Project URL, CI green on the first PR.

## Daily workflow (what the generated AGENTS.md documents)

Everything starts as an issue in the Project. Non-trivial `feat`/`refactor` work goes through superpowers `brainstorming` -> a spec in `docs/superpowers/specs/` -> `writing-plans` -> a plan in `docs/superpowers/plans/`. `fix` work goes through `systematic-debugging` and only gets a spec if behavior changes. Then `scripts/gh-flow.sh start <type> <slug> --issue N`, implement with `subagent-driven-development` + `test-driven-development`, `verification-before-completion`, `scripts/gh-flow.sh pr`, wait for CI, `scripts/gh-flow.sh merge`. Base branch is always `dev`; `main` only moves via `scripts/gh-flow.sh release`. Agents without superpowers installed follow the same steps manually.

The generated `AGENTS.md` is the source of truth for the new repo - read it there, not here, once a project exists. If the code and the doc disagree, fix the doc.

## Standards and enforcement

Every scaffolded repo carries Loren's engineering standards two ways: as conventions any AI reads (`AGENTS.md`'s "Engineering standards" section plus the stack's `AGENTS.stack.md`), and as mechanical enforcement wherever a tool can actually check it:

- **ESLint** (`eslint.config.*`, `typescript-eslint@8.71.1` as of writing): `no-explicit-any`, `no-floating-promises`, `no-misused-promises`, `consistent-type-imports`, `switch-exhaustiveness-check`, `no-unnecessary-condition` (all type-aware via `projectService: true`), plus `eqeqeq` and `no-console` (errors, allowing `console.warn`/`console.error`). react-vite/next also get `eslint-plugin-jsx-a11y@6.10.2` recommended rules and keep the existing zero-useEffect config (`eslint-plugin-react-hooks` + `eslint-plugin-react-you-might-not-need-an-effect`).
  - react-vite and nestjs: `pnpm create vite` and `nest new` both default to `oxlint` with no ESLint config at all now - this skill writes a flat `eslint.config.js`/`.mjs` that supersedes it (same pattern the zero-useEffect override already used for vite). `--install` points `lint` at `eslint` instead of the generator's `oxlint` default.
  - next: `eslint-config-next` already registers the `jsx-a11y` plugin itself (a handful of rules at `warn`). The template merges in `eslint-plugin-jsx-a11y`'s recommended **rules** object only, not its flat-config object (which would try to re-register the same plugin and crash with "Cannot redefine plugin"), and does not need `typescript-eslint` as a direct dependency - `eslint-config-next/typescript` already registers `@typescript-eslint`.
  - node-ts: has no generator, so the template ships the config outright, plus a pinned `typescript@^5` (typescript-eslint 8.x doesn't yet support TypeScript 7, which is now `npm`'s `latest` tag) and `@types/node`.
- **tsconfig strictness**: `init.sh --install` runs `scripts/ensure-tsconfig-strict.js` to turn on `strict`, `noUncheckedIndexedAccess`, `noImplicitOverride`, and `noFallthroughCasesInSwitch` in the project's tsconfig (`tsconfig.app.json` for react-vite, `tsconfig.json` for next/nestjs; node-ts's template ships all four already). All four flags were verified against the stock `pnpm create vite@latest --template react-ts`, `pnpm create next-app@latest`, and `pnpm dlx @nestjs/cli new` scaffolds (October 2026) - none needed to be skipped. The script uses the project's own installed `typescript` to parse the file (comments and all) before deciding what's missing, and only inserts the missing flags as text so existing comments/formatting survive; without `--install` it only prints what it would do.
- **CI** (`.github/workflows/ci.yml`): the `ci` job (kept as-is, branch protection depends on that check name) gains a non-blocking `pnpm audit --audit-level high` step (`continue-on-error: true`) and a `docs-check` step (see below). A new `secret-scan` job runs `gitleaks/gitleaks-action@v3` with `fetch-depth: 0` - free for personal GitHub accounts, no `GITLEAKS_LICENSE` needed. (The task that commissioned this used `@v2`; v2 is EOL as of September 2026 per the project's own README, so this scaffolds `@v3` instead - same inputs/behavior, different Node runtime underneath.)

## Documentation layer

Every scaffolded repo carries enough documentation for a new agent session to work from docs alone: `AGENTS.md`'s "Documentation map" points, in order, to `.agents/CONTEXT.md` (current stack/architecture snapshot), `docs/plans/HANDOFF.md` (current state + how to resume mid-flight work), `docs/architecture.md` (overview/modules/data model/flows/env/deploy skeleton), `docs/decisions/` (ADRs for trade-offs, starting at `0001-record-architecture-decisions.md`, new ones copied from `0000-template.md`), `docs/superpowers/specs|plans/` (the existing spec-driven workflow - every plan and worker spec created in a session, not only the first), and `docs/prompts.md` (every AI prompt the app sends, verbatim, with its history; deleted if the app calls no model). `AGENTS.md`'s "Documentation rules" section says when each gets written and keeps `AGENTS.md` itself capped at ~150 lines. The PR template checklist and a non-blocking `docs-check` step in CI (`scripts/docs-check.sh`, warns via `::warning::` when a PR touches deps/env/docker/workflows/top-level folders without touching docs) nudge toward keeping it current; neither blocks a merge.

## Workspace mode

Use `scripts/workspace.sh` when the target is a plain folder (not a git repo) that holds **2 or more repos side by side** - a frontend and a backend of one product, say. Per-repo setup (init or adopt) is unchanged and stays inside each repo; the workspace layer only adds what is shared: a map of the repos, how they talk, the cross-repo flow and, for an organization, its policies and skills.

1. **Recognize it**: the folder has no `.git` and no `AGENTS.md`, and the user confirms it is one product. A workspace is marked by its own `AGENTS.md` (first line `<!-- workspace-init -->`); never infer it from the folder shape alone (a folder of unrelated projects is not a workspace).
2. **Interview** (ask, don't assume): which child dirs are repos and the role of each (frontend, backend, ...); each one's stack (a `config/scopes.json` stack or `-`); how the repos talk (HTTP API, events, shared types) and where the contract lives; the cross-repo flow if it differs from the default; the organization, if any (propose the detected one with `bash scripts/orgs.sh detect <owner>`).
3. **Dry run first, then apply**:
   ```
   bash scripts/workspace.sh --dir <workspace> --name <slug> --repo <dir>:<role>:<stack> --repo ... [--org <name>] [--comm "<text>"] [--cross "<text>"] --dry-run
   ```
   - **With `--org`**: the config is written to `organizations/<org>/workspaces/<slug>/` (the org's private repo) and the workspace folder gets symlinks to it, so it is versioned and nothing company-specific enters this public repo. Org skills and `POLICIES.md` are installed there with `project-agents.sh --org --no-packs`.
   - **Without `--org`**: files go in the folder itself, which becomes its own local git repo (child repos git-ignored). No commit and no remote are made; the user decides those.
4. **Never overwrite**: an existing `AGENTS.md`/`CLAUDE.md` without the marker is skipped and reported; merge by hand. Re-running refreshes only files that carry the marker.
5. Show the generated files and the commit command; commit in the org repo (or the local workspace repo) and create any remote only with the user's OK.

Open Claude in the workspace folder for cross-repo work. For code changes, work inside the right repo: its own `AGENTS.md`, `.claude/skills` and hooks apply there. SessionStart tells the agent when it starts in a workspace folder.

## Adopting an existing repo

Use `scripts/adopt.sh` instead of `init.sh` when the repo was **not** generated by this skill and already has its own history, CI, and flow. Adopt is docs-only: it never adds hooks, CI, ESLint, pre-push, or branch protection - any of those would break whatever the repo already does. It documents the repo's CURRENT reality (a "Workflow contract" table that may legitimately say "nothing (convention only)" in every row) and only RECOMMENDS stronger enforcement in its output, capped at 3 bullets.

1. Create a worktree from the repo's default branch - never touch the user's own working tree/branch, which may be dirty or mid-task:
   ```
   git -C <repo> fetch origin
   git -C <repo> worktree add ../<repo>-adopt -b docs/workflow-contract origin/<default>
   ```
   (`<default>` is whatever `git symbolic-ref --short refs/remotes/origin/HEAD` reports, `main`/`master` otherwise.)
2. Run `bash scripts/adopt.sh --dir ../<repo>-adopt` (add `--dry-run` to preview, `--json` for machine-readable output). It detects the default/dev branch, branch protection, merge settings, branch naming and commit-message history, CI, hooks, PR/issue templates, and package manager/scripts, then fills in or creates `AGENTS.md`, `CLAUDE.md`, `.agents/CONTEXT.md`, `docs/decisions/{0000,0001}-*.md`, and `docs/plans/HANDOFF.md` - never overwriting a file that already carries real content. Idempotent: a second run makes no changes.
3. Review the diff in the worktree, especially the generated "Workflow contract" table - fix anything detection got wrong before committing.
4. Commit there: `git -C ../<repo>-adopt add AGENTS.md CLAUDE.md .agents docs && git -C ../<repo>-adopt commit -m "docs: add workflow contract and agent docs"`.
5. Push and land the change following the **repo's own** workflow, not this skill's: open a PR if the repo already uses PRs or has branch protection, otherwise `git merge --no-ff` straight into the default branch.
6. Remove the worktree: `git -C <repo> worktree remove ../<repo>-adopt` (and delete the branch if it wasn't merged with `--no-ff` locally first).

## Notes

- `init.sh` never overwrites an existing file unless `--force`; it prints `skip <path> (exists)` instead. Safe to re-run (verified by diffing the tree before/after a second run with no flags changed). Two files are a deliberate exception: `eslint.config.js`/`.mjs` and `AGENTS.md` still get overlaid even if a file already exists there, as long as that file doesn't carry this skill's own marker text yet - `create-next-app --eslint` writes its own `eslint.config.mjs`, and Next 16+ also writes a short `AGENTS.md` (regenerated by `next dev` regardless, per its own comment), both at the exact paths this skill needs to own. Once this skill's version is in place (marker present), normal skip-if-exists behavior resumes.
- `nest new`'s current scaffold ships Vitest, not Jest (`init.sh`'s default `test` script for nestjs follows suit: `vitest run --passWithNoTests`, only used when the generator's own `package.json` is missing a `test` script, which it currently never is).
- CI's lint step is `pnpm run --if-present lint --max-warnings 0`, with no `--` separator before the flag: the installed pnpm (12.5.1 as of writing) forwards every token after the script name verbatim, including a literal `--`, which breaks `eslint`'s arg parsing if one is added back.
- `bootstrap-github.sh all` only runs with `--dry-run` (refuses otherwise) - the real sequence is always confirmed step by step per item 4.
- `.gitignore` is the other exception to skip-if-exists: generators write their own, so `init.sh` appends every template line not already present under a `# project-init baseline` header (`merged .gitignore (+N lines)`, or `skip .gitignore (complete)` on re-run).
- `init.sh --install` adds any tool the scripts call but the project doesn't declare (`prettier`, `vitest`, `tsx`) to the same `pnpm add -D` as the ESLint deps, writes `pnpm-workspace.yaml` `allowBuilds.esbuild: false` when `tsx` comes in (pnpm otherwise aborts with `ERR_PNPM_IGNORED_BUILDS`), and ends with `pnpm run format` so CI's `format:check` passes. `.prettierignore` skips `pnpm-lock.yaml`.
- `test` is `vitest run --passWithNoTests` on every stack (bare `vitest` is watch mode and exits 1 with no test files; an existing bare `vitest` is replaced). next's `typecheck` is `next typegen && tsc --noEmit` (global types like `LayoutProps` live in gitignored `.next/types`; an existing bare `tsc --noEmit` is replaced).
- `bootstrap-github.sh` and `gh-flow.sh` export `CLICOLOR_FORCE=0 NO_COLOR=1`: a shell with `CLICOLOR_FORCE=1`/`FORCE_COLOR=1` makes `gh --format json | jq` fail on ANSI codes, and only `CLICOLOR_FORCE=0` turns it off. `gh-flow.sh start` uses `git pull --autostash` so a dirty tree survives pull.rebase.
- The project's `guard-branch.sh` hook blocks `git commit`/`git push` on dev/main, except the initial commit (no HEAD yet). It judges the repo the command targets (`git -C <dir>` or a leading `cd <dir> &&`), not the session cwd.
- node-ts's ESLint config is `eslint.config.mjs` so it loads regardless of the package `"type"`.
- After editing the manifest/interview parts, run `bash scripts/test-manifest.sh` (offline, no network).
- After editing anything in this skill, run `bash scripts/e2e.sh --stack all` (generates every stack, including `java-spring`, `java-spring-gradle`, `kotlin-spring` and `python`, in temp dirs, runs `init.sh --install`, `verify-ci.sh`, and an idempotency re-run; never touches GitHub). It must end with every stack PASS.

- **Packs** (`packs/<name>/` in the hub: `pack.json`, `skills/`, `commands/`) bundle skills and slash commands by architecture. `init.sh --manifest` passes the manifest to `project-agents.sh`, which installs the `always` packs (`workflow`) plus those whose `when` matches the stacks and decisions (e.g. `backend-hexagonal-spring` for a Java/Kotlin backend with `backend-style: hexagonal`). It also writes `.agents/critical.json` (keyword/path -> skill, read by the `critical-reasoning.sh` hook), a keyword table in `AGENTS.md` and `.agents/skills.lock`. Check with `bash ~/.agents/skills/scripts/test-packs.sh`.
- `init.sh` also installs the stack's skills/rules/MCP into `.claude/` and `.mcp.json` via `scripts/project-agents.sh` (stacks in `config/scopes.json`; `--with` adds extra ones). Stack skills are NOT global anymore.
