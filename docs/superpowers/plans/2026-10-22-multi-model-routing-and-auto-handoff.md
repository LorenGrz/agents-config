# Plan — Neutral `~/.agents` layer, OpenCode-first routing, automatic handoff

Date: 2026-10-22
Status: approved decisions applied (v2, KISS pass)
ADRs to write: 0006 (neutral layer + routing), 0007 (automatic handoff)

## Goal

1. Everything (instructions, skills, rules, hooks) lives in one tool-neutral place,
   `~/.agents/`. Each tool only gets symlinks into it. If a tool breaks or a new one appears,
   nothing else changes.
2. Spend Claude usage only where it matters: cheap/mechanical work goes to OpenCode first
   (DeepSeek & co.), Claude is the fallback and the decision-maker.
3. When Claude's quota runs out, OpenCode or Codex continue from an up-to-date
   `docs/plans/HANDOFF.md` without anyone asking for it.

Rule for every step: if it isn't needed now, it's out. Cut items are listed at the end.

## Decisions (Loren, 2026-10-22)

| # | Decision |
|---|---|
| 1 | Cheap **scout** tier is read-only. |
| 2 | Handoff nudge: kept, simplified (see Phase 3). |
| 3 | Codex runs with approval `never`, sandboxed to a dedicated worktree. |
| 4 | OpenCode first for **worker** tasks too (not just lookups); Claude Sonnet is the fallback. Model choice is situational — one line to change, no code. Ollama optional, off by default. |
| 5 | Push from this session: yes. Hub clone moves to `~/projects/agent-config`. |

## Phase 0 — Verify on Loren's machine (one sitting, ~15 min)

Run these, note results in ADR 0006; any surprise changes the phase that depends on it.

- `claude --version` and the hooks doc: `Stop` input has `stop_hook_active`; JSON
  `{"decision":"block","reason":…}` continues the turn.
- `opencode models | grep -iE 'deepseek|glm|kimi'` → pick the default cheap model.
- OpenCode global instructions path (does it read `~/.config/opencode/AGENTS.md`?).
- `codex --version`; `codex login status`; whether `notify` runs after each turn.

## Phase 1 — Repo cleanup + neutral layer (`refactor/neutral-agents-layer`)

**Repo layout, after:**

```
agent-config/
├── skills/<category>/<skill>/SKILL.md   (all category dirs moved here with git mv)
├── config/  AGENTS.md  CLAUDE.md  profiles/  rules/  hooks/  agents/  settings.base.json  models.env
├── bin/     oc-ask
├── docs/    decisions/  superpowers/plans/
├── install.sh   (absorbs sync.sh)
└── README.md
```

**`~/.agents/` after `install.sh` (all symlinks into the repo, plus one generated file):**

```
~/.agents/AGENTS.md     generated: config/AGENTS.md + your profile
~/.agents/skills/<n>    flat links to skills/<category>/<n>   ← Codex + OpenCode read this natively
~/.agents/rules         → config/rules
~/.agents/hooks         → config/hooks
~/.agents/models.env    → config/models.env  (CHEAP_MODEL=..., one line per tier)
```

**Per-tool adapters (symlinks only, except Claude's generated CLAUDE.md as today):**

- Claude: `~/.claude/skills → ~/.agents/skills`, `rules → ~/.agents/rules`,
  `hooks → ~/.agents/hooks`, `agents → config/agents`, generated `CLAUDE.md` imports
  `~/.agents/AGENTS.md` + `config/CLAUDE.md`.
- Codex: `~/.codex/AGENTS.md → ~/.agents/AGENTS.md`. Skills: native.
- OpenCode: global AGENTS path → `~/.agents/AGENTS.md`. Skills: native.
- Removing a tool = deleting its symlinks. No flag, no generator.

**Cleanup (less to maintain, fewer always-loaded tokens):**

- Delete `.claude-plugin/` and `hooks/hooks.json`: a second, Claude-only install method
  that duplicates `install.sh` and contradicts the neutral layer.
- Delete `meta/codex-workflows`: its job (making Claude see Codex skills) is done by the
  shared `~/.agents/skills`.
- Delete `meta/team-architect-agent`, `team-implementer-agent`, `team-reviewer-agent`:
  duplicate the `reasoner` / `worker` agents, superpowers and `code-review-safety`.
- `config/CLAUDE.md`: drop the skill-routing list (skills already trigger by their
  `description`; the list costs tokens every session and drifts).
- `settings.base.json`: drop the `statusLine` pointing at an untracked script.
- Merge `sync.sh` into `install.sh` (one entry point).
- `install.sh`: if the hub is still cloned at `~/.agents/skills`, stop and print the
  `mv` command to `~/projects/agent-config` (never moves it itself).
- README: update the install path, layout and tables; remove the plugin method.

Verification: temp `HOME` → `install.sh --dry-run`, then `install.sh` → `ls -l` shows every
adapter resolves; Claude Code lists skills; `codex` and `opencode` list the same skills;
`rm ~/.claude/skills` leaves Codex/OpenCode unaffected.

## Phase 2 — OpenCode-first routing (`feat/opencode-first`)

One script, one rule, one config line.

- `config/models.env`: `CHEAP_MODEL=<from Phase 0>`. Change it whenever you want to
  vary (DeepSeek, GLM, an Ollama model...).
- `bin/oc-ask` (linked to `~/.local/bin/oc-ask`), ~20 lines:
  - `oc-ask scout "question"` → `opencode run -m $CHEAP_MODEL --agent plan` (read-only).
  - `oc-ask work "task + acceptance command"` → `opencode run -m $CHEAP_MODEL --agent build`.
  - Any failure (not installed, quota, timeout) → exit 3.
- `config/CLAUDE.md` Agent Routing (replaces current table, stays short):
  1. Lookups → `oc-ask scout`; on exit 3 → `scout` (Haiku).
  2. Implementing a decided plan → `oc-ask work`, then run the acceptance command yourself;
     if it fails twice or exit 3 → `worker` (Sonnet).
  3. Decisions, unknown-cause bugs, plan review → main session (Opus). Unchanged.
- `settings.base.json`: allow `Bash(oc-ask *)`.

Verification: `oc-ask scout "where are hooks wired?"` answers; with OpenCode uninstalled it
exits 3 and Claude falls back to `scout`; `ccusage` shows fewer Sonnet/Haiku tokens over a
week.

## Phase 3 — Automatic handoff (`feat/auto-handoff`)

One script, `config/hooks/handoff.sh`, two modes:

- **`snapshot`** — no model, no tokens, works with zero quota. If the repo has
  `docs/plans/HANDOFF.md`, rewrite only the block between `<!-- handoff:auto -->` markers:
  date, which agent, branch, last 5 commits, `git status --short`, newest plan file.
  Called by: Claude `Stop`; Codex `notify` (if installed); OpenCode — only if Phase 0 shows a
  one-line way to run a command after each turn, otherwise skipped (snapshot from Claude/Codex
  is enough).
- **`nudge`** (Claude `Stop` only) — the "nudge" is the hook asking Claude, right before
  it stops, to rewrite the human part (*Current state / Pending work*, ≤15 lines). It fires
  only if files changed since the last nudge **and** ≥20 min passed (state in `.git/`), and
  never twice in a row (`stop_hook_active`). Cost: one short extra turn at most every 20 min.
- Add the marker block to the project-init `HANDOFF.md` template and `adopt.sh`.
- `config/AGENTS.md`: "When resuming, read `docs/plans/HANDOFF.md` first if it exists."

Verification: temp git repo with a `HANDOFF.md` → `snapshot` writes the block, is
idempotent, leaves the rest byte-identical; `nudge` with `stop_hook_active:true` → silent;
changed tree → block JSON; again within 20 min → silent.

## Phase 4 — Codex (optional, `feat/codex-tier`)

Only if `codex` is installed and logged in; otherwise `install.sh` prints one line and skips.

- `claude mcp add -s user codex -- codex mcp-server` (skip if present).
- `config/CLAUDE.md`: "Large, well-specified implementation → `codex` MCP tool, sandbox
  `workspace-write`, approval `never`, in its own worktree." `never` = Codex runs commands
  without stopping to ask; the sandbox limits it to that worktree folder, so worst case you
  delete the worktree.
- `notify` in `~/.codex/config.toml` → `handoff.sh snapshot` (manual line documented in the
  README; no TOML merger).

Verification: `claude mcp list` shows `codex`; a toy task lands in its worktree and passes.

## Phase 5 — Docs (`docs/neutral-layer`, can ride with each phase)

ADR 0006, ADR 0007, README (install, layout, routing table, "out of Claude quota" runbook:
open `opencode` in the same repo → it reads `AGENTS.md` + `HANDOFF.md` → continue; cost
section: Claude Pro + OpenCode Go baseline).

## Cut from v1 (and why)

| Cut | Why |
|---|---|
| CodeGraph MCP | Useful on big repos; measure first. Revisit when a repo is large enough to hurt. |
| `models.toml` + generated per-tool agent files | One `CHEAP_MODEL` line covers today's need. |
| `mcp.toml` generator, per-tool hook adapters dir | No second MCP to share yet; one script with a mode arg is enough. |
| rulesync changes for OpenCode | OpenCode reads `~/.agents/skills` and AGENTS.md natively. rulesync stays only for Cursor/Antigravity, as today. |
| `opencode serve` / `--attach`, auto-start | Optimization; add if `oc-ask` latency actually bothers. |
| `flock`, frontmatter lint, `--only/--remove` flags | Single user, rare concurrency; removal is deleting symlinks. |
| Agent Deck automation | One README line; install it by hand if you want it. |
| Voice phase | One line in the profile (`/voice`, language set in `/config`, needs claude.ai login). |
