# 0003 — Model routing by task complexity, not by habit

> Partly superseded by [0009](0009-opusplan-and-critical-reasoning-hook.md) and then [0018](0018-opus-medium-default-reasoner-high.md): the main session runs on Opus at medium effort; deep decisions go to `reasoner` (effort high).

> The "≤3 known files inline" rule below is narrowed by [0006](0006-always-delegate.md): it applies to known files only; open lookups go to `scout`.

## Context

Three model-pinned subagents exist (`scout` = Haiku, `worker` = Sonnet, `reasoner` = Opus,
`config/agents/*.md`), and superpowers dispatches subagents for implementer, reviewer, and
search roles during `subagent-driven-development`, `executing-plans`,
`dispatching-parallel-agents`, and `requesting-code-review`. Without an explicit rule, it is
easy to default every dispatch to the main session's model (Opus) regardless of what the
step actually needs, which is slow and token-expensive for mechanical work, or to default
everything to Sonnet, which under-uses Opus for the decisions that actually benefit from it.

## Decision

Route by what the step *does*, not by which agent is "better":

- **Opus** (main session / `reasoner`) only reasons and decides: architecture, unknown-cause
  bugs, plan review, hard-to-reverse calls. It does not do worker-type writing.
- **Sonnet** (`worker`) writes all code/docs from an already-decided plan.
- **Haiku** (`scout`) does light read-only lookups only.

Superpowers' `subagent_type` follows the same split: implementer tasks → `worker`;
spec/code-quality reviewers → `worker` for routine review, `reasoner` only when the change
is security- or architecture-critical; file searches/inventories → `scout`.

Below that, skip the subagent entirely: a change touching ≤3 known files is cheaper done
inline than paying a subagent's cold-start cost.

This is recorded in `config/CLAUDE.md`'s "Agent Routing" section (kept short — that file
loads every session) rather than duplicated in `AGENTS.md`, which already carries the
Codex-facing orchestration rules.

## Consequences

- Reviewers and other agents can predict which model a given dispatch will use without
  re-deriving it from scratch each time.
- Opus time is spent on decisions, not on mechanical writing it would do no better (and
  slower, more expensively) than Sonnet.
- If a `worker` dispatch fails its acceptance check twice, or a reviewer's first hypothesis
  doesn't reproduce, escalate to `reasoner` rather than retrying the same tier — this is the
  existing escalation rule in `config/CLAUDE.md`'s Agent Routing section and is unchanged by this
  ADR.
