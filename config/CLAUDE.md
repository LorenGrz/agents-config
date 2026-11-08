# Claude Code specifics

Claude Code-only additions on top of `AGENTS.md` (imported separately by the file that
pulls this one in — do not re-import it here).

## Skills

Invoke a matching skill before acting (`/<name>` or auto-activate); load only what the task needs.

Skills live in this repo's `<category>/<skill>/` directories, mirrored flat into
`~/.claude/skills` by `sync.sh` — run it after adding/moving a skill. Edit skills in the
repo, commit, push; see the repo's own README for the remote and any mirror clones you keep
in sync (profile-specific, not listed here).

Path-scoped rules in `~/.claude/rules/` load automatically when Claude touches a matching file (`paths:` frontmatter); some skills carry the same frontmatter.

Routing (by skill name). Stack skills (React, Next, Nest, persistence, API, auth, AWS) exist only in repos set up with `project-agents.sh`: check the repo's `.claude/skills` and AGENTS.md first.

- React: effects and lifecycle review `react-component-validator`; UI build/review `ui-builder`/`ui-review` (frontend-ui pack, installed per project).
- TypeScript quality: `typescript-code-quality`. New repo: `project-init` (interviews org + architecture first); new company/client: `org-creator`. Tooling upgrade of an existing project: `typescript-project-starter`.
- Roadmap planning: `roadmap-coach`. NestJS modules: `nest-module-generator`. Next.js SSR: `nextjs-ssr-frontend`.
- Persistence: `database-persistence-patterns`. API contracts: `api-contract-design`.
- Tests: `unit-test-generator` to write, `execute-test-suite` to run and fix.
- Debugging: `debug-assistant`. Docs: `code-documenter`. Regex: `regex-builder-explainer`. Commits: `conventional-commit-generator`.
- Security/auth: `auth-security-basics` only when relevant.
- Plugin skills overlap with the hub's; one default per task: planning `superpowers:brainstorming` then
  `superpowers:writing-plans`; TDD `superpowers:test-driven-development`; unknown-cause bugs
  `superpowers:systematic-debugging` (`debug-assistant` only for a pasted stack trace); TypeScript review
  `code-review-safety` (acting on feedback: `superpowers:receiving-code-review`); optional
  `mattpocock-skills:grilling` to stress-test an idea. Any git action goes through `git-workflow` first, not
  `superpowers:finishing-a-development-branch`.
- Plugins that only fit some stacks (`vercel`, `playwright`) are off globally and enabled per project by
  `scripts/project-agents.sh` (`config/scopes.json` `plugins`, or `--plugin`).
- AWS (`aws/`): `sam-deploy`, `lambda-patterns`, `iam-least-privilege` (always least privilege), `cost-optimizer`, `serverless-scanner` (migration analysis).
- Integrations (ADR 0016): Slack `slack-usage`; Jira/Confluence `jira-usage`; GitHub remote `github-usage`
  (local git flow stays `git-workflow`); Gmail/Calendar/Drive `google-workspace-usage`; Obsidian notes
  `obsidian-vault`; NotebookLM ↔ Obsidian `notebooklm-obsidian-sync`; cross-model review `codex-review`.
  Anything that sends, schedules, creates, merges, shares or deletes through these is shown and approved first.
- Desktop/OS config, PDFs, and other local-tool skills: check your profile
  (`config/profiles/<your-name>.md`) for any paths or skills specific to your own setup.

Rule files are guidance; hard constraints live in each repo's ESLint/CI/hooks (see `project-init`).

## Agent Routing

Pick the agent by role and task complexity, not by habit. The model behind each role is set in your profile ("Model routing").

- **Look up** (`scout`): light read-only lookups only.
- **Decide** (`reasoner`, or plan mode): architecture, unknown-cause bugs, plan review, hard-to-reverse calls. Never bulk writing.
- **Implement** (`worker`): common writing — code, docs, tests — from an already-decided plan; needs an acceptance command.
- **Bulk (external)** (`gemini-delegate` skill, `agy`): mechanical writing or wide reading when that quota is the better spend; review the diff and run the acceptance command (ADR 0010).

When superpowers dispatches subagents (`subagent-driven-development`, `executing-plans`, `dispatching-parallel-agents`, `requesting-code-review`), set `subagent_type`:

| Subagent role | subagent_type |
|---|---|
| Implementer | `worker` |
| Spec/code-quality reviewer (routine) | `worker` |
| Reviewer for security/architecture-critical changes | `reasoner` |
| File search / inventory | `scout` |

### When to delegate

- **Planning**: recommend whether subagents help (which roles, why) and ask before dispatching; never assume "always" or "never".
- Deciders (plan mode, `reasoner`) decide; the main session writes specs for subagents, reviews their results, and reports. The `critical-reasoning.sh` hook nudges toward `reasoner` on architecture, security, migrations, prod and unknown-cause work.
- Open lookups (paths not already known, sweeping directories or caches, web search, docs lookup, inventories) → `scout`, with one concrete question. Reading an already-known file to decide stays inline.
- Large changes (more than 3 files, or bulk/mechanical writing) → `worker`, with the decided spec, the exact files, and an acceptance command. Small changes to ≤3 known files stay inline: a subagent's cold start costs more than doing it.
- Decisions costly to get wrong (cross-module design, unknown-cause bugs, security) → `reasoner` or the main session, never `worker`/`scout`.
- Independent subtasks → dispatch in parallel in one message.
- Parallel `worker`s that touch the same repo → each in its own worktree (`isolation: "worktree"` or `superpowers:using-git-worktrees`); parallel workers on disjoint files may share the tree.
- While executing, delegating per the rules above is a standing instruction (it overrides the harness default "don't spawn agents unless the user asks"); while planning, ask first (first bullet).

Prefer `/clear` between unrelated tasks over `/compact`.
