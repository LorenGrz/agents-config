# 0025 — Lane order and the grilling interview, enforced by a hook

Status: accepted (2026-11-13). Amends ADR 0022 ("the rule lives in `config/CLAUDE.md`, not in a hook") for
these two points.

## Context

ADR 0022 fixed the lane question's order as Continuar, Plan S, Plan L, with the recommended option marked but
not moved. On 2026-11-13 the agent still put the recommended option (Plan S) first. The tool description of
`AskUserQuestion` says "put the recommended option first", and in practice it beat the prompt text.

The same day, Loren asked for a mandatory interview before any plan, Plan S or Plan L: the agent asks
until nothing is left to assume, in line with the "no assumptions" rule of his profile.
`mattpocock-skills:grilling` already does this interview.

## Decision

- `config/hooks/lane-guard.sh`, registered as PreToolUse on `AskUserQuestion|ExitPlanMode`:
  - **AskUserQuestion:** if a question's options name lanes, they must be exactly Continuar, Plan S,
    Plan L, in that order. Otherwise the call is denied (exit 2) with the reason.
  - **ExitPlanMode:** the transcript must show `mattpocock-skills:grilling` loaded (as a Skill call or as
    the slash command) after the last `EnterPlanMode`. When plan mode was entered by hand (no
    `EnterPlanMode` call), any grilling earlier in the session counts. Otherwise the call is denied.
  - Subagents are not checked. The hook also lets the call through when the transcript can't be read.
- The flow (lanes and interview) moves to `config/AGENTS.md` "Workflow lanes", agent-neutral, because it is how Loren works with any agent; `config/CLAUDE.md` keeps only the Claude Code mechanics (`AskUserQuestion`, `EnterPlanMode`, PonyTail, the hook). Grilling comes first, then the plan. In Plan L, `brainstorming`
  follows without asking again what was already answered. That ordering was an assumption stated to
  Loren when the change was made.
- The `critical-reasoning.sh` and `session-start.sh` reminders restate both rules.

## Consequences

- The order and the interview can no longer be skipped silently. A denied call comes back to the agent
  with the reason, and the agent retries.
- Every plan costs one interview: about 1–2k tokens when the skill loads, plus the questions.
- The hook depends on Claude Code's transcript format (JSONL with `tool_use` blocks). If that format
  changes, the ExitPlanMode check fails closed and denies every plan until the hook is fixed.
- Checked with `scripts/test-lane-guard.sh` (15 offline cases).
