# 0001. Record architecture decisions

## Status

Accepted

## Date

{{DATE}}

## Context

A new agent session or a human picking this project back up needs to know *why* the codebase is shaped the way it is. Code, `AGENTS.md` and `docs/architecture.md` describe the current state; rejected trade-offs disappear unless something records them, and a later session may silently reverse a settled decision.

## Decision

Record every decision with a real trade-off as an Architecture Decision Record (ADR) under `docs/decisions/`, one file per decision, numbered sequentially starting at `0001` (this file). Start a new ADR from `docs/decisions/0000-template.md`.

A spec (`docs/superpowers/specs/`) and a plan (`docs/superpowers/plans/`) describe *what* to build and *how*, and exist only while that work runs: both are deleted in the merge that finishes it. An ADR records *why* one approach was chosen over its alternatives and outlives the plan; whatever a plan decided that must last goes into an ADR before that merge.

Routine implementation choices need no ADR. Write one for architecture, a library or service choice that's expensive to reverse, a data model shape, a security trade-off, or anything a future session might second-guess or redo.

## Alternatives considered

- **No decision log, rely on git history** — rejected: reconstructing intent from diffs is slow and lossy, and an agent reading the repo has no reason to look there.
- **A wiki or doc outside the repo** — rejected: drifts from the code and isn't visible to an agent that only reads the repo.

## Consequences

One small file per non-trivial decision, cheaper than re-litigating it. Revisit if the project adopts a dedicated decision-tracking tool.
