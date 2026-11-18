# 0032 — Stacked PR branches kept up to date by a timer

Status: accepted (2026-11-18). Builds on 0029 (one worktree per task) and 0030 (worktree cleanup).

## Context

Loren stacks PRs: a branch is cut from another branch whose PR is still open. When the lower PR gets review
changes, or is merged into `dev` with squash, the upper branch is left behind or starts conflicting with
`dev`, and someone has to merge by hand in the right worktree. On 2026-11-18 he asked for this to happen by
itself, in the worktree of each branch, without touching the others; conflicts resolved by an agent.

## Decision

- `scripts/stack-sync.sh`, run every 10 minutes by a systemd user timer installed with
  `scripts/stack-sync-install.sh` (opt-in, per machine; `--remove` undoes it).
- Scope: Loren's open PRs (`gh pr list --author @me`) in the repos of one GitHub owner found under some
  root folders, both set in `~/.config/stack-sync/config` (not committed), each processed only in the
  local worktree of its branch, lower PRs first.
- Per PR: base PR merged → merge `origin/<trunk>`, push, retarget to the trunk; base branch with new
  commits → merge `origin/<base>`, push; trunk-based PR that conflicts → merge `origin/<trunk>`, push.
- A conflicting merge is aborted and a visible Claude agent is opened in that worktree with
  `orca agent launch` (it needs no coordinator, so it works from a timer) with a fixed spec: resolve, run
  the repo checks, commit the merge, push, `notify-send` the result. One launch per (PR, base commit).
- Never rebase, force or amend; a dirty worktree, or one whose HEAD is not the PR head (unpushed commits
  or behind), is skipped and logged. Pushing without asking follows Loren's standing OK to push in his work
  org; opening or merging PRs still needs his OK.
- Actions go to `notify-send` and `~/.local/state/stack-sync/stack-sync.log`; skips only to the log.
  `--dry-run` lists what it would do. Tested offline by `scripts/test-stack-sync.sh`.

## Consequences

- Stacks follow their base within 10 minutes; the retarget after a merge is no longer manual.
- An agent may push a conflict resolution on its own; the repo checks are its gate.
- `orchestration worker-start` is not used here: outside an Orca terminal it needs `--from` with a
  coordinator's handle, which a timer does not have.
