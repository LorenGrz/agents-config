# Plan: global vs project scope (approved 2026-11-02)

Outcome: install.sh/sync.sh install only generic skills/rules globally; stack assets install per project.
Files: config/scopes.json, scripts/project-agents.sh, sync.sh, install.sh, devops/project-init/scripts/init.sh,
README.md, config/README.md, devops/project-init/SKILL.md, docs/decisions/0011-global-vs-project-scope.md.
Verify: `./install.sh --dry-run`, `./sync.sh` (45 -> 29 skills), `project-agents.sh --stack nestjs,apex,supabase --dir <tmp>`.
Global MCP: removed github/atlassian/slack from ~/.claude.json (gh CLI covers GitHub; Jira/Slack are per-project/opt-in).
