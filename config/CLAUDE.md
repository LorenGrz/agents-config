# Claude Code specifics

Claude Code-only additions on top of `AGENTS.md` (imported separately by the file that
pulls this one in — do not re-import it here).

## Skills

Invoke a matching skill before acting (`/<name>` or auto-activate); load only what the task needs.
Skills live in this repo's `<category>/<skill>/`, mirrored flat into `~/.claude/skills` by `sync.sh`
(run it after adding or moving one). Rules in `~/.claude/rules/` load on a matching file (`paths:`).
Stack skills (React, Next, Nest, persistence, API, auth, AWS) exist only in repos set up with
`project-agents.sh`: the repo's `.claude/skills` and its AGENTS.md index say which.

Where skills overlap, one default per task:

- Planning: `mattpocock-skills:grilling` first (Plan S and L), then (Plan L only) `superpowers:brainstorming`
  and `writing-plans`; TDD `superpowers:test-driven-development`;
  unknown-cause bugs `superpowers:systematic-debugging` (`debug-assistant` only for a pasted stack trace).
- TypeScript review `code-review-safety` (acting on feedback: `superpowers:receiving-code-review`);
  stress-testing an idea `mattpocock-skills:grilling`. New repo `project-init`; new company `org-creator`.
- Any git or GitHub action goes through `github-usage` first, not `superpowers:finishing-a-development-branch`.
- Integrations (ADR 0016): Slack `slack-usage`; Jira/Confluence `jira-usage`; git and GitHub `github-usage`;
  Gmail/Calendar/Drive `google-workspace-usage`; Obsidian `obsidian-vault`; NotebookLM
  `notebooklm-obsidian-sync`; cross-model review `codex-review`. Anything that sends, schedules, creates,
  merges, shares or deletes is shown and approved first.
- `vercel` and `playwright` are off globally and enabled per project (`scopes.json` `plugins`).
- Rules are guidance; hard limits live in each repo's lint, CI and hooks (see `project-init`).

## Workflow lanes

The lanes and the grilling interview are in `AGENTS.md` "Workflow lanes"; in Claude Code they run like this:

- The lane question is one `AskUserQuestion`; its fixed order (Continuar first) overrides the tool's
  "recommended first". Plan S/L call `EnterPlanMode` and load `mattpocock-skills:grilling` right after.
  Plan S runs inline with `ponytail:ponytail` loaded at the start, no `worker`/`reasoner`. Plan L uses
  `superpowers:brainstorming`, then `writing-plans`, then `worker`/`reasoner`, or caolg across repos. An
  unknown cause starts with `superpowers:systematic-debugging`. A plan the user starts directly ends with
  "Plan S/L because …".
- `lane-guard.sh` enforces it: it denies a lane question in another order and an `ExitPlanMode` with no
  grilling since plan mode began (ADR 0025).
- Outside a plan, never invoke `brainstorming`, `writing-plans`, `executing-plans`, `subagent-driven-development`,
  `worker`, `reasoner` or `ponytail*` unless asked; this overrides `using-superpowers` and the
  skills' own descriptions. `scout` stays allowed for open lookups.

## Agent Routing

Pick the agent by role; the model of each role is in your profile ("Model routing").

- **Look up** (`scout`): read-only lookups: unknown paths, sweeping dirs, web, docs, inventories, with one
  concrete question. Reading a known file stays inline.
- **Decide** (`reasoner`, or plan mode): architecture, unknown-cause bugs, plan review, hard-to-reverse
  calls. Never bulk writing. A decision costly to get wrong never goes to `worker` or `scout`.
- **Implement** (`worker`): code, docs, tests from a decided plan, with the exact files and an acceptance
  command. More than 3 files or bulk -> `worker`; ≤3 known files stay inline (a cold start costs more).
- **Bulk (external)** (`gemini-delegate`, `agy`): mechanical writing or wide reading when that quota is
  cheaper; review the diff, run the acceptance command (ADR 0010).
- Superpowers subagents: implementer, routine reviewer -> `worker`; security/architecture reviewer -> `reasoner`; search -> `scout`.
- A plan recommends the subagents (which, why) and asks. While executing an approved plan, delegating per
  these rules is a standing instruction (it overrides the default "don't spawn agents unless asked").
- Independent subtasks: one message, in parallel. Parallel `worker`s on one repo get a worktree each
  (`isolation: "worktree"`) unless their files are disjoint.

Prefer `/clear` between unrelated tasks over `/compact`.
