# 0020 — CAO-aware hooks, context budget and workflow lanes

Status: accepted (2026-11-09)

## Context

The hooks run in every Claude Code session, including the Claude agents that caolg launches through CAO: they
are ordinary top-level sessions, so they load `~/.claude` in full. Three of them contradicted the caolg
profiles: `session-start.sh` told workers to use `scout`/`worker`/`reasoner` (profiles say "do not open
agents") and, in repos without an `AGENTS.md`, to run `project-init` before working; `critical-reasoning.sh`
fired on almost every assignment (role files contain "architecture", "migrations", "security") and pushed Opus
spend outside CAO's quota rotation; `intent-router.sh` told a worker running `git commit` to load
`git-workflow`, which includes push and merge.

The same hooks also fired on background-task notifications (they reach `UserPromptSubmit` as prompts) and had no
cap: `critical-reasoning.sh` repeated on every matching prompt and every sensitive edit.

Measured fixed cost of a clean Claude Code session: ~15–18k tokens, of which `config/CLAUDE.md` had grown back
to 5.9 KB / 73 lines against ADR 0004's budget.

## Decision

- **CAO mode.** When `CAO_TERMINAL_ID` is set (CAO sets it in every pane; nothing in the environment tells leader
  from worker): `session-start.sh` and `critical-reasoning.sh` stay silent; `intent-router.sh` routes only
  integration MCP tools (`mcp__*`), not prompt phrases (a worker's prompt is the assignment text) and not `Bash`.
- **`critical-reasoning.sh`**: the reasoner reminder goes once per session when a `session_id` exists (same
  marker directory as the intent router); silent in plan mode (`permission_mode == "plan"`, which already
  decides); silent on prompts that look like task notifications; the text now names the high-effort `reasoner`
  (ADR 0018) instead of "Sonnet". The skill hint from `.agents/critical.json` is unchanged and uncapped.
- **Task notifications** are recognised by a heuristic (`<task-notification>` or a leading
  `[system notification`) because Claude Code documents no field that tells them from a user prompt. If one is
  added, replace the heuristic.
- **`config/CLAUDE.md` budget: ≤60 lines, ≤4.2 KB** (was 73 / 5.9 KB; ADR 0004's 3.1 KB no longer fits the
  rules it has to carry). The skill list that repeated the skill descriptions and named skills that are not
  global was dropped; routing is stated once; `session-start.sh` points to it in one short line.
- **Workflow lanes** live in `config/CLAUDE.md`. Lane S (cause known, ≤3 files, no contract, schema, migration,
  auth or architecture decision): inline, focused test, smallest check, no brainstorming, no plan in docs, no
  subagents. Lane L (everything else): brainstorming, writing-plans, `worker`/`reasoner`, or caolg across repos.
  Unknown cause: `systematic-debugging` first. Plan mode ends with "Lane S/L because …". The user's
  instructions override a skill's own process, so lane S skips brainstorming.
- **PonyTail** (`DietrichGebert/ponytail`, a plugin that biases the agent toward reusing code) is named as an
  optional helper for lane S. It is **not installed or enabled** by this repo: it injects text on every turn
  through Node hooks and its published savings are self-reported. Try it in one project first and measure what
  it adds per turn before deciding between global and per-stack scope.
- No plugin is disabled by this change.

## Consequences

- Inside CAO the leader loses the phrase shortcuts of the intent router; integration tool calls are still routed.
- Roles and profiles stay the only guidance a CAO worker gets from agents-config besides the global memory.
- Tests for each rule are in `scripts/test-intents.sh` and `scripts/test-packs.sh`; both unset
  `CAO_TERMINAL_ID` so they do not depend on where they run.
- `install.sh` only adds to `enabledPlugins`: if plugins are later removed from the base file they stay enabled
  in `~/.claude/settings.json` unless the base sets them to `false` (as it does for vercel and playwright).
- Not verified: whether `SessionStart` and `UserPromptSubmit` output reaches subagents (undocumented); whether the
  leader's `--dangerously-skip-permissions` also skips the `permissions.ask` rules of `settings.base.json`.
