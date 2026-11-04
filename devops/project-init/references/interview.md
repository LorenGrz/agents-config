# Project interview

Run before generating anything. Output: a manifest (`.agents/project.json`, schema below) that `init.sh --manifest` consumes.

## Rules

- One block at a time, with `AskUserQuestion`. Put the recommended option first and state the trade-off in each description.
- Every critical block (3-6) always offers **"No sé todavía"** → the decision goes to `pending`. Never fill in a default for it.
- Non-trivial project: before blocks 3-6, recommend a `reasoner` pass over the trade-offs and ask whether to run it.
- A policy of the chosen org is shown as a *proposal* ("política de <org>"), the user confirms it. If it replaces a base practice, record it with `"source": "org-policy"`.
- Ask in the user's language; keys and values in the manifest stay in English.

## Blocks

| # | Key | Ask | Typical options |
|---|---|---|---|
| 1 | `org` | Which organization owns this project? | Detected one (see below) / another registered / personal (`null`) |
| 2 | `stacks` | Stack and build tool | `react-vite`, `next`, `nestjs`, `node-ts`, `python`, `java-spring` (Maven or Gradle), `kotlin-spring` (Gradle). `rn` and others have no template: record the choice, scaffold by hand |
| 3 | `backend-style` | Backend architecture (only if a backend stack) | `hexagonal` (hexagonal + DDD per bounded context) / `modular` (modular monolith per feature) / `layered`; the manifest value must be exactly one of these tokens |
| 4 | `frontend-style` | Frontend architecture (only if a frontend stack) | `feature-sliced` (barrels + lint boundaries) / `hexagonal` (ports for API) / `simple`; exactly one of these tokens |
| 5 | `data`, `auth` | Database, persistence and migrations; auth strategy | Ask each separately. Never assume |
| 6 | `testing`, `deploy` | Test pyramid and e2e; deploy target | Deploy: none / Docker / AWS / Vercel. Respect `feedback-frugal-personal-projects`: nothing that costs money without asking |
| 7 | `sdd` | Specs before features? | exactly one of `required` (spec + plan for every non-trivial feat/refactor, the template default) / `light` (only big features; small changes go straight to implementation) / `off` (no spec requirement). `init.sh` rewrites step 2 of the generated `AGENTS.md` accordingly |

Optional, only when it applies: a component/UI library project gets the decision `project-kind: ui-library` (installs the `ui-library` pack).

Org detection: if `~/.config/agents-config/organizations.json` exists, match the repo owner or remote against each entry's `match`; propose the hit and always confirm. No registry → skip block 1 (`org: null`).

## Manifest (v1)

```json
{
  "version": 1,
  "name": "shop-api",
  "org": null,
  "stacks": ["nestjs"],
  "extras": ["aws"],
  "decisions": [
    {
      "key": "backend-style",
      "title": "Backend architecture",
      "value": "hexagonal",
      "why": "Domain logic must not depend on the framework.",
      "alternatives": ["modular monolith: simpler, weaker boundaries"],
      "source": "user"
    }
  ],
  "pending": [{ "key": "auth", "title": "Auth strategy", "note": "Waiting on the client" }]
}
```

- `stacks[0]` is the scaffold stack; other entries are passed to `project-agents.sh` only if `config/scopes.json` knows them. `extras` are extra skill stacks (`aws`, `llm`, `supabase`...).
- `source` is `user` (default) or `org-policy`.
- Required keys, each in `decisions` or `pending`: `data`, `auth`, `testing`, `deploy`, `sdd`, plus `backend-style` / `frontend-style` when the stacks include a backend / frontend. `scripts/manifest.sh validate` enforces it.

## What init does with it

`init.sh --manifest <file>` fills `--name`, `--stack` and `--with` (flags still win), then `manifest.sh apply` writes `.agents/project.json`, one ADR per decision in `docs/decisions/`, and a "Pending decisions" section in `.agents/CONTEXT.md`. Pending items must be asked before implementing anything that depends on them.
