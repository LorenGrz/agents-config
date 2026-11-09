# 0004 — Token budget for always-loaded files

## Context

`config/CLAUDE.md` loads at the start of every Claude Code session, in every project, no
matter how small. Before this change it was 63 lines / 5879 bytes and duplicated content
that already lived in `config/AGENTS.md` (which it `@`-imports) — a full "Roadmap" section,
a long Orchestrator-mode writeup, and a stale Agent Routing table that didn't yet reflect
the complexity-first routing rule (ADR 0003). Every one of those bytes is paid on every
session, in every repo, whether or not the session needs it.

## Decision

Treat `config/CLAUDE.md` as a token budget, not just a config file: target ≤60 lines.

- Keep only what's Claude Code-specific and actually used every session: the `@AGENTS.md`
  import, a short skills-location/workflow paragraph, the skill routing list, and the
  rewritten Agent Routing section.
- Move content that is detailed but rarely needed into the thing it's about, loaded on
  demand instead of always: the full learning-roadmap detail moved from `AGENTS.md`'s
  "Roadmap" section into `meta/roadmap-coach/references/roadmap-detail.md` (the
  `roadmap-coach` skill's own reference file, loaded only when that skill activates).
  `AGENTS.md` keeps a 2-line pointer.
- Remove anything from `CLAUDE.md` that `AGENTS.md` already says; `CLAUDE.md` is additive,
  never a second copy.

Result: `config/CLAUDE.md` went from 63 lines / 5879 bytes to 48 lines / 3124 bytes.
`config/AGENTS.md` went from 107 lines / 6986 bytes to 93 lines / 6741 bytes (it gained a
short docs-layer rule, see below, and lost the roadmap detail).

## Consequences

- Every session pays less for a file it didn't ask to read in full.
- The roadmap-coach skill is now the single source of truth for roadmap detail instead of
  a second copy in `AGENTS.md` — update it there when the stage changes.
- Future additions to `CLAUDE.md` should ask "does this apply to every session?" before
  growing the file; if not, it belongs in a skill, rule, or reference file loaded on demand.

## Update (2026-11-09)

The budget is revised to ≤60 lines and ≤4.2 KB in ADR 0020: the 3.1 KB target no longer fits the rules the file has to carry.
