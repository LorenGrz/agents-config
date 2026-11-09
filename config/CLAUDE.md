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

- Planning (Plan L only) `superpowers:brainstorming` then `writing-plans`; TDD `superpowers:test-driven-development`;
  unknown-cause bugs `superpowers:systematic-debugging` (`debug-assistant` only for a pasted stack trace).
- TypeScript review `code-review-safety` (acting on feedback: `superpowers:receiving-code-review`);
  stress-testing an idea `mattpocock-skills:grilling`. New repo `project-init`; new company `org-creator`.
- Any git action goes through `git-workflow` first, not `superpowers:finishing-a-development-branch`.
- Integrations (ADR 0016): Slack `slack-usage`; Jira/Confluence `jira-usage`; GitHub remote `github-usage`;
  Gmail/Calendar/Drive `google-workspace-usage`; Obsidian `obsidian-vault`; NotebookLM
  `notebooklm-obsidian-sync`; cross-model review `codex-review`. Anything that sends, schedules, creates,
  merges, shares or deletes is shown and approved first.
- `vercel` and `playwright` are off globally and enabled per project (`scopes.json` `plugins`).
- Rules are guidance; hard limits live in each repo's lint, CI and hooks (see `project-init`).

## Workflow lanes

- **Punctual change** (one file, clear intent): do it directly. No question, no plan, no lane (optional:
  PonyTail, ADR 0020).
- **More than one file, or unclear scope** (unknown-cause bugs too): before editing, one `AskUserQuestion`
  with exactly three options, in this order: **Continuar** (direct, no plan) · **Plan S** (plan mode, short
  plan: files, change, check; executed inline, no brainstorming, no spec docs, no `worker`/`reasoner`) ·
  **Plan L** (plan mode: `brainstorming`, `writing-plans` in `docs/superpowers/`, then `worker`/`reasoner`,
  or caolg across repos). Mark the one you recommend with one line of why; keep the order. On Plan S/L
  call `EnterPlanMode`; an unknown cause starts with `systematic-debugging`. If the user enters plan mode
  directly, the plan ends with "Plan S/L because …".
- Outside a plan, never invoke `brainstorming`, `writing-plans`, `executing-plans`, `subagent-driven-development`,
  `worker` or `reasoner` unless asked (this overrides `using-superpowers`); `scout` stays allowed for open lookups.

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
