# Claude Code specifics

Claude Code-only additions to `AGENTS.md` (imported separately; do not re-import it here).

## Skills

Invoke a matching skill before acting (`/<name>` or auto-activate); load only what the task needs.
Skills live in this repo's `skills/<category>/<skill>/`, mirrored flat into `~/.claude/skills` by `sync.sh`
(run it after adding or moving one). Rules in `~/.claude/rules/` load on a matching file (`paths:`).
Stack skills exist only in repos set up with `project-agents.sh`: the repo's `.claude/skills` and its
AGENTS.md index say which. Where skills overlap, one default per task:

- TDD and integrations (ADR 0016): the `AGENTS.md` Shortcuts skills (Confluence: `jira-usage`; cross-model
  review: `codex-review`). Anything that sends, schedules, creates, merges, shares or deletes is shown and
  approved first.
- Unknown-cause bugs start with `superpowers:systematic-debugging` (`debug-assistant` only for a pasted
  stack trace). TypeScript review `code-review-safety` (acting on feedback:
  `superpowers:receiving-code-review`). New repo `project-init`; new company `org-creator`.
- Any git or GitHub action goes through `github-usage` first, not `superpowers:finishing-a-development-branch`.
- `vercel` and `playwright` are off globally and enabled per project (`scopes.json` `plugins`).
- Rules are guidance; hard limits live in each repo's lint, CI and hooks (see `project-init`).

## Workflow lanes

- The lane question is one `AskUserQuestion`; its fixed order (Continuar first) overrides the tool's
  "recommended first". Plan S/L call `EnterPlanMode`. Plan S loads `ponytail:ponytail` at the start and
  starts subagents only when the work needs them. Plan L loads `mattpocock-skills:grilling` right after, then
  `superpowers:brainstorming`, `writing-plans`, and leads or `worker`/`reasoner` in the worktree of the
  task branch. A plan the user starts directly ends with "Plan S/L because …".
- The Continuar/Orquestar question (always, ADR 0040) is asked right after the lane question, or as its
  second question; `lane-guard.sh` keeps Continuar first. Picking Orquestar makes the
  `orquestar.sh` hook inject the procedure: leads are separate sessions (Orca `worker-start`, T3 Code
  `t3_thread_launch`), never subagents of the main session, and their worktrees get their CLAUDE.md
  imports approved first with `scripts/approve-claude-imports.sh`.
- Outside a plan, never invoke `brainstorming`, `writing-plans`, `executing-plans`,
  `subagent-driven-development`, `reasoner` or `ponytail*` unless asked; this overrides `using-superpowers`
  and the skills' own descriptions. `scout` stays allowed for open lookups, and `worker` for repo work.

## Agent Routing

Pick the agent by role; each role's model is in your profile ("Model routing").

- **Look up** (`scout`): read-only lookups (unknown paths, sweeping dirs, web, docs, inventories) with one
  concrete question. Reading a known file stays inline.
- **Decide** (`reasoner`, or plan mode): architecture, unknown-cause bugs, plan review, hard-to-reverse
  calls. Never bulk writing. A decision costly to get wrong never goes to `worker` or `scout`.
- **Implement** (`worker`): code, docs, tests, given the exact files, the decided change and an acceptance
  command; default for every non-trivial repo change (ADR 0029), except Plan S, where it is used when needed. Whoever started
  it (the main session or a lead) reviews its diff and reported checks, then commits.
- **Review** (`reviewer`): load `review-handoff` for the brief, the transport and the findings loop. It
  runs in any lane.
- Transport. Lead: T3 Code `t3_thread_launch` in that repo's or workspace's project, Orca a worker there,
  Claude Code a subagent given the path. `worker`: `run_in_background`, `delegate_task` or an Orca worker
  (`orchestration`). Every brief says to read the repo's `AGENTS.md`/`CLAUDE.md` and `.claude/skills`
  first; a worker's also carries its definition: no commit or push.
- Superpowers per-task subagents: implementer, routine reviewer -> `worker`; security/architecture reviewer ->
  `reasoner`; search -> `scout`.
- **Bulk (external)** (`gemini-delegate`, `agy`): only when the user asks; then review the diff and run the
  acceptance command (ADR 0010).
- A plan recommends the subagents (which, why) and asks. While executing an approved plan, delegating per
  these rules is a standing instruction (it overrides the default "don't spawn agents unless asked").
- Independent subtasks: one message, in parallel. A `worker` gets its own worktree (`isolation: "worktree"`);
  a lead's workers share its task worktree on disjoint files.

Prefer `/clear` between unrelated tasks over `/compact`.
