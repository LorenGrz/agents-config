<!--
  Profile template. Copy to config/profiles/<your-name>.md and fill it in.
  install.sh imports it into ~/.claude/CLAUDE.md and ~/.codex/AGENTS.md, so it
  reaches every agent session on this machine. Personal content goes here, never
  in config/AGENTS.md or config/CLAUDE.md.
-->

# Profile: <your name>

<!-- One line: role, timezone, primary language. -->

## Identity

- Name: <your name>
- Preferred language for replies: <e.g. English, Spanish>
- English coaching notes ("English note" + "Better" line for messages written partly/fully in
  English): <yes | no>

## GitHub

- Default owner/org for new repos: <your-github-username>
- Showcase/mirror clones to keep in sync (if any): <none, or repo paths>

## Stack and learning stage

<!-- Optional. Keep it short; rarely needed detail goes in a skill's references/. -->

- Current stack: <e.g. TypeScript, React, NestJS>
- Current learning stage / roadmap pointer: <stage, or link to your own roadmap repo>
- Long-term project(s) in progress: <name + one line>

## Model routing

<!-- Which model backs each role in config/CLAUDE.md "Agent Routing". -->

- Main session: <model / mode>
- `worker` (implementation): <model>. `reasoner` (decisions): <model>. `scout` (lookups): <model>.
- Repo lead (one per repo when a Plan L spans repos): <model>.
- `reviewer` (reviews the diff before every PR and before a Plan L merge): <a model from another
  provider, and how it is reached>. Fallback when it is unavailable: <model or role>.

## Local tool paths

<!-- Locally installed tools that skills should reference (e.g. MarkItDown for PDFs). -->

- <tool name>: `<absolute or ~-relative path>`

## Skill routing

<!-- Optional. Which skill to load for which of your tools or workflows. -->

- <area>: `<skill>` before <doing what>.

## OS / desktop config

<!-- Optional: a desktop environment (e.g. Omarchy) with its own settings repo. -->

- Settings repo: `<path>`

## Notes

<!-- Anything else every agent session on this machine should know about your preferences. -->
