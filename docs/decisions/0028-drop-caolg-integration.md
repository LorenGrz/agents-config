# 0028 — Drop the caolg integration

Status: accepted (2026-11-16). Supersedes ADR 0021 and the "CAO mode" part of ADR 0020.

## Context

caolg (a separate repo wrapping CAO in tmux) was the way to run a leader agent with workers across repos.
Loren stopped using it and switched to Orca, which runs the same kind of workers but leaves the repositories
clean. agents-config still carried code that only made sense under caolg: hooks that went quiet when
`CAO_TERMINAL_ID` was set, a statusline that wrote two cache files for caolg's bar and pane borders, an
`opencode-cao` baseline target for OpenCode launched by CAO, and an `agent_providers` key in `org.json` that
only caolg's leader read.

## Decision

- `session-start.sh`, `critical-reasoning.sh` and `intent-router.sh` no longer check `CAO_TERMINAL_ID`; they
  behave the same in every session. The rest of ADR 0020 (context budget, once-per-session reasoner reminder,
  task-notification heuristic) stays.
- `statusline.sh` only draws the line. It no longer writes `~/.cache/claude/rate-limits.json` or
  `~/.cache/claude/ctx/<id>.json`; nothing else read them.
- `gen-cli-baselines.sh` drops the `opencode-cao` target (`~/.aws/opencode`).
- `agent_providers` is removed from the org template and the organizations README.
- Mentions of caolg in `config/CLAUDE.md`, the profile and `.agents/CONTEXT.md` are removed. Orca is not named
  in their place: how agents-config should route work to Orca is a separate decision.
- Older ADRs and plans keep their text as history; only their status line points here.

## Consequences

- A Claude session inside a CAO pane, if CAO is ever used again, gets the full routing and reminders like any
  other session.
- `CLAUDE_CODE_FORCE_TERMINAL_IMAGES=1` (ADR 0024) stays: it helps any session inside tmux, not only caolg.
- The tests for the CAO cases in `test-intents.sh`, `test-packs.sh` and `test-cli-baselines.sh` are gone.
