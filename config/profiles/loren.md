# Profile: Lorenzo Graizzaro

Full-stack developer, UNSAM tutor, Buenos Aires, Argentina.

## Identity

- Name: Lorenzo Graizzaro (Loren).
- Preferred language for replies: Spanish by default; switch to English when the user writes in English.
- English coaching: yes — for every message written partly or fully in English, add a 2-line-maximum `English note` (one main issue) plus a `Better` line with the prompt phrased correctly, in English only (the `english-prompt-coach` skill, when available).

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

- Main session: Sonnet via `opusplan` (Opus in plan mode), ADR 0009.
- `worker` = Sonnet: implements common writing tasks (code, docs, tests) from an approved plan. `reasoner` = Opus: decisions only. `scout` = Haiku: light read-only lookups.
- Gemini (`agy`) for bulk mechanical writing or wide reading when its quota is the better spend.
- Planning: recommend subagents and ask. Default recommendation: `scout` for open lookups, `reasoner` for critical decisions, `worker` for changes over 3 files.

## Local tool paths

- MarkItDown (PDF conversion, use first for PDF work): `~/projects/markitdown/.venv/bin/markitdown`.
- Oracle APEX (`apexlang`) skill source: `~/projects/oracle-skills/apex/apexlang`.
- AWS skills history: `aws/` in this hub (folded in via `git subtree`, no longer a separate `~/projects/aws-skills` clone — see ADR 0001).

## Skill routing (personal)

- Omarchy/Linux desktop: `omarchy` before editing terminal, Hyprland, Waybar, Mako, Walker, theme, or desktop config.
- Oracle APEX: `apexlang` for `.apx` apps and APEXlang workflows.

## OS / desktop config

- Desktop: Omarchy (Arch-based Linux). Settings repo: `~/projects/omarchy-settings`.
- For end-user Omarchy customization, edit safe user config locations such as `~/.config/`, never Omarchy source under `~/.local/share/omarchy/`.
- If changing OS or desktop config, test locally first; confirm the change works before pushing to the settings repo above; do not push unrelated or pre-existing changes.

## Codex workflow adapter

`meta/codex-workflows` adapts Claude Code to this existing personal setup. Its extra skill roots, beyond this hub, are:

- `~/.codex/skills`
- `~/.local/share/omarchy/default/omarchy-skill/SKILL.md`

## Notes

- All of Loren's repos are public except `omarchy-loren` (private: per-machine config and the new-PC setup). Never commit secrets, API keys, or credentials to any of them, private included.
