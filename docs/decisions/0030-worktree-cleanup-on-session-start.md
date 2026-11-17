# 0030 — Merged-PR worktrees are deleted when a session starts

Status: accepted (2026-11-17). Follows 0029 (every non-trivial repo change runs in its own worktree).

## Context

Since 0029 each task lives in a sibling worktree of the repo (for example `repo-frontend-abc-123` next to
`repo-frontend`). Nobody removes it after the PR is merged, so orphan worktrees and local branches pile up.
Git cannot tell that a task is done: the repos merge with squash and keep the remote branch, so the branch
is never an ancestor of the base. The only reliable signal is the PR on GitHub. On 2026-11-17 Loren asked
for the worktree of a task to be deleted by itself when a session opens once its PR is merged.

## Decision

- A second `SessionStart` hook, `config/hooks/worktree-cleanup.sh`, registered in `settings.base.json`
  next to `session-start.sh`. It reads `cwd` from the hook JSON (`$PWD` as fallback).
- Scope: if the cwd is inside a git repo, the linked worktrees of that repo; if it is a folder that groups
  repos (not a repo, children with their own `.git`), the linked worktrees of each. Never the main
  worktree, never the worktree that contains the cwd.
- A linked worktree with a branch is deleted only when all of these hold:
  1. `git status --porcelain` is empty;
  2. `gh pr list --repo <owner/repo of origin> --head <branch> --state merged` returns a PR;
  3. that PR's `headRefOid` equals the worktree's `HEAD`, so a later local commit is never lost.
  Then `git worktree remove <path>` (no `--force`: if git refuses, nothing is touched) and
  `git branch -D <branch>` in the main repo (`-d` fails after a squash merge; `-D` is safe because of 3).
- Never touched: the remote branch, the main worktree, a dirty worktree, one with commits the PR does not
  have, locked or detached ones, and the branches `main`, `master`, `dev`, `develop`.
- Time budget of about 10 seconds for the whole run, with a `timeout` per `gh` call. No `gh`, no network or
  any other failure: exit 0 in silence. The hook never breaks a session.
- Output: when it deleted something, one line per worktree as `additionalContext`
  ("worktree-cleanup: borré <path> (rama <branch>, PR #<n> mergeado)"); nothing otherwise.
- On demand: `bash ~/.claude/hooks/worktree-cleanup.sh --cwd <dir>` prints a plain-text summary, and
  `--dry-run` only lists what it would delete. It is the "limpiar worktrees" shortcut of `github-usage`.
- Tested offline by `scripts/test-worktree-cleanup.sh` (temp repos and a fake `gh`).

## Consequences

- Finished task worktrees disappear without a manual step, at the cost of up to 10 seconds in the worst
  case at session start (a slow `gh`), and only when the session opens in the repo or its folder.
- It deletes without asking, which is what Loren requested; the guard is the exact-head check, so
  unmerged or extended work is left alone.
- A worktree whose PR was merged but whose head moved afterwards stays until it is removed by hand.
