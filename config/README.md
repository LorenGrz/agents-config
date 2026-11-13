# config/ — portable Claude Code configuration

`install.sh` at the repo root generates/symlinks all of these into `~/.claude/` /
`~/.codex/` so each agent loads them, combined with your personal profile:

```
~/.claude/CLAUDE.md  -> generated: @<repo>/config/AGENTS.md, @<repo>/config/profiles/<name>.md, @<repo>/config/CLAUDE.md
~/.codex/AGENTS.md   -> generated: <repo>/config/AGENTS.md + <repo>/config/profiles/<name>.md, concatenated
~/.claude/rules/*.md -> per-file symlinks: only the GLOBAL rules of <repo>/config/rules (see scopes.json)
~/.claude/hooks      -> symlink: <repo>/config/hooks
~/.claude/agents     -> symlink: <repo>/config/agents
~/.claude/keybindings.json -> symlink: <repo>/config/keybindings.json (Alt+P plan, Alt+M model picker)
```

`AGENTS.md` and `CLAUDE.md` here are **generic** — shareable with anyone who clones this
repo, no names or personal paths. `AGENTS.md` holds the agent-agnostic instructions (read by
Codex and other agents, concatenated with your profile); `CLAUDE.md` holds Claude Code-only
sections (skills, agent routing) and is never imported by `AGENTS.md` itself — the generated
`~/.claude/CLAUDE.md` imports both plus your profile, in that order.

**`profiles/`** — personal content, one file per person. `_template.md` is the commented
template; copy it to `<name>.md` and fill it in (identity, preferred language, GitHub owner,
learning stage, your own project/tool paths, OS settings repo, ...). Never add personal
content to `AGENTS.md` or `CLAUDE.md` above — add it to your profile instead.

Edit here, commit, push; keep any personal mirror clone you maintain in sync yourself (not
tracked by this repo).

**Also tracked:**

- `hooks/statusline.sh` — status line (model, effort, session cost, context, 5h/7d usage with reset time; colored by threshold, ASCII only, responsive to terminal width; `NO_COLOR` disables color).
- `agents/` — `scout.md`, `worker.md`, `reasoner.md`, the three model-pinned subagents (see root README).
- `settings.base.json` — sanitized base merged into `~/.claude/settings.json` by `install.sh`
  (permissions, model, hooks, statusLine, enabledPlugins, extraKnownMarketplaces, theme). No secrets,
  no machine-specific `autoMode` block.
- `rulesync/` — multi-AI rule/skill generation for Codex CLI, Cursor, and Google Antigravity
  (Gemini). See the root README.

**Not tracked** (machine-local / secret): `~/.claude/settings.json` (the real, merged file),
`settings.local.json`, `.credentials.json`, `sessions/`, `projects/` (auto-memory + transcripts),
logs, caches.

> Cowork sessions on the desktop skip a symlinked `~/.claude/rules/` that points outside
> the working dir. This setup targets the Claude Code CLI, where symlinked rules load fine.

## rules/

Path-scoped — each loads only when Claude touches a matching file.

| File | Loads on | Purpose |
|------|----------|---------|
| `typescript.md` | `**/*.ts(x)` | strict typing, boundary validation |
| `react.md` | `**/*.tsx`, `**/*.jsx` | zero-`useEffect`-for-logic doctrine, hooks own data-loading, presentational/container split, Vitest+RTL |
| `next.md` | Next `app/` files, `next.config.*`, `middleware.ts`/`proxy.ts` | RSC-first data loading, Server Actions, client-boundary and secret rules |
| `nestjs.md` | Nest file suffixes | clean-architecture layering |
| `kotlin.md` | `**/*.kt(s)` | Spring Boot layered architecture (domain / service / controller / mapper), Kotest |
| `python.md` | `**/*.py` | uv/ruff/mypy, pydantic, agent-script reliability |
| `testing.md` | `*.test/spec.*` | behaviour over implementation |
| `security.md` | server + config files | authz binding, tokens, CSRF/CORS, input validation, secrets, error handling |

## hooks/ — wire into `~/.claude/settings.json`

```json
{
  "hooks": {
    "PreToolUse":  [
      { "matcher": "Edit|Write|MultiEdit", "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/guard-omarchy.sh" }] },
      { "matcher": "Bash", "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/scout-readonly.sh" }] },
      { "matcher": "Bash", "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/rtk.sh" }] },
      { "matcher": "Edit|Write|MultiEdit", "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/critical-reasoning.sh" }] }
    ],
    "PostToolUse": [{ "matcher": "Edit|Write|MultiEdit", "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/format-file.sh", "statusMessage": "formatting" }] }],
    "SessionStart": [{ "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/session-start.sh" }] }],
    "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/critical-reasoning.sh" }] }],
    "Stop":        [{ "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/stop-git-status.sh" }] }],
    "InstructionsLoaded": [{ "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/log-instructions.sh", "async": true }] }]
  }
}
```

| Script | Event | Does |
|--------|-------|------|
| `guard-omarchy.sh` | PreToolUse (Edit\|Write\|MultiEdit) | denies edits under `~/.local/share/omarchy/` |
| `scout-readonly.sh` | PreToolUse (Bash) | inside the `scout` subagent only: allowlists read-only commands, denies writes/mutating flags |
| `format-file.sh` | PostToolUse | project formatter on the edited file: prettier → eslint `--fix` (TS), `ktlint -F` (Kotlin), `ruff` (Python) |
| `session-start.sh` | SessionStart | re-injects the agent routing rule; in repos with ≥200 tracked files nudges to create/refresh `.agents/CONTEXT.md` when missing or ≥30 commits stale |
| `critical-reasoning.sh` | UserPromptSubmit, PreToolUse (Edit\|Write\|MultiEdit) | in the main session only: when the prompt or edited file looks costly to get wrong (architecture, security, migrations, prod, IAM, CI), injects a nudge to delegate to `reasoner` (Opus). Guidance only, never blocks |
| `stop-git-status.sh` | Stop | shows uncommitted changes when in a git repo |
| `log-instructions.sh` | InstructionsLoaded | logs session/cwd + `file_path`/`memory_type`/`load_reason`/`trigger_file_path` (or raw JSON if the payload has none of those) to `~/.claude/logs/instructions-loaded.log` |
| `rtk.sh` | PreToolUse (Bash) | hands read-only/verification commands (git status/diff/log, ls, find/grep, lint/test/tsc) to [rtk](https://github.com/rtk-ai/rtk) to compress their output; everything else passes through so the normal permission flow applies (rtk answers `allow`). No-op without rtk |

## Per-repo setup

This `config/` tree is global (machine-wide). Per-repo agent config — `AGENTS.md`,
`.claude/settings.json` with superpowers, branch/lint hooks, CI, GitHub Project —
comes from the `skills/devops/project-init` skill, run once per new repo.

**`scopes.json`** — which skills/rules/MCP belong to which stack. Unlisted = global. Per-project
install: `scripts/project-agents.sh --stack <a,b> --dir <repo>` (ADR 0011).
