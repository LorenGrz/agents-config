# 0010 — Delegating work to Gemini through `agy`

## Context

Antigravity CLI (`agy`) is installed and already reads the same rules and skills as Claude
Code (ADR 0002). Loren has Google quota that sat unused while Anthropic tokens paid for
bulk reading and mechanical writing.

## Decision

- **`meta/gemini-delegate`**: a skill plus `scripts/gemini-delegate.sh` with two modes:
  `run` (headless `agy -p`, the main session waits and reviews the diff) and `open`
  (interactive `agy -i` in a tmux split or the default terminal, for the user to drive).
- **No subagent.** A subagent's cold start costs Anthropic tokens; the main session calls
  the script through Bash.
- **`--dangerously-skip-permissions` in `run`**, chosen by the user, protected by a guard:
  the script refuses a dirty worktree (exit 2) unless `--allow-dirty`, so Gemini's edits are
  exactly the diff and can be reviewed or discarded.
- `Bash(*gemini-delegate.sh *)` is allowed in `config/settings.base.json`; bare `agy` still
  asks.

## Consequences

- Gemini sees the repo, rules and skills but not the conversation; the spec must be complete.
- Output quality is not guaranteed: the main session always reviews the diff and runs the
  acceptance command.
- Depends on `agy` being installed and on Google quota/availability; the model name
  (`gemini-3.8-flash-high`) may change, hence `GEMINI_DELEGATE_MODEL`.
