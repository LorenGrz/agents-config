# 0018 — Opus at medium effort as default; planning at high via `reasoner`

Status: accepted (2026-11-09). Supersedes the model choice in [0009](0009-opusplan-and-critical-reasoning-hook.md)
(the critical-reasoning hook from 0009 stays).
The medium effort is superseded by [0024](0024-opus-high-effort-and-terminal-images.md): the main session runs at high.

## Context

ADR 0009 made `opusplan` the default: Opus in plan mode, Sonnet for everything else. The owner now
wants the main session to be Opus at **medium** effort, and planning at **high**.

Claude Code has no per-mode effort. `effortLevel` and `modelSettings.<model>.effortLevel` are
per model. With `model: opus`, plan mode is Opus too and shares the session effort, so "plan mode at
high" cannot be a setting.

## Decision

- `config/settings.base.json`: `"model": "opus"`, `"effortLevel": "medium"` and
  `modelSettings.claude-opus-5-5.effortLevel = "medium"`. The per-model entry is the one that
  matters: the docs say a top-level `effortLevel` in user settings is ignored by Opus 5.5 and later,
  and a model's own `effortLevel` beats the top-level one in the same file.
- `install.sh` merge: base wins for `model`, `effortLevel` and the `modelSettings` keys it defines
  (a stale local `high` for Opus is replaced); other models' `modelSettings` are kept.
- Planning at high effort goes through the `reasoner` subagent (Opus), whose frontmatter now has
  `effort: high` (documented: it overrides the session effort; `CLAUDE_CODE_EFFORT_LEVEL` still wins). Native plan mode stays at the session effort (medium); raise it by hand with
  `/effort high` for a hard plan.

## Consequences

- Main-session cost goes up (Opus instead of Sonnet for execution); medium effort offsets part of it.
- The routing text (`config/CLAUDE.md`, `session-start.sh`, profile) no longer says "Sonnet via
  `opusplan`": `worker` (Sonnet) still implements, the main session (Opus) delegates and reports.
- "Planning at high" is only guaranteed when the plan is made by `reasoner` or after `/effort high`.
  If Claude Code later adds a per-mode effort setting, switch to it and supersede this ADR.
- The `modelSettings` key is the canonical model name (`claude-opus-5-5`): when a new Opus ships, add
  its key to the base or it starts at its own default.
- The marketplace install method still cannot pin the model or effort; both come only from `install.sh`.
