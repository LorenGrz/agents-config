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

- Planning `superpowers:brainstorming` then `writing-plans`; TDD `superpowers:test-driven-development`;
  unknown-cause bugs `superpowers:systematic-debugging` (`debug-assistant` only for a pasted stack trace).
- TypeScript review `code-review-safety` (acting on feedback: `superpowers:receiving-code-review`);
  stress-testing an idea `mattpocock-skills:grilling`. New repo `project-init`; new company `org-creator`.
- Any git action goes through `git-workflow` first, not `superpowers:finishing-a-development-branch`.
- Integrations (ADR 0016): Slack `slack-usage`; Jira/Confluence `jira-usage`; GitHub remote `github-usage`;
  Gmail/Calendar/Drive `google-workspace-usage`; Obsidian `obsidian-vault`; NotebookLM
  `notebooklm-obsidian-sync`; cross-model review `codex-review`. Anything that sends, schedules, creates,
  merges, shares or deletes is shown and approved first.
- `vercel` and `playwright` are off globally and enabled per project (`scopes.json` `plugins`).
- Rule files are guidance; hard constraints live in each repo's ESLint/CI/hooks (see `project-init`).

## Workflow lanes

Pick the lane when planning, by size and risk; end every plan with one line: "Lane S/L because …".

- **S (light):** cause known, ≤3 files, no new contract, schema, migration or auth, no architecture
  decision. Work inline: focused test, fix, smallest check. No brainstorming, no plan in docs, no
  subagents. Reuse what exists before writing new code (optional plugin: PonyTail, see ADR 0020).
- **L (heavy):** new feature, >3 files or several modules/repos, contract or data changes, or a decision
  with trade-offs: `brainstorming`, `writing-plans` (specs and plans in `docs/superpowers/`), then execute
  with `worker`/`reasoner`. Across repos, or to spread quota across CLIs, open caolg (`claudes`).
- Unknown cause: `systematic-debugging` first, then pick the lane. The user's instructions override a
  skill's own process (lane S skips brainstorming).

## Agent Routing

Pick the agent by role, not by habit; the model behind each role is in your profile ("Model routing").

- **Look up** (`scout`): read-only lookups: unknown paths, sweeping dirs, web, docs, inventories, with one
  concrete question. Reading a known file stays inline.
- **Decide** (`reasoner`, or plan mode): architecture, unknown-cause bugs, plan review, hard-to-reverse
  calls. Never bulk writing. A decision costly to get wrong never goes to `worker` or `scout`.
- **Implement** (`worker`): code, docs, tests from a decided plan, with the exact files and an acceptance
  command. More than 3 files or bulk -> `worker`; ≤3 known files stay inline (a cold start costs more).
- **Bulk (external)** (`gemini-delegate`, `agy`): mechanical writing or wide reading when that quota is the
  better spend; review the diff and run the acceptance command (ADR 0010).
- Superpowers subagents: implementer, routine reviewer -> `worker`; security/architecture reviewer -> `reasoner`; search -> `scout`.
- Planning: recommend the subagents (which, why) and ask. While executing, delegating per these rules is
  a standing instruction (it overrides the default "don't spawn agents unless asked"). The
  `critical-reasoning.sh` hook nudges toward `reasoner` once per session.
- Independent subtasks go in one message, in parallel. Parallel `worker`s on the same repo get one
  worktree each (`isolation: "worktree"`); on disjoint files they may share the tree.

Prefer `/clear` between unrelated tasks over `/compact`.
