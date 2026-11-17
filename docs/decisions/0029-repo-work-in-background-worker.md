# 0029 — Repo work goes to a background worker by default

Status: accepted (2026-11-17). Amends the "≤3 known files stay inline" rule of `config/CLAUDE.md`
"Agent Routing" and the "`worker` only from an approved plan" limit.

## Context

The previous rule kept changes of up to 3 known files in the main session, and allowed `worker` only
inside an approved plan. While a small front fix ran inline, Loren could not keep working with the main
session. On 2026-11-17 he asked for the opposite default: the repo work goes to a worker, and he keeps
talking with the main session.

## Decision

- Every non-trivial change in a repo goes to a `worker`, inside or outside a plan, run in the background
  (`run_in_background`) in its own worktree on the task branch.
- The brief carries the exact files, the decided change and an acceptance command, and tells the worker to
  read the repo's `AGENTS.md`/`CLAUDE.md` and `.claude/skills` first and not to commit or push.
- The main session reviews the diff and the reported checks, and commits.
- Trivial changes (one line, or one file with no checks: a typo, a copy text, a config value) stay inline.
- The lane question (Continuar / Plan S / Plan L) and the org rules do not change.

## Consequences

- The main session stays free while code is written, at the cost of a cold start per task.
- A worker cannot see the conversation: a thin brief gives a wrong change, so the brief is the main
  session's job.
- Written in `config/CLAUDE.md` "Agent Routing", `config/AGENTS.md` "Workflow lanes", the
  `session-start.sh` reminder and the profile's "Model routing".
