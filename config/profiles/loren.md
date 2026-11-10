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
- Roadmap progress is auto-tracked: when Loren says he understood/finished a roadmap topic, or finished work shows it (e.g. a completed project in that tech), update the stage line above yourself — run `~/.agents/skills/meta/roadmap-coach/scripts/update-stage.sh "<new stage text>"` without asking, then tell him in one line. Don't edit copies elsewhere; this line is the only source.
- Keep roadmap tasks small and aligned to the current stage; do not introduce later frameworks just to make a project look advanced.
- Current roadmap repo: `~/projects/roadmap`. Repository context file: `~/projects/roadmap/.agents/CONTEXT.md`.
- Long-term product track: Study Tracker / Developer Progress Tracker (StudyQuest).
- Portfolio work should explain problem solved, stack, architecture decisions, lessons learned, repository link, and live demo when available.

## Model routing

- Main session: Opus at high effort (ADR 0024); planning/decisions via `reasoner` (Opus, effort high), ADR 0018 (supersedes the `opusplan` choice of ADR 0009).
- `worker` = Sonnet: implements common writing tasks (code, docs, tests) from an approved plan. `reasoner` = Opus: decisions only. `scout` = Haiku: light read-only lookups.
- Gemini (`agy`) for bulk mechanical writing or wide reading when its quota is the better spend.

## Local tool paths

- MarkItDown (PDF conversion, use first for PDF work): `~/projects/markitdown/.venv/bin/markitdown`.
- Oracle APEX (`apexlang`) skill source: `~/projects/oracle-skills/apex/apexlang`.
- AWS skills history: `aws/` in this hub (folded in via `git subtree`, no longer a separate `~/projects/aws-skills` clone — see ADR 0001).

## Skill routing (personal)

- Omarchy/Linux desktop: `omarchy` before editing terminal, Hyprland, Waybar, Mako, Walker, theme, or desktop config.
- Oracle APEX: `apexlang` for `.apx` apps and APEXlang workflows.

## OS / desktop config

- Desktop: Omarchy (Arch-based Linux). Settings repo: `~/projects/omarchy-settings`. Never edit Omarchy source under `~/.local/share/omarchy/` (the generic rules are in `AGENTS.md` "OS and desktop config").

## Codex workflow adapter

`meta/codex-workflows` adapts Claude Code to this existing personal setup. Its extra skill roots, beyond this hub, are:

- `~/.codex/skills`
- `~/.local/share/omarchy/default/omarchy-skill/SKILL.md`

## Notes

- All of Loren's repos are public except `omarchy-loren` (private: per-machine config and the new-PC setup). Baseline rule 1 (no secrets) applies to all of them, private included.
