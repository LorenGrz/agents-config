<!--
  Profile template for agents-config.

  Copy this file to config/profiles/<your-name>.md and fill in the sections
  below. install.sh imports this file (alongside config/AGENTS.md and
  config/CLAUDE.md) into ~/.claude/CLAUDE.md and ~/.codex/AGENTS.md, so
  everything you write here becomes part of every agent session on this
  machine.

  Keep this file personal: names, preferred language, your own project
  paths, stack/learning stage, and anything else config/AGENTS.md should
  stay generic about. Do not edit config/AGENTS.md or config/CLAUDE.md to
  add personal content — add it here instead.
-->

# Profile: <your name>

<!-- One line: who you are, and anything an agent should know about you
     up front (role, timezone, primary language). -->

## Identity

- Name: <your name>
- Preferred language for replies: <e.g. English, Spanish>
- English coaching notes (add a short "English note" + "Better" line when a
  message is written partly/fully in English): <yes | no>

## GitHub

- Default owner/org for new repos: <your-github-username>
- Showcase/mirror clones to keep in sync (if any): <none, or repo paths>

## Stack and learning stage

<!-- Delete this section if not relevant. Keep it short — detail that's
     rarely needed belongs in a skill's references/, not here. -->

- Current stack: <e.g. TypeScript, React, NestJS>
- Current learning stage / roadmap pointer: <stage, or link to your own roadmap repo>
- Long-term project(s) in progress: <name + one line>

## Model routing

<!-- Which model backs each role in config/CLAUDE.md "Agent Routing". -->

- Main session: <model / mode>
- `worker` (implementation): <model>. `reasoner` (decisions): <model>. `scout` (lookups): <model>.

## Local tool paths

<!-- Paths to tools you've installed locally that skills should reference,
     e.g. MarkItDown for PDF conversion, a personal skills root, etc. -->

- <tool name>: `<absolute or ~-relative path>`

## OS / desktop config

<!-- Only if you use a specific desktop environment (e.g. Omarchy) with its
     own settings repo. Delete this section otherwise. -->

- Settings repo: `<path>`

## Notes

<!-- Anything else persistent that every agent session on this machine
     should know about your working style or preferences. -->
