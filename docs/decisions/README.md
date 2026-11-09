# Decisions (ADRs)

- [0001 — One repo for agent config and skills](0001-single-repo.md) — fold `aws-skills` into `aws/` via `git subtree`; drop external symlinks.
- [0002 — rulesync for multi-AI rule/skill distribution](0002-rulesync-for-multi-ai.md) — `config/rulesync/build.sh` rebuilds a throwaway `.rulesync/` tree from the real sources.
- [0003 — Model routing by task complexity, not by habit](0003-model-routing-by-complexity.md) — Opus decides, Sonnet writes, Haiku looks up; escalate to `reasoner` after two failures.
- [0004 — Token budget for always-loaded files](0004-token-budget.md) — keep `config/CLAUDE.md` ≤60 lines; move detail to the thing it describes.
- [0005 — Portable install, personal profiles, and a plugin marketplace](0005-portable-install-and-profiles.md) — personal content in `config/profiles/<name>.md`; `install.sh --profile`; marketplace subset.
- [0006 — The main session delegates open lookups and large changes](0006-always-delegate.md) — open lookups to `scout`, large changes to `worker`; small known-file edits stay inline.
- [0007 — Rename agent-config to agents-config](0007-rename-to-agents-config.md) — repo, plugin, marketplace, docs and setup skill renamed.
- [0008 — SessionStart hook for routing and codebase-map refresh](0008-session-start-hook.md) — re-inject routing each session; nudge to refresh `.agents/CONTEXT.md` in large or stale repos.
- [0009 — `opusplan` default and critical-reasoning hook](0009-opusplan-and-critical-reasoning-hook.md) — plans on Opus, execution on Sonnet; hook nudges toward `reasoner` on critical work.
- [0010 — Delegating work to Gemini through `agy`](0010-gemini-delegation-via-agy.md) — `gemini-delegate` skill + script (`run` headless / `open` interactive); clean-worktree guard.
- [0011 — Global vs project scope for skills, rules and MCP](0011-global-vs-project-scope.md) — only global skills in `~/.claude`; stack skills are copied per project.
- [0012 — Layers: base, organizations, projects](0012-layers-and-organizations.md) — public base + `baseline.md`; private org repos in `organizations/`; `orgs.sh`.
- [0013 — project-init interview, manifest and stack profiles](0013-interview-manifest-and-stack-profiles.md) — `project.json`, ADR per decision, `stack.env`, Java/Kotlin/Python templates.
- [0014 — Packs, keyword index and critical hooks](0014-packs-keyword-index-and-critical-hooks.md) — packs by architecture; table in `AGENTS.md`; `critical.json` hint hook.
- [0015 — Leak guard and generated plugin files](0015-leak-guard-and-generated-plugin-files.md) — local blocklist, pre-commit + CI; `gen-plugin.sh`.
- [0016 — Integrations: plugins, user-scope MCP and outbound guardrails](0016-integrations-plugins-mcp.md) — plugins in settings.base.json, `config/mcp.user.json`, `ask` rules, paste-preview patch.
- [0017 — Intent router, per-project plugins and workspaces](0017-intent-router-and-workspaces.md) — `## Shortcuts` in skills -> `intent-router.sh`; plugins per stack; workspace mode in project-init.
- [0018 — Opus medium default, planning high via `reasoner`](0018-opus-medium-default-reasoner-high.md) — supersedes the `opusplan` default; effort is per model, so high planning rides on the `reasoner` subagent.
