# 0009 — `opusplan` as default model and a critical-reasoning hook

Status: model choice superseded by [0018](0018-opus-medium-default-reasoner-high.md); the hook stays.

## Context

ADRs 0003 and 0006 assumed the main session runs on Opus and delegates mechanical work. In
practice the main session kept doing lookups and small edits inline, so Opus tokens were
spent on work `scout`/`worker` handle fine, and prose rules lost to the harness default of
not spawning agents. Asking the user to switch models by hand does not scale either.

## Decision

- **Default model is `opusplan`** (`config/settings.base.json`): Opus in plan mode, Sonnet
  for everything else. Plans are always made by Opus without a manual switch; execution is
  cheap by default.
- **`config/hooks/critical-reasoning.sh`** on `UserPromptSubmit` and
  `PreToolUse(Edit|Write|MultiEdit)`: when the prompt or file looks costly to get wrong
  (architecture, security, migrations, prod, IAM, CI, unknown-cause bugs) it injects
  `additionalContext` telling the main session to delegate the decision to `reasoner` (Opus).
  It is silent inside subagents and always exits 0.
- The plugin marketplace method ships the hook too (`hooks/hooks.json`) but cannot pin the
  model; `opusplan` comes only from `install.sh`.

## Consequences

- A hook cannot switch the model, so the hook is a nudge, not enforcement. If it proves
  too weak, the next step is a stricter `PreToolUse` that asks before sensitive edits from
  the main session.
- The keyword/path lists are heuristics: expect false positives (cheap) and misses
  (acceptable; plan mode still runs on Opus).
- `opusplan` only reacts to real plan mode. A plain "make me a plan" in a normal turn stays
  on Sonnet.
- Anyone who prefers a single model overrides `model` in their own `settings.json` after
  `install.sh` (the merge makes base win for `model`, so edit `settings.base.json` in
  their clone instead).
