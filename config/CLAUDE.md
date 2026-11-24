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
- Unknown-cause bugs start with `mattpocock-skills:diagnosing-bugs` (`debug-assistant` only for a pasted
  stack trace). TypeScript review `code-review-safety`. New repo `project-init`; new company `org-creator`.
- Any git or GitHub action goes through `github-usage` first.
- `vercel` and `playwright` are off globally and enabled per project (`scopes.json` `plugins`).
- Rules are guidance; hard limits live in each repo's lint, CI and hooks (see `project-init`).

## Workflow lanes

- The lane question is one `AskUserQuestion`; its fixed order (Continuar first) overrides the tool's
  "recommended first". Plan S/L call `EnterPlanMode`. Plan S loads `ponytail:ponytail` at the start and
  starts subagents only when the work needs them. Plan L loads `mattpocock-skills:grilling` right after, then
  reads and follows the plugin's `to-spec`, `to-tickets` and `implement-spec` (`AGENTS.md` "Workflow
  lanes"), with leads or `worker`/`reasoner` in the worktree of the task branch. A plan the user starts
  directly ends with "Plan S/L because …".
- `lane-guard.sh` keeps Continuar first in the Continuar/Orquestar question too. Picking Orquestar makes the
  `orquestar.sh` hook inject the procedure: leads are separate sessions (Orca `worker-start`, T3 Code
  `t3_thread_launch`), never subagents of the main session, and their worktrees get their CLAUDE.md
  imports approved first with `scripts/approve-claude-imports.sh`.
- Outside a plan, never invoke `reasoner` or `ponytail*` unless asked; this overrides the skills' own
  descriptions. `scout` stays allowed for open lookups, and `worker` for repo work.

## Agent Routing

Pick the agent by role; each role's model is in your profile ("Model routing").

- **Look up** (`scout`): read-only lookups (unknown paths, sweeping dirs, web, docs, inventories) with one
  concrete question. Reading a known file stays inline.
- **Decide** (`reasoner`, or plan mode): architecture, unknown-cause bugs, plan review, hard-to-reverse
  calls. Never bulk writing. A decision costly to get wrong never goes to `worker` or `scout`.
- **Implement** (`worker`): test first, then code and docs, given the exact files and the decided change
  (when to use it: `AGENTS.md`); it runs only the tests it wrote. Whoever started it (the main session or a
  lead) reviews its diff and reported tests, then commits.
- **Review** (`reviewer`): load `review-handoff` for the two briefs (Standards and Spec), the transport and
  the findings loop. It runs in any lane.
- Transport. Lead: T3 Code `t3_thread_launch` in that repo's or workspace's project, Orca a worker there,
  Claude Code a subagent given the path. `worker`: `run_in_background`, `delegate_task` or an Orca worker
  (`orchestration`). Every brief says to read the repo's `AGENTS.md`/`CLAUDE.md` and `.claude/skills`
  first; a worker's also carries its definition: no commit or push.
- **Bulk (external)** (`gemini-delegate`, `agy`): only when the user asks; then review the diff and run the
  acceptance command (ADR 0010).
- A plan recommends the subagents (which, why) and asks. While executing an approved plan, delegating per
  these rules is a standing instruction (it overrides the default "don't spawn agents unless asked").
- Independent subtasks: one message, in parallel. A `worker` gets its own worktree (`isolation: "worktree"`);
  a lead's workers share its task worktree on disjoint files, except Plan L's per-ticket workers, each in
  its own worktree from the task branch.

Prefer `/clear` between unrelated tasks over `/compact`.
