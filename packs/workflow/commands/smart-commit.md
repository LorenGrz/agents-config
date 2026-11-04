---
description: Group the current changes into semantic commits and commit them. Uses the session summary (/smart-compact) as the source of intent. $ARGUMENTS - optional context for the messages.
argument-hint: optional context for the commit messages
---

Optional context for the messages: `$ARGUMENTS`

## Source of intent

The diff says what changed; the conversation says why. If `/smart-compact` ran in this session, one topic group is roughly one commit, but validate it first: every file in `git status --short` must fall in a group, nothing in it may already be committed (`git log --oneline`), and later edits or reverts make it stale (then extend it mentally, do not discard it). With no conversation (fresh session on a dirty tree), work from the diff only and say the bodies will be thinner.

## Rules

- Inspect first: `git status --short`, `git diff --stat`, `git diff`, `git log --oneline -10` (scope and granularity; not the language).
- Group by intent (feat, fix, refactor, test, docs, chore...). Never mix unrelated changes in one commit.
- Conventional Commits: `type(scope): imperative summary`, 72 characters or fewer, in English unless `AGENTS.md` says otherwise. Add a body only when the why is not deducible from the code (a measurement, a rule, a deliberate deviation, coupling between files); otherwise subject only.
- Follow the repo's commit and attribution rules in `AGENTS.md`.
- Items marked `undone:` in the summary never appear in a message. If one still shows in the diff, the revert is half done: show the file and ask before staging.
- Pending work with files in the diff goes in its own `wip(scope):` commit whose body says what is missing and untested.
- Before staging, look for `.env`, tokens, keys, credentials, connection strings. If any appears, stop and ask.
- Never `--no-verify`, `amend` existing commits, `push --force` or revert existing changes.

## Flow

1. State the source in one line (`Source: this session's summary, current` / `extended with N later changes` / `diff only`) and show the planned commits mapped to topics before touching anything. Ask only when a file could belong to two groups.
2. For each group, in order: `git add <explicit files>` (never `git add .` unless the whole tree is one group), confirm with `git status --short`, then commit with `git commit -F - <<'EOF' ... EOF`. If `AGENTS.md` says the user commits, stop after staging and hand over the command instead.
3. Do not push. When all commits exist, run the project's checks against the committed state if it has such a script, then summarize the groups and print the updated `## Pending`.
