# 0019 — AGENTS.md first: the single source for every agent, baseline for every CLI

Status: accepted (2026-11-09)

## Context

Every repo set up by `project-init` shipped both `AGENTS.md` (the content) and a `CLAUDE.md` that only said
`@AGENTS.md` plus `@.agents/CONTEXT.md`. The reason was that Claude Code did not read `AGENTS.md` by itself.

That is no longer true. Claude Code 2.1.277+ (the local install is 2.1.319) reads `AGENTS.md` as project
instructions when there is no `CLAUDE.md`, `.claude/CLAUDE.md` or `CLAUDE.local.md` in the working directory or
any directory above it (`~/.claude/CLAUDE.md` does not count). Checked live: in a folder with only an
`AGENTS.md` holding a codeword, both the main session and a `worker` subagent knew it. Subagents load the same
memory hierarchy as the main session, built-in Explore and Plan excepted.

The rules that matter most (the seven in `config/baseline.md`) only reached Claude Code, through
`~/.claude/CLAUDE.md`. agy, Copilot and OpenCode got nothing global and run with automatic permissions under
caolg; Codex got them only through the concatenated `~/.codex/AGENTS.md`.

## Decision

- **`AGENTS.md` is the source in every project.** `project-init` and `adopt.sh` no longer create `CLAUDE.md`
  (`--claude-shim` writes the one-line `@AGENTS.md` for older Claude Code versions). An existing `CLAUDE.md` is
  never touched or deleted: a thin `@AGENTS.md` pointer is harmless (Claude does not read the file twice) and
  covers sessions where the native read is unavailable (built-in plugin disabled; Bedrock or telemetry-off
  before 2.1.281).
- **The template `AGENTS.md` carries the critical rules**: the baseline between `<!-- baseline:start -->` and
  `<!-- baseline:end -->`, in English, plus "read `.agents/CONTEXT.md` before exploring". Every CLI that reads
  the repo's `AGENTS.md` (Claude main session and subagents, Codex, Copilot, OpenCode, agy) gets them. `adopt.sh`
  appends the block once to an existing `AGENTS.md` that lacks it.
- **Baseline for the CLIs without a global file**: `scripts/gen-cli-baselines.sh`, opt-in through
  `install.sh --with-cli-baselines`, writes `config/baseline.md` to `~/.gemini/GEMINI.md`,
  `~/.copilot/copilot-instructions.md` (verified with `copilot instruction list`),
  `~/.config/opencode/AGENTS.md` and, for OpenCode launched by CAO, `~/.aws/opencode/AGENTS.md`. Only for tools
  that are installed; same backup rules as `install.sh`.
- **`~/.claude/CLAUDE.md` stays** as the generated file with the `@imports`: it is the only global channel, and
  it also reaches subagents.
- **`scout` sets `omitClaudeMd: true`** (verified: it no longer receives the memory chain). Lookups need none of
  the rules and each invocation otherwise pays that chain.

## Consequences

- Duplication: the baseline now appears in the project `AGENTS.md` and in the global memory, ~0.2k tokens in
  Claude Code. Accepted: the project copy is what the other CLIs and a repo cloned elsewhere get.
- A `CLAUDE.md` in any parent directory (for example `~/CLAUDE.md` or a workspace folder's) silently disables the
  native `AGENTS.md` read for everything below it. `workspace.sh` still writes a `CLAUDE.md` with `@AGENTS.md`
  for that reason; revisit it separately.
- `InstructionsLoaded` does not fire for an `AGENTS.md` read this way, so `log-instructions.sh` no longer sees it.
- The superpowers phase table that lived in the template `CLAUDE.md` is gone; "Workflow lanes" in
  `config/CLAUDE.md` replaces it (ADR 0020).
- Not verified: that agy reads `~/.gemini/GEMINI.md` when launched by CAO (its binary names the path; it was not
  run). The personal Copilot file and the project `AGENTS.md` read by Copilot were verified.
- Left alone: `~/.agents/skills` is a symlink to the whole hub and the profile calls a script through it, so
  curating what Codex sees there needs its own change.
