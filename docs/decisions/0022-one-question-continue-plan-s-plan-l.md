# 0022 — One question decides the process: Continuar, Plan S or Plan L

Status: accepted (2026-11-09); hook enforcement of the order and the grilling interview added in ADR 0025. Supersedes the lane selection of ADR 0020 and narrows ADR 0006 (delegation
applies to work that comes out of an approved plan).

## Context

ADR 0020 asked every plan to pick lane S or L. That left two gaps. Work done without a plan had no rule, and
`using-superpowers` (injected in every session) pushes `brainstorming` "before any creative work", so small
tasks could still pull in the heavy process. And choosing a process took two steps: "plan?" and then "S or L?".

The fixed text is not where the cost is. The lanes section is ~0.2k tokens of a ~17.6k floor. The cost is per
task: `brainstorming` (15.2 KB), `writing-plans` (10.3 KB) and `subagent-driven-development` (19.7 KB) add up
to ~11k tokens when they load, and each `worker` or `reasoner` cold start adds ~4–6k.

## Decision

- **Punctual change** (one file, clear intent): done directly. No question, no plan, no lane.
- **More than one file, or unclear scope** (unknown-cause bugs included): before editing, one
  `AskUserQuestion` with exactly three options, always in this order:
  - **Continuar:** direct, no plan.
  - **Plan S:** plan mode with a short plan (files, change, check), executed inline, with no brainstorming,
    no spec docs and no `worker`/`reasoner`.
  - **Plan L:** plan mode with `brainstorming`, then `writing-plans` in `docs/superpowers/`, then
    `worker`/`reasoner`, or caolg across repos.

  The recommended option is marked with one line of why, without reordering. Plan S or L enters plan mode
  (`EnterPlanMode`). An unknown cause starts with `systematic-debugging`. A plan mode the user enters directly
  ends with "Plan S/L because …".
- **Outside a plan**, `brainstorming`, `writing-plans`, `executing-plans`, `subagent-driven-development`,
  `worker` and `reasoner` are not invoked unless asked. This overrides `using-superpowers`, which itself
  ranks user instructions above skills. `scout` stays allowed for open lookups: it keeps file dumps out of
  the main window.
- **No assumptions** (personal rule, in the profile): when scope, a requirement or a choice is unclear,
  ask, even on trivial tasks; assume only when the user says so. It is a stricter `karpathy-guidelines` §1.
- **The rule lives in `config/CLAUDE.md`, not in a hook.** Entering plan mode through `EnterPlanMode` sends
  no new prompt, so `UserPromptSubmit` would not fire there. `critical-reasoning.sh` now asks for the
  three-option question, and names `reasoner` for Plan L; `session-start.sh` restates the rule in one line.

## Consequences

- Checked live with `claude -p --model sonnet` in a two-file scratch project:
  - A one-file request was done directly.
  - A two-file request stopped with the three options in order, recommended one, and asked about an
    ambiguity instead of assuming. No file was edited.
- In `claude -p` there is no interactive `AskUserQuestion`, so the question comes back as text.
- `config/CLAUDE.md` stays at 60 lines and 4.2 KB.
- Codex and the other CLIs are unaffected: plan mode and the question are Claude Code features.
