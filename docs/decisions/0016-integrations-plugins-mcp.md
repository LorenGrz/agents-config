# 0016 — Integrations: plugins, user-scope MCP and outbound guardrails

Status: accepted (2026-11-08)

## Context
The hub versioned skills, hooks and rules, but not the third-party plugins and MCP servers actually in use
(paste-preview, skill-creator, Codex, claude-obsidian, NotebookLM, Obsidian). Re-running `install.sh` would
also have flipped plugins that were enabled by hand, and nothing limited what an agent can send out through
Slack, Gmail, Calendar, Jira, GitHub or Drive. Per-project MCP already exists (ADR 0011); a personal, global
layer did not.

## Decision
- **Account connectors** (Slack, Atlassian/Jira, GitHub, Gmail, Calendar, Drive) come from the claude.ai account
  and are not declared in files. The hub adds usage skills and guardrails only.
- **Plugins** are declared in `config/settings.base.json` (`enabledPlugins` + `extraKnownMarketplaces`, merged
  key by key by `install.sh`): paste-preview, mattpocock-skills, claudex-loop, codex, claude-obsidian,
  andrej-karpathy-skills, skill-creator. The `github` plugin is off: it fails to authenticate and duplicates the
  claude.ai connector and `gh`. The Vercel plugin is on (it was enabled by hand; the base used to turn it off and
  `install.sh` would have disabled it on the next run). n8n, impeccable, higgsfield and graphify stay out for now.
- **User-scope MCP** servers live in `config/mcp.user.json` and are registered by
  `install.sh --with-integrations` (`claude mcp add-json --scope user`, idempotent, no secrets): `notebooklm`
  (`notebooklm-py` pinned, login by hand) and `obsidian` (`@bitbonsai/mcpvault` pinned; reads and writes the
  vault by filesystem, confined to it; path from `$OBSIDIAN_VAULT`). This is a deliberate exception to "MCP is
  opt-in per repo": both are personal tools, not tied to a stack. Machine-specific servers (e.g. `cao-mcp-server`)
  stay out.
- **Guardrails**: `permissions.ask` in `settings.base.json` covers outbound or hard-to-reverse tools (send,
  schedule, create/update/delete events, create/edit/transition Jira, merge/create PR, push files, share/trash
  Drive, delete/move in Obsidian). Reads and drafts are not gated.
- **Local patch**: paste-preview opens its editor on every paste and has no setting for it.
  `config/patches/paste-preview-no-autoedit.sh` comments that one line; `install.sh` re-runs it (idempotent)
  because a plugin update overwrites it. The Edit button still opens the editor.
- Plugins were audited from source before declaring them (hooks, network, exec). Codex's Stop review gate stays
  off (opt-in in the plugin); claude-obsidian's SessionStart context is off by default.

## Consequences
`install.sh` now touches more of the machine only behind `--with-integrations`; plain runs just merge settings
and re-apply the patch. Pinned versions need a deliberate bump. The paste-preview patch can break if upstream
changes that line (the script warns instead of failing). Writes through the Obsidian MCP are not gated except
delete/move, so keep the vault under backup or git.
