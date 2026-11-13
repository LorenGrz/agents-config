---
name: project-init
description: Use this skill when starting a new project or repo, or when adopting an existing one that this skill didn't generate. For new repos, scaffolds a repository that works with any AI agent (Codex, Cursor, Claude) and humans - a single AGENTS.md source of truth (no CLAUDE.md unless --claude-shim), .claude/ with the superpowers plugin and project hooks, a spec-driven workflow, branch flow feat|fix|refactor/<issue>-<slug> to dev with squash merge, a GitHub Project v2 per repo, and real enforcement via ESLint, a git pre-push hook, and CI. For existing repos, scripts/adopt.sh documents their current git workflow (branch/merge/CI reality, docs-only, no new hooks/CI/enforcement) and fills in the same AGENTS.md/.agents/CONTEXT.md/docs/decisions documentation layer. For a plain folder that groups several repos of one product (e.g. frontend + backend), workspace mode (scripts/workspace.sh) creates the workspace-level AGENTS.md.
---

# Project Init

## Objective

Scaffold a new repo once, correctly, instead of re-deciding workflow per project.

## Workflow

Pick the mode first:

- **New repo** (or empty dir): steps 1-5 below.
- **Existing repo this skill did not generate** (own history, CI, flow): `scripts/adopt.sh`, docs-only. Follow `references/adopt.md`.
- **Plain folder (no `.git`) holding 2 or more repos of one product**: `scripts/workspace.sh`. Follow `references/workspace.md`.

`scripts/` and `templates/` are relative to this skill folder; `project-agents.sh`, `orgs.sh` and `test-packs.sh` live in the hub root `scripts/`.

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
   - `--manifest` supplies `--name`, `--stack` (its first stack), `--with` and the org, and writes `.agents/project.json`, one ADR per decision and the pending decisions into `.agents/CONTEXT.md`. Without a manifest, pass `--stack <stack> --name <repo-name> [--with aws,llm,supabase,...]`.
   - `--owner` defaults to `gh api user --jq .login` (if `gh` is authenticated), then `git config github.user`; pass it explicitly if neither resolves.
   - Without `--install`, `init.sh` only prints the commands needed (devDependencies, missing package.json scripts); nothing is installed or written to `package.json` scripts.
   - With an org (manifest `org` or `--org <name>`) whose GitHub owners do not include `--owner`, `init.sh` warns that the org's private `POLICIES.md` would be copied and asks; non-interactive runs fail unless `--allow-org-mismatch` is passed. Never pass it without the user's OK.
   - `init.sh` also installs the stack's skills/rules/MCP into `.claude/` and `.mcp.json` and the matching packs via the hub's `scripts/project-agents.sh` (details in `references/script-notes.md`). Stack skills are NOT global anymore.

3. **Local git setup** (do this, do not delegate it):
   - `git init -b main` if the directory is not already a repo.
   - Confirm `.gitignore` exists and covers: `node_modules/`, `.pnp*`, `.venv/`, `__pycache__/`, `*.py[cod]`, `.env` and `.env.*` (keep `!.env.example`), `*.pem`, `*.key`, `*credentials*.json`, `*secret*.json`, `dist/`, `build/`, `out/`, `.next/`, `.turbo/`, `coverage/`, `*.tsbuildinfo`, `*.log`, `.cache/`, `tmp/`, `.DS_Store`, `Thumbs.db`, `.idea/`, `.vscode/*` (keep `!.vscode/extensions.json`), `.superpowers/`. `init.sh` merges any missing baseline lines into the generator's `.gitignore`; only fix it if something is still missing.
   - `git config core.hooksPath .githooks`
   - `git add -A && git commit -m "chore: initial project setup"`
   - `bash scripts/verify-ci.sh --dir <path>` - clones the committed HEAD and runs CI's steps (install --frozen-lockfile, format:check, lint, typecheck, test, build). Fix anything red before step 4.

4. **External steps, one at a time, each confirmed by the user before running.** Never hand these to a background agent - they touch GitHub and real resources. `--owner` defaults the same way as `init.sh`'s.
   ```
   bash scripts/bootstrap-github.sh repo     [--owner <owner>] --name <name> --visibility public
   bash scripts/bootstrap-github.sh dev      [--owner <owner>] --name <name>
   bash scripts/bootstrap-github.sh settings [--owner <owner>] --name <name>
   bash scripts/bootstrap-github.sh labels   [--owner <owner>] --name <name>
   bash scripts/bootstrap-github.sh project  [--owner <owner>] --name <name>
   bash scripts/bootstrap-github.sh protect  [--owner <owner>] --name <name>
   ```
   `project` creates the Project, then replaces `TBD`/`{{PROJECT_NUMBER}}` in the repo (`.github/ISSUE_TEMPLATE/*.yml`, `AGENTS.md`, `.agents/CONTEXT.md`), commits it (`chore: set project number to N`) and pushes the current branch itself - no manual commit.
   Add `--dry-run` to preview the exact `gh`/`git` commands without touching GitHub. `bootstrap-github.sh all` only runs with `--dry-run` (refuses otherwise).

5. **Verify and report**: repo URL, dev as default branch, Project URL, CI green on the first PR.

### Daily workflow (what the generated AGENTS.md documents)

Everything starts as an issue in the Project. Non-trivial `feat`/`refactor` work goes through superpowers `brainstorming` -> a spec in `docs/superpowers/specs/` -> `writing-plans` -> a plan in `docs/superpowers/plans/`. `fix` work goes through `systematic-debugging` and only gets a spec if behavior changes. Then `scripts/gh-flow.sh start <type> <slug> --issue N`, implement with `subagent-driven-development` + `test-driven-development`, `verification-before-completion`, `scripts/gh-flow.sh pr`, wait for CI, `scripts/gh-flow.sh merge`. Base branch is always `dev`; `main` only moves via `scripts/gh-flow.sh release`. Agents without superpowers installed follow the same steps manually.

The generated `AGENTS.md` is the source of truth for the new repo - read it there, not here, once a project exists. If the code and the doc disagree, fix the doc.

## Rules

- **AGENTS.md only.** New and adopted repos get `AGENTS.md` as the single source and **no `CLAUDE.md`**: Claude Code >= 2.1.277 reads `AGENTS.md` natively (main session and subagents) as long as there is no `CLAUDE.md` in the working directory or any parent directory; one in a parent directory disables that. `init.sh --claude-shim` / `adopt.sh --claude-shim` write a `CLAUDE.md` whose whole content is `@AGENTS.md`, for older Claude Code versions (optional and harmless). An existing `CLAUDE.md` is never deleted or overwritten; one that only says `@AGENTS.md` can stay.
- `AGENTS.md` carries a `## Critical rules` block (between `<!-- baseline:start -->` and `<!-- baseline:end -->`, the agents-config baseline) and points every session at `.agents/CONTEXT.md` first.
- **No overwrites.** `init.sh` never overwrites an existing file unless `--force`; it prints `skip <path> (exists)` and is safe to re-run. The deliberate exceptions (`eslint.config.*`, `AGENTS.md`, `.gitignore`) are in `references/script-notes.md`.
- **Adopt is docs-only**: it never adds hooks, CI, ESLint, pre-push, or branch protection, and it runs in a worktree, never in the user's own working tree/branch.
- **Workspace**: never infer one from the folder shape alone, and never overwrite an `AGENTS.md`/`CLAUDE.md` that lacks the `<!-- workspace-init -->` marker.
- Every scaffolded repo carries Loren's engineering standards as conventions (`AGENTS.md`'s "Engineering standards" section plus the stack's `AGENTS.stack.md`) and as mechanical enforcement (ESLint, tsconfig strictness, pre-push hook, CI). Do not weaken either; what each one checks is in `references/standards.md`.

## Reference

- `references/interview.md`: read when running the interview, building or validating the manifest.
- `references/adopt.md`: read when the repo already exists and was not generated by this skill.
- `references/workspace.md`: read when the target is a plain folder that groups several repos.
- `references/standards.md`: read when explaining or changing what a scaffolded repo enforces (ESLint rules, tsconfig flags, CI jobs, stack profiles) or which docs it carries (documentation layer).
- `references/script-notes.md`: read when a script's output is surprising (skip/overlay/merge messages, lint or test script values, color env vars, the branch guard hook, packs) or before editing this skill's scripts or templates.
- `references/sdd/light.md`, `references/sdd/off.md`: template text `init.sh` writes into the generated `AGENTS.md` for `sdd: light` / `sdd: off`. Not instructions for this session.

## Verification

- After editing the manifest/interview parts, run `bash scripts/test-manifest.sh` (offline, no network).
- After editing `templates/common/scripts/docs-check.sh`, run `bash scripts/test-docs-check.sh` (offline).
- After editing anything in this skill, run `bash scripts/e2e.sh --stack all` (generates every stack, including `java-spring`, `java-spring-gradle`, `kotlin-spring` and `python`, in temp dirs, runs `init.sh --install`, `verify-ci.sh`, and an idempotency re-run; never touches GitHub). It must end with every stack PASS.
- Packs: `bash scripts/test-packs.sh` from the hub root.
