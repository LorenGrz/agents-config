# Agent Instructions

Shared instructions for every coding agent. Agent-specific additions go in that agent's own file
(e.g. `CLAUDE.md`), never here. Personal preferences go in your profile (`config/profiles/<your-name>.md`).

## Communication

- Answer in the user's language by default.
- If the active profile enables English coaching: for every user message written partly or fully in
  English, add a 2-line-maximum `English note` (one main issue) plus a `Better` line with the prompt
  phrased correctly, written only in English.
- Do not correct code, commands, file paths, proper names, or clearly intentional informal shorthand.
- Be concise and practical, in direct engineering language: no cheerleading, vague reassurance or
  unnecessary theory.

## Working Style

- Read the existing project before changing it. Prefer small, scoped changes that match its patterns.
- Search with `rg` or `rg --files` first.
- Do not overwrite, revert, or delete user changes unless explicitly asked.
- Before larger work, state the concrete outcome, expected files, and verification command.
- New project → `project-init` skill.
- Prefer project-local dependencies and scripts over global installs.
- Use `pnpm` for JavaScript and TypeScript unless a project clearly uses another package manager.
- Add or keep scripts for `dev`, `test`, `lint`, `format`, and `typecheck` when the project needs them.
- Learning projects keep a short `README.md`: purpose, stack, commands, architecture decisions, lessons
  learned, next steps.
- Per-repo context lives in `AGENTS.md`, the single source for every agent. `CLAUDE.md`, when present,
  holds only `@AGENTS.md` plus Claude-specific instructions; content found in both is merged into AGENTS.md.
- Every repo keeps these, updated after merging:
  - `AGENTS.md`: the map new sessions read instead of the code.
  - `.agents/CONTEXT.md`: current state.
  - `docs/superpowers/specs/` and `docs/superpowers/plans/`: the spec and plan being executed. Copy an
    approved plan-mode plan into `docs/superpowers/plans/YYYY-MM-DD-<slug>.md` before implementing;
    delete both in the merge that finishes the work, and move what must outlive them to an ADR.
  - `docs/decisions/NNNN-<slug>.md`: ADRs for decisions with trade-offs.
  - `docs/prompts.md`: every AI prompt the app sends to a model (verbatim copy, where it lives in code,
    short history of what was tried and why it changed), updated in the same PR as any prompt change.

## Workflow lanes

- **Punctual change** (one file, clear intent): do it directly. No question, no plan.
- **More than one file, or unclear scope** (unknown-cause bugs too): before editing, ask one question with
  exactly three options, always in this order: **Continuar** (direct, no plan) · **Plan S** (short plan:
  files, change, check; executed inline, no brainstorming, no spec docs, no subagents) · **Plan L** (design,
  spec and plan in `docs/superpowers/`, then delegated to subagents or workers). Option descriptions stay
  minimal: «directo», «plan corto», «plan complejo». Mark the recommended one with "(Recomendado)" and one
  short line of why, without moving it: Continuar stays first.
- **Plan S has no interview:** investigate, then ask only the critical decisions that can't be deduced, in
  one batch. No rounds.
- **Plan L starts with a grilling interview:** before designing anything, interview the user one question
  at a time (the `mattpocock-skills:grilling` skill where available) until nothing is left to assume. The
  design step does not re-ask what was answered.
- **Plan L splits the work by repo:** the main session plans, writes the briefs, integrates, and writes no
  code. Work that spans repos (backend, frontend) gets one lead per repo: a session opened in that repo, in
  the one worktree of its task branch, so that repo's `AGENTS.md`, skills and restrictions apply. When the
  repos sit in a workspace folder that holds their skills, the lead opens in that folder and may send a
  lead to each child repo. A lead implements with the repo's skills, may start `worker` and `scout` agents
  there, commits on the task branch and gets its diff reviewed before handing it back; it never pushes or
  opens the PR. In a single repo the main session is the lead.
- **A reviewer checks the work before every PR is opened**, and before the merge that closes a Plan L when
  there is no PR: a model from another provider (named in the profile) reviews the diff against the
  original request with the repo's review skill and runs the checks, without editing. Whoever asked for
  the review fixes small findings, sends large ones to a worker and asks for one re-review; what is still
  open goes to the user. No reviewer available: the profile's fallback reviews, and the user is told in one line.
- **An agent started from a brief** (lead, worker, scout, reviewer) executes it without the lane
  question. Only a lead may start agents of its own: `worker` and `scout`, and a workspace lead also the
  leads of its child repos.
- **Every plan (S or L) is shown in the terminal message, not only in the plan file, with a table:** who
  does what, whether it runs in parallel, files, and how it is verified. Parallel or visual work adds an
  ASCII diagram of the order.
- Outside a plan, don't pull in the heavy process (brainstorming, plan writing, subagent-driven execution)
  unless asked.
- **Repo work goes to a background worker by default** (where the agent has subagents): every non-trivial
  change runs in a worker on the task branch, in its own worktree or in its lead's; whoever started it
  reviews the diff and commits. Trivial changes (one line, or one file with no checks) are done directly.

## Organizations (work repos)

In a repo that matches an organization (`organizations/INDEX.md`): never commit on `main`/`master`/`dev`,
ask before every push or PR, and a new ticket or a comment goes to the tracker only with the user's OK on the exact text.
Load the `github-usage` skill (full org rules) before the first git action there. An org's `POLICIES.md`
may add to these rules, never relax them.

## Roadmap

The learning roadmap and current stage are personal: see your profile and the `roadmap-coach` skill
(`skills/meta/roadmap-coach/references/roadmap-detail.md`).

## Git

- If the repo has `scripts/gh-flow.sh` (repos scaffolded with `project-init`), use it: the repo's AGENTS.md
  flow (base `dev`, PR + squash) overrides this section.
- Assume the worktree may already be dirty; inspect `git status --short` before committing.
- Prefer non-interactive git commands: inline `-m` messages, never open an editor, never `-i`.
- Never use destructive commands like `git reset --hard` or checkout-based reverts unless the user
  explicitly asks. Never `git push --force` to `main`/`master` or any shared branch.
- Before committing, pushing, merging or opening a PR, follow the `github-usage` skill (gitignore gate,
  branch, verify, commit, push, merge, update `AGENTS.md` after merging).

## Verification

- Run the smallest useful verification command for the change.
- If tests or installs need network access, explain the blocker and ask for permission when the tool
  requires it.
- Report what was changed, what was verified, and anything not verified.

## OS and desktop config

- If a profile names a desktop-environment settings repo (e.g. Omarchy), edit only safe user config
  locations (such as `~/.config/`), never the desktop environment's own source tree.
- Test OS or desktop config changes locally and confirm they work before pushing to that settings repo.
  Do not push unrelated or pre-existing changes.

<!-- intents:start -->
## Shortcuts

Natural phrases map to a skill. Load the skill and use the command in its `## Shortcuts` section;
Claude Code's `intent-router` hook injects this automatically. Outbound actions still need the user's OK.

- `codex-review`: Codex review
- `github-usage`: pull changes, new branch, commit, push, open PR, issues and PRs, clean up worktrees
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
