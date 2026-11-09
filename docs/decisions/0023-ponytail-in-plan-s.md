# 0023 — PonyTail, only in Plan S

Status: accepted (2026-11-09). Completes ADR 0022 (Plan S) and settles the PonyTail trial left open in ADR 0020.

## Context

Plan S is the light path: a short plan executed inline (ADR 0022). PonyTail (`DietrichGebert/ponytail`,
5.3.3, MIT) is a Claude Code plugin that biases the agent toward the smallest complete change: reuse what
exists, stdlib first, no unrequested abstractions. Its published savings are its own claims.

What the code does, read before installing:
- **Hooks.** Three Node hooks: SessionStart, SubagentStart and UserPromptSubmit.
- **Default mode.** `full`, active in every session. `PONYTAIL_DEFAULT_MODE` or `~/.config/ponytail/config.json`
  change it. With `off`, the SessionStart hook writes nothing (`hooks/ponytail-activate.js`).
- **Changing the mode.** It changes only when the user types `/ponytail` (the UserPromptSubmit hook reads the
  user's prompt).
- **The band.** A UI module ("band") above the prompt writes one CSV row per turn to
  `~/.config/ponytail/band/` unless the plugin option `ledger` is `false`. The file `~/.claude/.ponytail-band`
  containing `off` hides it.
- **Network.** Only an optional webhook, empty by default. It runs `git ls-files` for its repo map.
- **Cost.** `claude plugin details`: ~641 tokens always on (six skill descriptions); the `ponytail` skill
  costs ~1.1k each time it is invoked.

## Decision

- **Installed and enabled globally**, but **off by default**. `settings.base.json` enables it and sets
  `env.PONYTAIL_DEFAULT_MODE = "off"` and `pluginConfigs["ponytail@ponytail"].options.ledger = false`.
- **Plan S loads it explicitly.** `config/CLAUDE.md`: Plan S runs inline with the `ponytail:ponytail` skill
  loaded when execution starts. Outside Plan S no `ponytail*` skill is invoked unless asked, whatever their
  descriptions say ("use on any coding task").
- **`install.sh`** merges `env` and `pluginConfigs` the same way it merges `enabledPlugins` (base wins on
  its keys, user keys survive; plugin options deep-merged). It also creates `~/.claude/.ponytail-band`
  containing `off` once, never overwriting the user's own choice.

## Consequences

- Every session pays ~641 tokens for the skill list, Plan S sessions ~1.1k more when the skill loads, and
  other sessions nothing more: with mode `off` the hooks add no context.
- Typing `/ponytail` turns it on for the rest of a session; "stop ponytail" turns it off.
- Third-party code runs on every session start and prompt (Node hooks, plus the band module in the UI).
  Updating the plugin pulls new code: review the diff before `claude plugin marketplace update ponytail`.
- A plugin installed mid-session is only available from the next session.
