# Script behavior notes
Read when: a project-init script prints something surprising, or before editing this skill's scripts or templates.

## init.sh

- Skip-if-exists has three deliberate exceptions:
  - `eslint.config.js`/`.mjs` and `AGENTS.md` are overlaid even if a file already exists there, unless it already carries this skill's marker text: `create-next-app --eslint` writes its own `eslint.config.mjs`, and Next 16+ writes a short `AGENTS.md` (`next dev` regenerates it anyway, per its own comment). Once the marker is present, normal skip-if-exists resumes.
  - `.gitignore`: generators write their own, so `init.sh` appends every template line not already present under a `# project-init baseline` header (`merged .gitignore (+N lines)`, or `skip .gitignore (complete)` on re-run).
- `init.sh --install` adds any tool the scripts call but the project doesn't declare (`prettier`, `vitest`, `tsx`) to the same `pnpm add -D` as the ESLint deps, writes `pnpm-workspace.yaml` `allowBuilds.esbuild: false` when `tsx` comes in (pnpm otherwise aborts with `ERR_PNPM_IGNORED_BUILDS`), and ends with `pnpm run format` so CI's `format:check` passes. `.prettierignore` skips `pnpm-lock.yaml`.
- `test` is `vitest run --passWithNoTests` on every node stack (bare `vitest` is watch mode and exits 1 with no test files; an existing bare `vitest` is replaced). For nestjs that default only applies when the generator's `package.json` has no `test` script (`nest new` currently ships Vitest and always writes one).
- next's `typecheck` is `next typegen && tsc --noEmit` (global types like `LayoutProps` live in gitignored `.next/types`; an existing bare `tsc --noEmit` is replaced).

## Skills, rules and packs

- `init.sh` installs the stack's skills/rules/MCP into `.claude/` and `.mcp.json` via the hub's `scripts/project-agents.sh` (stacks in `config/scopes.json`; `--with` adds extra ones).
- **Packs** (`packs/<name>/` in the hub: `pack.json`, `skills/`, `commands/`) bundle skills and slash commands by architecture. `init.sh --manifest` passes the manifest to `project-agents.sh`, which installs the `always` packs (`workflow`) plus those whose `when` matches the stacks and decisions (e.g. `backend-hexagonal-spring` for a Java/Kotlin backend with `backend-style: hexagonal`). It also writes `.agents/critical.json` (keyword/path -> skill, read by the `critical-reasoning.sh` hook), a keyword table in `AGENTS.md` and `.agents/skills.lock`.

## GitHub scripts and hooks

- `bootstrap-github.sh` and `gh-flow.sh` export `CLICOLOR_FORCE=0 NO_COLOR=1`: a shell with `CLICOLOR_FORCE=1`/`FORCE_COLOR=1` makes `gh --format json | jq` fail on ANSI codes, and only `CLICOLOR_FORCE=0` turns it off.
- `gh-flow.sh start` uses `git pull --autostash` so a dirty tree survives pull.rebase.
- The project's `guard-branch.sh` hook blocks `git commit`/`git push` on dev/main, except the initial commit (no HEAD yet). It judges the repo the command targets (`git -C <dir>` or a leading `cd <dir> &&`), not the session cwd.
