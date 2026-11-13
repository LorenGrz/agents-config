---
name: roadmap-coach
description: Keep Loren's learning and project work aligned to the full-stack TypeScript roadmap. Use when a request involves planning, choosing the next task, creating or changing learning projects, deciding whether to use JavaScript, Node.js, TypeScript, React, NestJS, Supabase/WebSockets, Next.js, or React Native, or preventing premature framework jumps.
---

# Roadmap Coach

Keep work scoped to the current learning stage and convert broad ideas into small, verifiable steps.

The current stage lives only in the active profile (`config/profiles/<name>.md`, line `- Current stage (as of ...)`), which is already loaded in every session. For roadmap repo paths and the long-term product track, load `references/roadmap-detail.md`.

## Roadmap Order

1. JavaScript fundamentals
2. Node.js
3. TypeScript
4. React
5. NestJS
6. Supabase and WebSockets
7. Next.js
8. React Native

## Workflow

1. Identify the user's current stage from the repo, request, and `~/projects/roadmap/README.md` when relevant.
2. State whether the requested work fits the current stage or is a deliberate preview of a later stage.
3. Prefer the smallest useful project or exercise that teaches the intended concept.
4. Define a concrete deliverable and verification command before implementing larger work.
5. Keep explanations short and practical; include English practice only when it naturally supports README, commit, or project documentation.

## Guardrails

- Do not introduce a framework earlier than needed just to make the project look advanced.
- Prefer official docs and project-local scripts over global assumptions.
- Favor portfolio-ready habits from the beginning: README, clear commands, small commits, tests when behavior matters.
- When the user asks for a full app, propose an incremental slice that can be finished and verified.

## Updating The Stage

Do this proactively, without asking, whenever there is clear evidence of progress:

- The user says a topic is understood, done, finished, or no longer pending ("ya entendí Supabase", "terminé NestJS").
- Finished, verified work shows it: a project in that tech reaches a working, tested state, or a stage's exercises are completed in the roadmap repo.
- The user says a topic is pending again or they moved back — update that too.

Don't update on intent alone ("quiero empezar Next.js") or on a single exercise.

Run, from any directory:

```bash
~/.agents/skills/meta/roadmap-coach/scripts/update-stage.sh "<full new stage text>"
```

Write the full sentence in the existing style (what's active/pending, what's understood, what's next), without the date — the script adds today's date, regenerates `~/.codex/AGENTS.md`, commits, merges, pushes, and pulls the profile's mirror clones. Use `--dry-run` first if unsure. Then tell the user in one line what changed. Never copy the stage text into other files.
