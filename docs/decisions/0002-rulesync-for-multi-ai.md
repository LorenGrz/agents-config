# 0002 — rulesync for multi-AI rule/skill distribution

## Context

`AGENTS.md` and `config/rules/*.md` are Claude Code/Codex-flavored (Codex reads
`AGENTS.md` directly; `rules/*.md` uses Claude Code's own `paths:` frontmatter). Cursor and
Google's Gemini-family tooling (Antigravity) each want their own file formats and
locations (`.cursor/rules/*.mdc`, `~/.gemini/GEMINI.md` + `~/.gemini/config/rules/*.md`).
Hand-maintaining a parallel copy per tool duplicates content and drifts.

[`rulesync`](https://github.com/dyoshikawa/rulesync) (`pnpm dlx rulesync`) converts one
source tree into per-tool outputs for ~50 tools, including a `--global`/`-g` (user-scope)
mode.

## Decision

Use rulesync, sourced from `config/rulesync/build.sh`, which rebuilds a throwaway
`.rulesync/` tree from this repo's real sources on every run:

- `config/AGENTS.md` → `.rulesync/rules/overview.md` (root rule; frontmatter added).
- Each `config/rules/*.md` → `.rulesync/rules/<name>.md` (its `paths:` list becomes
  rulesync's `globs:`; frontmatter added, body copied through unchanged).
- A handful of skills (`project-init`, `typescript-code-quality`, `react-component-validator`
  as the proof set) are **symlinked**, not copied, into `.rulesync/skills/` — rulesync
  follows symlinks when discovering source files and their frontmatter already matches
  what it expects, so no transform is needed.

`.rulesync/` itself is gitignored (`config/rulesync/.gitignore`): it is a build artifact,
not a second source of truth.

Targets actually generated, verified with `HOME` pointed at a temp dir:

| Target | Global rules | Global skills |
|---|---|---|
| `codexcli` (Codex CLI) | ✅ → `~/.codex/AGENTS.md` | ✅ |
| `cursor` | ❌ (rulesync: project scope only) | ✅ → `~/.cursor/skills/` |
| `antigravity-cli` (Gemini-family CLI) | ✅ → `~/.gemini/GEMINI.md`, `~/.gemini/config/rules/*.md` | ✅ → `~/.gemini/antigravity-cli/skills/` |

**There is no `geminicli` target.** It was assumed in the plan but rulesync's schema
rejects it outright (`Invalid option: expected one of "agentsmd"|...`, no `geminicli`
listed). The actual Gemini-family integration rulesync ships is Google Antigravity
(`antigravity-cli` / `antigravity-ide`), which already matches this hub's existing
`sync.sh` step 3 (it links `~/.gemini/config/skills` to the mirror) — so `antigravity-cli`
was substituted and is what `install.sh --with-rulesync` actually drives.

In the real `$HOME` (not the temp-HOME test), `~/.codex/AGENTS.md` is already a symlink
into this hub (installed by `install.sh` itself). Per rulesync's own symlink-safety rule,
generation skips writing through a link that leads outside the output root — so running
rulesync for `codexcli` against the real home is a safe no-op for that file; Codex already
gets `AGENTS.md` via the existing symlink without rulesync's help. rulesync's real value
here is `cursor` and `antigravity-cli`, which this hub did not otherwise reach.

## Consequences

- One edit to `config/AGENTS.md` / `config/rules/*.md` / a sourced skill propagates to
  Cursor and Antigravity global config via `install.sh --with-rulesync`, no manual copy.
- `cursor` never gets a global rules file from this pipeline — only skills/subagents/mcp/
  hooks/permissions. If Loren wants Cursor rules, they have to be per-project (rulesync
  supports that, just not in `--global` mode); documented here rather than worked around.
- `geminicli` is not a real target; if a future rulesync release adds a plain "Gemini CLI"
  target, add it to `config/rulesync/rulesync.jsonc`'s `targets` array — no other change
  needed since `features` and the build already parameterize per-target output.
