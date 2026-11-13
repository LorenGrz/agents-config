---
name: codex-review
description: Use when the user wants a second-opinion code review from Codex before a PR, on risky changes (auth, migrations, data), or delegates a task to Codex, via the codex plugin (openai/codex-plugin-cc) commands /codex:review, /codex:adversarial-review, /codex:rescue.
---

# Codex Review

## Objective

Get a second-opinion review from Codex before a PR or on risky changes, and treat the result as advisory.

## Prerequisites

The codex plugin (`openai/codex-plugin-cc`) commands:

- `/codex:review --base <branch>`: standard review of the diff; run before opening a PR.
- `/codex:adversarial-review`: use for risky changes (auth, migrations, data handling).
- `/codex:rescue`: only when the user wants Codex to edit files. It modifies the checkout; check `git status` first and review the diff after.
- `/codex:status`, `/codex:result`, `/codex:cancel`: manage running jobs.

## Workflow

1. Run the project's tests and lint first so Codex does not report known failures.
2. Pick the command by risk level; pass `--base <branch>` matching the PR target.
3. Read the result with `/codex:result` when the job finishes.
4. Report: confirmed findings, rejected findings with reason, what changed.

## Rules

- In a repo that matches an organization, use that organization's replacement skill when one is installed (e.g. in `.claude/skills/`); its rules win.
- NEVER enable the stop review gate (`/codex:setup --enable-review-gate`): it loops and burns quota.
- The code goes to OpenAI. Skip Codex for repos with confidential or org-restricted code unless the organization's policy allows it; check `POLICIES.md` when in doubt.
- The review is advisory: verify each finding against the code and discard false positives. Do not apply fixes automatically; list findings by severity, then fix what the user approves.

## Shortcuts
<!-- parsed by scripts/gen-intents.sh -->
- intent: Codex review — `revis[aá]lo con codex|segunda opini[oó]n|codex review|review (it )?with codex|second opinion` → `/codex:review (or /codex:adversarial-review for risky changes); never enable the review gate`
