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
  - `.scratch/<topic>/` (local, ignored by git globally, never committed): the spec and tickets being
    executed ("Issue tracker" below). Copy an approved plan-mode plan into `.scratch/<topic>/plan.md`
    before implementing (`spec.md` is only `to-spec`'s); before the merge that finishes the work, move what must outlive it to an ADR.
  - `docs/decisions/NNNN-<slug>.md`: ADRs for decisions with trade-offs.
  - `docs/prompts.md`: every AI prompt the app sends to a model (verbatim copy, where it lives in code,
    short history of what was tried and why it changed), updated in the same PR as any prompt change.

## Workflow lanes

- **Trivial change** (one line or a typo): do it directly. No question, no plan.
- **Every other task** (any non-trivial repo change, one file included; unknown-cause bugs too): before
  editing, ask one question with exactly three options, always in this order: **Continuar** (direct, no
  plan) · **Plan S** (short plan: files, change, check; no interview, no `to-spec` or `to-tickets`, subagents only when
  the work needs them) · **Plan L** (interview, spec and tickets in `.scratch/`, then one worker per
  ticket). Option descriptions stay minimal: «directo», «plan corto», «plan complejo». Mark the recommended one with "(Recomendado)" and one
  short line of why, without moving it: Continuar stays first.
- **Always after the lane question** (ADR 0040), one more question with exactly two options, in this
  order: **Continuar** (the main session runs it) · **Orquestar** (one lead per task branch and repo, as a
  separate session in its worktree with that repo's skills and only the context it needs; several branches
  run in parallel; each lead may start its own `worker` and `scout`, never a reviewer). It may go as the second
  question of the same `AskUserQuestion`. With more than one task branch (several tickets, or back and
  front) Orquestar is the recommended one; with one, recommend by size, with one short line of why. Work
  that depends on a contract (the front of a ticket whose back defines it) starts when that contract is
  committed. Picking Orquestar loads the fixed procedure (ADR 0039).
- **Plan S has no interview:** investigate, then ask only the critical decisions that can't be deduced, in
  one batch. No rounds.
- **Plan L starts with a grilling interview:** before designing anything, interview the user one question
  at a time (the `mattpocock-skills:grilling` skill where available) until nothing is left to assume. The
  next steps do not re-ask what was answered.
- **Plan L then follows Matt Pocock's skills** (ADR 0052): `to-spec` writes `.scratch/<topic>/spec.md`,
  `to-tickets` splits it into `.scratch/<topic>/issues/NN-<slug>.md`, and execution follows `implement-spec`:
  one `worker` per unblocked ticket, in parallel, each in its own worktree from the task branch. `.scratch/`
  does not travel to worktrees: each worker's brief carries the absolute path of the main checkout's
  `.scratch/<topic>/`. The lead commits each worker's diff and merges it into the task branch, then starts
  the tickets it unblocks. Then the two-axis review below, from the parent; the PR follows the repo's or
  org's policy (in CX, the draft opens at the start). `to-spec`, `to-tickets`, `implement-spec` and
  `wayfinder` are user-invoked only: read their `SKILL.md` from the plugin and follow it, with the
  exceptions in this section.
- **Plan L splits the work by repo:** the main session plans, writes the briefs, integrates, and writes no
  code. Work that spans repos (backend, frontend) gets one lead per repo: a session opened in that repo, in
  the one worktree of its task branch, so that repo's `AGENTS.md`, skills and restrictions apply. When the
  repos sit in a workspace folder that holds their skills, the lead opens in that folder and may send a
  lead to each child repo. A lead implements with the repo's skills, may start `worker` and `scout` agents there and
  commits on the task branch; it does not run lint, typecheck or the test suite, does not verify in a browser
  and does not start a reviewer (ADR 0048): the parent reviews. It never pushes or opens the PR. In a single repo the main session is the lead.
- **Two reviewers check the work before every PR is opened**, and before the merge that closes a Plan L when
  there is no PR (`review-handoff`): separate reviewer agents (the profile names their model), started by the
  parent session in one message (one pair per PR, in parallel; back and front of one PR go to the same pair),
  get only the diffs and the ticket, without editing. **Standards** reviews against the repo's documented
  rules, its review skill and a smell baseline, and runs the repo's CI commands once (`.github/workflows`,
  never a default package manager); **Spec** reviews against the ticket or spec. Their reports are shown
  under `## Standards` and `## Spec`, never merged. Nobody else reruns the checks: workers run only the
  tests they wrote (their definition says so), and working alone in Plan S the main session runs them once
  at the end. Whoever asked for
  the review fixes small findings, sends large ones to a worker and asks for one re-review per axis; what is still
  open goes to the user. Another provider's model reviews only when the user asks for it. An agent that
  cannot start a reviewer says so before the PR instead of skipping the review.
- **An agent started from a brief** (lead, worker, scout, reviewer) executes it without the lane
  question. Only a lead may start agents of its own: `worker` and `scout`, and a workspace lead also the
  leads of its child repos. Briefs are short: the ticket, the located cause, the files, the decisions taken and
  the paths of skills the repo does not expose; never what the repo already gives the agent.
- **Every plan (S or L) is shown in the terminal message, not only in the plan file, with a table:** who
  does what, whether it runs in parallel, files, and how it is verified. Parallel or visual work adds an
  ASCII diagram of the order.
- Outside a plan, don't pull in the heavy process (grilling, `to-spec`, `to-tickets`, per-ticket workers)
  unless asked.
- **Repo work goes to a background worker by default** (where the agent has subagents): every non-trivial
  change runs in a worker on the task branch, in its own worktree or in its lead's; whoever started it
  reviews the diff and commits. Trivial changes (one line or a typo) are done directly.
  In Plan S the main session executes and starts one only when the work needs it.

## Agent skills

### Issue tracker

Matt Pocock's skills (`to-spec`, `to-tickets`, `implement-spec`, `wayfinder`, `code-review`) use local
markdown in `.scratch/`, ignored by git globally and never committed. The team's tracker (GitHub issues,
Jira) is separate: those skills never write to it.

- One directory per topic: `.scratch/<topic>/`. The spec is `spec.md` (written only by `to-spec`; an
  approved plan-mode plan goes to `plan.md`); tickets are one file each, `issues/NN-<slug>.md`, numbered
  from `01`.
- Near the top of each ticket: a `Status:` line (`needs-triage`, `needs-info`, `ready-for-agent`,
  `ready-for-human`, `wontfix`; `claimed` and `resolved` while it is worked) and a `Blocked by: NN, NN`
  line. A ticket is unblocked when every ticket it lists is `resolved`.
- "Publish to the issue tracker" means create the file; "fetch the ticket" means read it. Comments go at
  the bottom under `## Comments`.
- `wayfinder` keeps its map in `.scratch/<effort>/map.md`, with child tickets in `issues/` as above.
- Full format: `issue-tracker-local.md` of `setup-matt-pocock-skills` in the plugin.

### Triage labels

The canonical roles are the label strings themselves (`needs-triage`, `needs-info`, `ready-for-agent`,
`ready-for-human`, `wontfix`), written in the ticket's `Status:` line.

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
- Every branch starts from the repo's base (`origin/dev`, or the default branch without `dev`) and its PR
  targets that base: never stack a branch on another open PR, because a PR against a non-base branch runs
  no CI (ADR 0054). Before branching, check whether the task needs code from an unmerged PR; if it does,
  tell the user instead of stacking (wait for that merge, or add the task to that PR).
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
- `mattpocock-skills:diagnosing-bugs`: unknown-cause bug
- `mattpocock-skills:grilling`: stress-test an idea, design before building
- `mattpocock-skills:tdd`: test first
- `notebooklm-obsidian-sync`: NotebookLM
- `obsidian-vault`: vault notes
- `slack-usage`: read or search Slack, send to Slack
<!-- intents:end -->
