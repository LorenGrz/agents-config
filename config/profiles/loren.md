# Profile: Lorenzo Graizzaro

Full-stack developer, UNSAM tutor, Buenos Aires, Argentina.

## Identity

- Name: Lorenzo Graizzaro (Loren).
- Preferred language for replies: Spanish by default; switch to English when the user writes in English.
- English coaching: yes (format in `AGENTS.md` "Communication"; the `english-prompt-coach` skill, when available).
- **No assumptions** unless Loren says so ("asumí" / "assume"). When scope, a requirement or a choice is unclear, ask instead of picking a default, even on trivial tasks; when something must be assumed to continue, say it explicitly first. Stricter version of `karpathy-guidelines` §1.

## GitHub

- Default owner/org for new repos: `LorenGrz`.

## Stack and learning stage

Full-stack TypeScript learning order:

```text
JavaScript -> Node.js -> TypeScript -> React -> NestJS -> Supabase + WebSockets -> Next.js -> React Native
```

- Current stage (as of 2026-10-23): NestJS and Next.js pending — the active focus. Supabase and WebSockets understood. React in-depth study completed. JavaScript, Node.js, and TypeScript foundations done. Next stage after that: React Native. Also now learning Python.
- When Loren says a roadmap topic is understood or finished, or finished work shows it, update the stage line above: run `~/.agents/skills/meta/roadmap-coach/scripts/update-stage.sh "<new stage text>"` without asking, then say so in one line. This line is the only source; don't edit copies elsewhere.
- Keep roadmap tasks small and aligned to the current stage; do not introduce later frameworks just to make a project look advanced.
- Current roadmap repo: `~/projects/roadmap`. Repository context file: `~/projects/roadmap/.agents/CONTEXT.md`.
- Long-term product track: Study Tracker / Developer Progress Tracker (StudyQuest).
- Portfolio work should explain problem solved, stack, architecture decisions, lessons learned, repository link, and live demo when available.

## Model routing

- Main session: Opus at high effort (ADR 0024). Opus designs plans (Plan S/L, plan mode), executes Plan S itself (subagents only when the work needs them) and delegates Plan L to leads or workers; never pass `model: fable` to a subagent. Fable is only the advisor (`advisorModel: "fable"` in `~/.claude/settings.json`). A reasoner is Opus at high effort consulting that advisor: the main session is one, and so is every lead.
- `worker` = Sonnet: code, docs, tests; every non-trivial repo change, in the background (ADR 0029); in Plan S, only when the work needs it. The `reasoner` subagent = Opus: decisions only. `scout` = Haiku: light read-only lookups.
- Lead (Plan L across repos) = a reasoner session, not the `reasoner` subagent: one per repo, in that repo's own session and with that repo's skills, or in the workspace folder when the skills live there; a workspace lead may send a lead to each child repo. Leads start `worker` (Sonnet), `scout` (Haiku) and their `reviewer`.
- Gemini (`agy`): manual and optional, only when Loren asks for it, for bulk writing, wide reading or a review.
- `reviewer` = the `reviewer` subagent (Opus at high effort, no edit tools), never the session that wrote the code:
  reviews the diff before every PR and before a Plan L merge. Optional, only when Loren asks: Gemini 4 Argon
  (`gemini-4-argon`, thought level high; `gemini-4-argon-high` in `agy`) through Antigravity, or Codex
  (`codex-review`). A day of Argon reviews used almost the whole weekly Gemini quota.

## Local tool paths

- MarkItDown (PDF conversion, use first for PDF work): `~/projects/markitdown/.venv/bin/markitdown`.
- AWS skills: `skills/aws/` in this hub, not a separate `~/projects/aws-skills` clone (ADR 0001).

## Skill routing (personal)

- Omarchy/Linux desktop: `omarchy` before editing terminal, Hyprland, Waybar, Mako, Walker, theme, or desktop config.

## OS / desktop config

- Desktop: Omarchy (Arch-based Linux). Settings repo: `~/projects/omarchy/settings`. Never edit Omarchy source under `~/.local/share/omarchy/` (the generic rules are in `AGENTS.md` "OS and desktop config").
- "Suspendé la PC" / "suspend the PC" (usually remote, through T3 Code): finish the reply's work first, then run `suspend-later` (30 s delay so the reply arrives). If it aborts listing active work, show the list and ask before `suspend-later --force`. `suspend-later --cancel` stops it.

## Codex workflow adapter

`skills/meta/codex-workflows` adapts Claude Code to this setup. Extra skill roots beyond this hub:

- `~/.codex/skills`
- `~/.local/share/omarchy/default/omarchy-skill/SKILL.md`

## Notes

- All of Loren's repos are public except `omarchy-loren` (per-machine config and the new-PC setup). Baseline rule 1 (no secrets) applies to all of them, private included.
