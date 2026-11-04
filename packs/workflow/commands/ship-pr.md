---
description: End to end without asking - commit the changes in semantic groups, push, and open the PR against the base branch with the /pr-message body. $ARGUMENTS - optional context.
argument-hint: optional context - ticket, review focus
---

Optional context: `$ARGUMENTS`

Running this command is the explicit authorization to commit and push in this run. Follow `/smart-commit` and `/pr-message` exactly, except:

- You commit each group yourself and do not ask for approval of the plan: print one line per group as you go.
- You push and open the PR. Do not ask anything except in "When to stop".

## Flow

1. **Branch**: on the base branch or `main`, create `<type>/<slug>` (or `scripts/gh-flow.sh start <type> <slug> --issue N` if there is an issue); confirm with `git ls-remote --heads origin <branch>` that it does not exist. Otherwise keep the current branch.
2. **Fresh base**: `git fetch origin`; check the branch descends from `origin/<base>` and say so in the final summary if not. Never rebase on your own.
3. **Commits**: the full `/smart-commit` flow.
4. **Checks**: run lint, typecheck and tests from the Commands table in `AGENTS.md` and record each real result; they go into `How to test`.
5. **PR**: write the body per `/pr-message` to a file in the scratchpad (not inline: heredocs and backticks break the markdown). Run `bash scripts/gh-flow.sh pr --title "<title>"` (it runs the checks, pushes without force and opens the PR), then `gh pr edit --body-file <file>`. If the branch already has an open PR, only edit it.
6. **Summary**: PR link, commits (sha and subject), checks with results, the `## Pending` block.

Screenshots: do not take them; leave a placeholder per touched screen and list the ones still missing.

## When to stop

Do not push or open the PR; say what happened and what is needed: (1) something sensitive in the diff, (2) an `undone:` item that survived in the diff, (3) a failing check. Do not fix a failing check with a reflex new commit: say what failed and in which group the file lives. A genuinely ambiguous file grouping is not a reason to ask: choose, and write the choice in one line of the summary.
