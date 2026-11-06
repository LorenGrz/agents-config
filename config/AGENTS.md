# Agent Instructions

Shared instructions for every coding agent (Claude Code, Codex, others). Agent-specific
additions live in each agent's own file (e.g. `CLAUDE.md`), never duplicated here.
Personal preferences (identity, language, learning stage, your own project paths) live in
your profile (`config/profiles/<your-name>.md`, imported alongside this file) — not here.

## Communication

- Answer in the user's language by default.
- If the active profile enables English coaching, add a 2-line-maximum `English note` (one
  main issue) plus a `Better` line with the prompt phrased correctly, written only in
  English, for every user message written partly or fully in English.
- Do not correct code, commands, file paths, proper names, or clearly intentional informal shorthand.
- Keep explanations concise and practical.
- Use direct engineering language. Avoid cheerleading, vague reassurance, and unnecessary theory.

## Working Style

- Read the existing project before changing it.
- Prefer small, scoped changes that match the repository's current patterns.
- Use `rg` or `rg --files` first for searching.
- Do not overwrite, revert, or delete user changes unless explicitly asked.
- Before larger work, state the concrete outcome, expected files, and verification command.
- New project → `project-init` skill (scaffolds AGENTS.md, .claude/, CI, GitHub Project; works with any AI).
- Prefer project-local dependencies and scripts over global installs.
- Use `pnpm` by default for JavaScript and TypeScript projects unless a project clearly uses another package manager.
- Add or keep scripts for `dev`, `test`, `lint`, `format`, and `typecheck` when the project needs them.
- Maintain a short `README.md` for learning projects with purpose, stack, commands, architecture decisions, lessons learned, and next steps.
- Per-repo context lives in `AGENTS.md` (single source of truth for every agent). `CLAUDE.md`, when present, contains only `@AGENTS.md` plus Claude-specific instructions. Never duplicate content between them; when a repo has both with overlapping content, merge into AGENTS.md.
- Every repo keeps: (a) `AGENTS.md` as the map new sessions read instead of the code; (b) `.agents/CONTEXT.md` for current state; (c) `docs/superpowers/specs/` and `docs/superpowers/plans/` for every approved spec/plan created in a session — including subagent/worker specs and mid-session follow-up plans, not only the first one — copy an approved plan-mode plan into `docs/superpowers/plans/YYYY-MM-DD-<slug>.md` before implementing (plan mode saves outside the repo, in `~/.claude/plans`); (d) `docs/decisions/NNNN-<slug>.md` ADRs for decisions with trade-offs; (e) `docs/prompts.md` with every AI prompt the app sends to a model (verbatim copy, where it lives in code, and a short history of what was tried and why it changed) — update it in the same PR as any prompt change. Update these after merging.

## Organizations (work repos)

Applies to every repo that matches an organization (`organizations/INDEX.md`); personal repos keep the
lighter flow of the sections above. An org's `POLICIES.md` may add to these rules, never relax them.

- **Never commit on the base or release branches** (`main`, `master`, `dev`). Each task starts on a new branch
  named after what it solves, cut from the remote base: `git fetch` then
  `git checkout -b <type>/<scope>-<topic> origin/<base>`. If the org's base branch does not exist yet, cut
  from `origin/main` and rebase onto the base when it appears. Check before the first commit with
  `git merge-base --is-ancestor origin/<base> HEAD`. Never stack a task on an old working branch.
- **Ask before every push or PR**, even when the plan already mentions it. A slash command the user invokes
  for that run (e.g. a ship command) counts as asking.
- **PR flow.** With the user's OK, the PR opens against the org's base branch with the explanation already
  agreed. Opening it also, without asking again: posts a short closing comment on each ticket (PR link plus
  one or two lines, only when it adds something the PR does not) and moves each ticket to the project's
  review/test status.
- **Everything else on the tracker is asked first.** Proposals, questions, new tickets, edits or any
  transition outside the PR flow above are shown first and published only after the user's explicit OK on
  that exact text. An approved plan that contains the text does not count.
- **Suggest issues, don't fix them in passing.** Anything found along the way that is out of scope but has
  real impact (security, a user-visible bug, docs that mislead the next person) and is simple to explain is
  proposed at the end of the task: title, impact in one line, proposal in one line, priority and evidence
  (`path:line`). No lint warnings or style preferences, nothing unverified. Filed only with the user's OK.
- **Say exactly where work landed.** Report the branch name; never write "committed to main" for work on a
  branch cut from main.

## Roadmap

Learning roadmap and current stage are personal — see your profile
(`config/profiles/<your-name>.md`) and the `roadmap-coach` skill
(`meta/roadmap-coach/references/roadmap-detail.md`).

## Git

- If the repo has `scripts/gh-flow.sh` (repos scaffolded with `project-init`), use it: the repo's AGENTS.md flow (base `dev`, PR + squash) overrides this global workflow.
- Assume the worktree may already be dirty.
- Inspect `git status --short` before committing.
- Prefer non-interactive git commands: inline `-m` messages, never open an editor, never `-i`.
- Never use destructive commands like `git reset --hard` or checkout-based reverts unless the user explicitly asks.
- Never `git push --force` to `main`/`master` or any shared branch.

### GitHub push workflow (always follow when pushing to main/master or handling a GitHub remote)

Detect the default branch first: `git symbolic-ref --short refs/remotes/origin/HEAD` (falls back to `main`; some repos use `master`). Use that name wherever `<default>` appears.

1. **`.gitignore` gate.** Before the first commit in a repo, make sure `.gitignore` exists and covers, at minimum:
   - dependencies: `node_modules/`, `.pnp*`, `.venv/`, `venv/`, `__pycache__/`, `*.py[cod]`
   - env & secrets: `.env`, `.env.*` (but `!.env.example`), `*.pem`, `*.key`, `*credentials*.json`, `*secret*.json`
   - build output: `dist/`, `build/`, `out/`, `.next/`, `.turbo/`, `coverage/`, `*.tsbuildinfo`
   - logs & caches: `*.log`, `.cache/`, `tmp/`
   - OS/editor: `.DS_Store`, `Thumbs.db`, `.idea/`, `.vscode/*` (but `!.vscode/extensions.json`)
   Base it on the github/gitignore template for the stack. If any of these are already tracked, untrack them: `git rm -r --cached <path>` then commit.

2. **Sync `<default>`:** `git checkout <default> && git pull origin <default>`.

3. **Resolve conflicts** if the pull reported any: fix the files, `git add <resolved>`, `git commit` (or `git merge --continue`). Only then continue.

4. **Branch:** `git checkout -b <type>/<slug>` where `<type>` is `feat`, `refactor`, or `fix` and `<slug>` is a short kebab-case summary.

5. **Verify the touched layer**, then **stage & commit.** Run the checks for what changed and fix failures before committing:
   - frontend (React/TS): `pnpm lint` (must pass at `--max-warnings 0`) and `pnpm test run`
   - backend (Kotlin/Spring): `./gradlew test`
   - other stacks: the project's own lint + typecheck + unit tests
   Then review `git status --short`; if unrelated changes are mixed in, ask before continuing. Otherwise `git add .` then `git commit -m "<Conventional Commit subject>"`.

6. **Push the branch:** `git push -u origin <type>/<slug>`.

7. **Merge & clean up:**
   ```
   git checkout <default>
   git merge --no-ff <type>/<slug> -m "Merge <type>/<slug>"
   git push origin <default>
   git branch -d <type>/<slug>
   git push origin --delete <type>/<slug>
   ```
   `--no-ff` keeps each feature visible as its own merge in the tree.

8. **Update project context after merging into `<default>`/`main`/`master`.** If the merged changes alter stack, architecture, modules, env vars, deploy/infra, commands, or known issues, update the project's `AGENTS.md` (and `CLAUDE.md` only if it holds Claude-specific content, plus `.agents/CONTEXT.md` if present) to match the code, commit it as `docs: update AGENTS.md after <branch> merge`, and push it in the same session. Skip only when nothing documented changed, and say so.

If the repo has branch protection or a PR-based flow, stop after step 6 and open a PR with `gh pr create` instead of merging locally.

## Verification

- Run the smallest useful verification command for the change.
- If tests or installs need network access, explain the blocker and ask for permission when the tool requires it.
- Report what was changed, what was verified, and anything not verified.

## OS and desktop config

- If a profile names a desktop-environment settings repo (e.g. Omarchy), edit only safe
  user config locations (such as `~/.config/`), never the desktop environment's own source
  tree.
- If changing OS or desktop config, test locally first, and confirm the change works before
  pushing to the settings repo named in the profile. Do not push unrelated or pre-existing
  changes.
