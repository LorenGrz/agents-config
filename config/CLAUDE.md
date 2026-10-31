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

Routing (by skill name):

- React build/refactor: `react-scalable-frontend`. React review: `react-component-validator`.
- TypeScript quality: `typescript-code-quality`. New repo scaffolding: `project-init`. Tooling upgrade of an existing project: `typescript-project-starter`.
- Roadmap planning: `roadmap-coach`. NestJS modules: `nest-module-generator`. Next.js SSR: `nextjs-ssr-frontend`.
- Persistence: `database-persistence-patterns`. API contracts: `api-contract-design`.
- Tests: `unit-test-generator` to write, `execute-test-suite` to run and fix.
- Debugging: `debug-assistant`. Docs: `code-documenter`. Regex: `regex-builder-explainer`. Commits: `conventional-commit-generator`.
- Security/auth: `auth-security-basics` only when relevant.
- AWS (`aws/`): `sam-deploy`, `lambda-patterns`, `iam-least-privilege` (always least privilege), `cost-optimizer`, `serverless-scanner` (migration analysis).
- Desktop/OS config, PDFs, and other local-tool skills: check your profile
  (`config/profiles/<your-name>.md`) for any paths or skills specific to your own setup.

Rule files are guidance; hard constraints live in each repo's ESLint/CI/hooks (see `project-init`).

## Agent Routing

Pick the model by task complexity, not by habit:

- **Main session** runs on Sonnet via `opusplan`: Opus in plan mode, Sonnet otherwise (ADR 0009).
- **Opus** (plan mode / `reasoner`) only reasons and decides — architecture, unknown-cause bugs, plan review, hard-to-reverse calls. Never does worker-type writing.
- **Sonnet** (`worker`) writes all code/docs from an already-decided plan.
- **Haiku** (`scout`) does light read-only lookups only.
- **Gemini** (`gemini-delegate` skill, `agy`) for bulk mechanical writing or wide reading when Google's quota is the better spend; always review the diff and run the acceptance command (ADR 0010).

When superpowers dispatches subagents (`subagent-driven-development`, `executing-plans`, `dispatching-parallel-agents`, `requesting-code-review`), set `subagent_type`:

| Subagent role | subagent_type |
|---|---|
| Implementer | `worker` |
| Spec/code-quality reviewer (routine) | `worker` |
| Reviewer for security/architecture-critical changes | `reasoner` |
| File search / inventory | `scout` |

### When to delegate

- Plan mode (Opus) and `reasoner` decide; the main session (Sonnet) writes specs for subagents, reviews their results, and reports. The `critical-reasoning.sh` hook nudges toward `reasoner` on architecture, security, migrations, prod and unknown-cause work.
- Open lookups (paths not already known, sweeping directories or caches, web search, docs lookup, inventories) → `scout`, with one concrete question. Reading an already-known file to decide stays inline.
- Large changes (more than 3 files, or bulk/mechanical writing) → `worker`, with the decided spec, the exact files, and an acceptance command. Small changes to ≤3 known files stay inline: a subagent's cold start costs more than doing it.
- Decisions costly to get wrong (cross-module design, unknown-cause bugs, security) → `reasoner` or the main session, never `worker`/`scout`.
- Independent subtasks → dispatch in parallel in one message.
- Parallel `worker`s that touch the same repo → each in its own worktree (`isolation: "worktree"` or `superpowers:using-git-worktrees`); parallel workers on disjoint files may share the tree.
- Standing user instruction: it overrides the harness default "don't spawn agents unless the user asks".

Prefer `/clear` between unrelated tasks over `/compact`.
