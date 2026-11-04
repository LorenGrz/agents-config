@AGENTS.md
@.agents/CONTEXT.md

# Claude-only notes

AGENTS.md above is the source of truth for this repo. This file only maps the workflow phases to superpowers skills for Claude Code sessions. `.agents/CONTEXT.md` is imported too - it's capped at ~60 lines (see its own comment) specifically so every session can afford to load it automatically instead of needing a separate read.

| Phase | Skill |
|---|---|
| New work item | `scripts/gh-flow.sh issue <type> "<title>"` |
| Non-trivial feat/refactor | `brainstorming` -> spec in `docs/superpowers/specs/` |
| Planning | `writing-plans` -> plan in `docs/superpowers/plans/` |
| Bug fix | `systematic-debugging` |
| Parallel work | `using-git-worktrees` |
| Implementation | `subagent-driven-development` + `test-driven-development` |
| Before opening a PR | `verification-before-completion` |
| Branching/PR/merge | `scripts/gh-flow.sh start\|pr\|merge\|release` |

`.claude/hooks/guard-branch.sh` blocks `git commit`/`git push` against `dev` or `main` directly - use `scripts/gh-flow.sh` instead. `.claude/hooks/lint-on-edit.sh` runs {{LINT_HOOK_DESC}} and reports errors back to the agent immediately.
