---
description: Write the PR title and body for the current branch from the commits of this work, ready to paste. Does not push or create the PR. $ARGUMENTS - optional context (ticket, review focus).
argument-hint: optional context - ticket, audience, what to stress
---

Optional context: `$ARGUMENTS`

## Source: the commits that will merge

Base = the merge base with the project's base branch (`git merge-base origin/<base> HEAD`; the base is in `AGENTS.md`, `dev` by default). Use:

- `git log <base>..HEAD --format='%h %s%n%b'`: the why is already in the commit bodies.
- `git diff <base>...HEAD --stat` and the diff: the what, and a check that no commit went uncounted.
- `git status --short`: only to spot what is NOT included. Uncommitted work on the same topic is flagged before the message (`Outside the PR: <files>`) and never described in the body.

If the branch carries commits from earlier work that were already reviewed, ask where this PR starts instead of guessing.

## Form

- Title: Conventional Commit, English, 72 characters or fewer. One commit: its subject. Several: the theme that ties them, not the last one's.
- Body language: the project's (`AGENTS.md`); sections as `##` with these names, in this order. If `.github/PULL_REQUEST_TEMPLATE.md` defines other headings, follow those instead.
- No empty sections: if one does not apply, say why in one line. Omit `Screenshots` entirely when the PR does not touch UI.
- Short prose and lists. No emojis, no decorative bold, no sign-offs. Paths as `path:line` when useful; no pasted diffs.

## Sections

1. **Summary**: two or three sentences, what problem it solves and what changes for the user. Not the how.
2. **Decisions**: one item per decision, not per file. Must include what a reviewer cannot deduce from the diff: measured backend/API quirks and changed contracts, breaking changes (who else uses it), migrations, new env vars, deliberate deviations from a project rule with the reason.
3. **What to review**: at most three pointers to concrete places (`path:line`) and what could be wrong there: untested edges, changes that hit outside their module, a decision taken with doubt (say it as a doubt). End with one line on what can be skimmed (renames, moves, formatting, generated churn). If nothing is risky: "Contained change, no hot spots."
4. **How to test**: preconditions (including data), steps from a concrete entry point, verifiable expected result; then the automated checks you ran with their real result. If you did not run them, say so.
5. **Screenshots** (UI only): one per touched screen, before/after for existing ones; a `<!-- pending: screenshot of X -->` placeholder when you have none.
6. **Not in this PR**: only what has evidence (`wip` commits, `TODO`s touched, follow-up docs, limits the user decided), with the reason and a link if there is a ticket. Never invent debt: "No known pending work in this scope." is a valid answer.

## Delivery

One code block ready to paste, with warnings (no commits, ambiguous base, uncommitted work, checks not run) outside it. Do not push, create the PR or call `gh` unless `$ARGUMENTS` asks; then block first, OK second, `gh` last. Follow the repo's attribution rules.
