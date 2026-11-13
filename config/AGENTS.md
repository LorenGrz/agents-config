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

## Workflow lanes

- **Punctual change** (one file, clear intent): do it directly. No question, no plan.
- **More than one file, or unclear scope** (unknown-cause bugs too): before editing, ask one question with
  exactly three options, always in this order: **Continuar** (direct, no plan) · **Plan S** (short plan:
  files, change, check; executed inline, no brainstorming, no spec docs, no subagents) · **Plan L** (design,
  spec and plan in `docs/superpowers/`, then delegated to subagents or workers). Mark the recommended one
  with "(Recomendado)" and one line of why, without moving it: Continuar stays first.
- **Every plan (S or L) starts with a grilling interview:** before designing anything, interview the user
  one question at a time (the `mattpocock-skills:grilling` skill where available) until nothing is left to
  assume. Plan L's design step does not re-ask what was answered.
- Outside a plan, don't pull in the heavy process (brainstorming, plan writing, subagent-driven execution)
  unless asked.

## Organizations (work repos)

In a repo that matches an organization (`organizations/INDEX.md`): never commit on `main`/`master`/`dev`,
ask before every push or PR, and nothing goes to the tracker without the user's OK on the exact text.
Load the `github-usage` skill before the first git action there: it has the full org rules (branch naming,
PR flow, tracker writes, issue suggestions). An org's `POLICIES.md` may add to these rules, never relax them.

## Roadmap

Learning roadmap and current stage are personal — see your profile
(`config/profiles/<your-name>.md`) and the `roadmap-coach` skill
(`skills/meta/roadmap-coach/references/roadmap-detail.md`).

## Git

- If the repo has `scripts/gh-flow.sh` (repos scaffolded with `project-init`), use it: the repo's AGENTS.md flow (base `dev`, PR + squash) overrides this global workflow.
- Assume the worktree may already be dirty.
- Inspect `git status --short` before committing.
- Prefer non-interactive git commands: inline `-m` messages, never open an editor, never `-i`.
- Never use destructive commands like `git reset --hard` or checkout-based reverts unless the user explicitly asks.
- Never `git push --force` to `main`/`master` or any shared branch.
- Before committing, pushing, merging or opening a PR, follow the `github-usage` skill (gitignore gate,
  branch, verify, commit, push, merge, update `AGENTS.md` after merging).

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

<!-- intents:start -->
## Shortcuts

Natural phrases map to a skill. Load the skill and use the command in its `## Shortcuts` section;
Claude Code's `intent-router` hook injects this automatically. Outbound actions still need the user's OK.

- `codex-review`: Codex review
- `github-usage`: pull changes, new branch, commit, push, open PR, issues and PRs
- `google-workspace-usage`: email, calendar, drive files
- `jira-ticket-review`: review my tickets
- `jira-usage`: Jira ticket
- `mattpocock-skills:grilling`: stress-test an idea
- `notebooklm-obsidian-sync`: NotebookLM
- `obsidian-vault`: vault notes
- `slack-usage`: read or search Slack, send to Slack
- `superpowers:brainstorming`: design before building
- `superpowers:systematic-debugging`: unknown-cause bug
- `superpowers:test-driven-development`: test first
<!-- intents:end -->
