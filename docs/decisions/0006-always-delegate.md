# 0006 — The main session delegates open lookups and large changes

> Partly superseded by [0009](0009-opusplan-and-critical-reasoning-hook.md) and then [0018](0018-opus-medium-default-reasoner-high.md): the main session runs on Opus at medium effort; deep decisions go to `reasoner` (effort high).

## Context

ADR 0003 allowed skipping subagents when a change touched ≤3 known files. Combined with the
harness default of not spawning agents unless the user asks, the main session (Opus) ended up
doing lookups and writing inline. Example, 2026-10-23: 6 search calls ran inline on Opus to
research a plugin, spending Opus tokens on work `scout` handles fine.

## Decision

The main session (Opus) decides, writes specs, reviews results, and reports.

- Open lookups (paths not already known, sweeping directories or caches, web search, docs
  lookup) → `scout`, with one concrete question. Reading a known file to decide stays inline.
- Large changes (more than 3 files, or bulk/mechanical writing) → `worker`, with the decided
  spec, exact files, and an acceptance command. Small changes to ≤3 known files stay inline.
- Costly-to-get-wrong decisions → `reasoner` or the main session, never `worker`/`scout`.
- Independent subtasks are dispatched in parallel in one message.
- This is a standing user instruction and overrides the harness default.

A first version of this ADR (same day) delegated *every* edit; it was narrowed to the above
because a subagent's cold start costs more than a small known-file edit.

Keeps 0003's "≤3 known files inline" rule for writing, but limits it to known files: open
lookups always go to `scout`.

## Consequences

- Opus no longer spends tokens on open-ended searches or bulk writing.
- Small known-file edits stay fast, with no cold-start cost.
- The main session has to write clear specs for what it delegates.
