# 0011 — Global vs project scope for skills, rules and MCP

Status: accepted (2026-11-02)

## Context
Everything was installed globally: 45 skills (descriptions loaded every session) and 8 rules in
`~/.claude/`, regardless of the repo. Stack-specific skills (NestJS, Next, AWS, APEX...) cost context
in unrelated work, and `project-init` only scaffolded enforcement, not agent assets.

## Decision
`config/scopes.json` lists stacks (`react-vite`, `next`, `nestjs`, `node-ts`, `rn`, `aws`, `python`,
`kotlin`, `apex`, `docker`, `llm`, `supabase`, `jira`) with their skills, rules and MCP servers.
**Anything not listed is global.** `install.sh`/`sync.sh` install only the global set;
`scripts/project-agents.sh --stack a,b` (also run by `project-init`'s `init.sh`, with `--with` for
extras) copies the stack's skills/rules into the project's `.claude/` and merges MCPs into `.mcp.json`.

## Consequences
- Lower baseline context per session (45 -> 29 skills, 8 -> 3 rules).
- Stack skills do not auto-activate in a repo that never ran `project-agents.sh`.
- Copies (not symlinks) keep repos portable for CI/clones; re-run the script to refresh them.
- claude.ai connectors (Notion, Miro, Whimsical, Supabase) are account-level and cannot be scoped here.
