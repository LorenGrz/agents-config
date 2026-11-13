# 0001. Record architecture decisions

## Status

Accepted

## Date

{{DATE}}

## Context

A new agent session (Claude, Codex, or any other AI) or a human picking this project back up needs to know *why* the codebase is shaped the way it is, not just what it currently does. Code and `AGENTS.md`/`docs/architecture.md` describe the current state, but trade-offs that were considered and rejected disappear from history unless something records them. Without a record, every session re-derives intent from diffs and commit messages, or worse, silently reverses a settled decision.

## Decision

Record every decision with a real trade-off as a lightweight Architecture Decision Record (ADR) under `docs/decisions/`, one file per decision, numbered sequentially starting at `0001` (this file). Use `docs/decisions/0000-template.md` as the starting point for a new ADR.

This is separate from the spec-driven workflow in `docs/superpowers/`: a spec (`docs/superpowers/specs/`) and a plan (`docs/superpowers/plans/`) describe *what* to build and *how*, for one unit of work. An ADR records *why* one approach was chosen over its alternatives, and stays relevant after the plan that produced it is done.

Not every change needs an ADR — routine implementation choices don't. Write one when a decision has a real trade-off: architecture, a library or service choice that's expensive to reverse, a data model shape, a security trade-off, or anything a future session might otherwise second-guess or redo.

## Alternatives considered

- **No decision log, rely on git history** — rejected: reconstructing intent from diffs and commit messages is slow and lossy, and an agent reading the repo fresh has no reason to go looking for it.
- **A wiki or doc outside the repo** — rejected: drifts from the code it describes and isn't visible to an agent that only reads the repo it's working in.

## Consequences

One more small file per non-trivial decision, which is cheap compared to re-litigating it later. Anyone or anything reading `docs/decisions/` gets the reasoning without archaeology. Revisit this if the project grows a dedicated decision-tracking tool and ADRs become redundant with it.
