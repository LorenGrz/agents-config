# 0031 — Plan S without the grilling interview

Status: accepted (2026-11-18). Amends ADR 0025 for the interview; the lane order stays as it is.

## Context

ADR 0025 made the grilling interview mandatory before any plan, Plan S or Plan L. On 2026-11-18, after a
Plan S that took three rounds of questions, Loren asked: «a partir de ahora el plan corto no va a tener
entrevista, sino para lo crítico me va a hacer las preguntas clave de decisiones importantes, dejamos la
entrevista para el plan L con subagentes y que estos se envíen a los worktree que correspondan». He also
asked for shorter lane options («directo», «plan corto», «plan complejo»).

## Decision

- **Plan S:** no interview. The agent investigates and asks, in one batch, only the critical decisions it
  can't deduce.
- **Plan L:** keeps the grilling interview, and its work goes to subagents or workers, each one in the
  worktree of the branch it touches.
- `lane-guard.sh` requires grilling at `ExitPlanMode` only when the last lane picked in the session (an
  `AskUserQuestion` answer `="Plan L…"`) is Plan L. Plan S, or a plan with no lane question, is not
  checked.
- The lane options carry minimal descriptions.

## Consequences

- A plan the user starts directly, with no lane question, is no longer forced through an interview; the
  agent asks the critical questions as in Plan S.
- `config/AGENTS.md`, `config/CLAUDE.md`, `session-start.sh` and `critical-reasoning.sh` restate the new
  rule; `scripts/test-lane-guard.sh` covers Plan S, Plan L and the last-lane-wins case.
