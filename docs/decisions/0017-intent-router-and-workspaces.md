# 0017 — Intent router, per-project plugins and workspaces

Status: accepted (2026-11-08)

## Context
Integration skills (`git-workflow`, `github-usage`, `slack-usage`, `jira-usage`, ...) only activated because
prose in `config/CLAUDE.md` asked the model to use them: nothing fired when a Slack or GitHub tool was called,
and a phrase like "traete los cambios" depended on the model remembering the exact command a skill dictates
(`git pull origin <base>`). Eleven plugins were enabled in every session of every project, including web-only
ones. And the agent did nothing special when a session started in a repo with no `AGENTS.md`, in a repo whose
stack skills were never installed, or in a folder that groups several repos of one product (a frontend and a
backend) and so has no repo of its own to carry config.

## Decision
- **Shortcuts live in the skill that owns them.** Each integration skill ends with `## Shortcuts`: `tools:` and
  `bash:` patterns (what identifies its calls) and `intent:` lines (label, phrase regex in Spanish and English,
  command). Plugin skills can't be edited, so theirs go in `config/intents.plugins.md`.
  `scripts/gen-intents.sh` derives `config/intents.json` (read by the hook) and a short table in
  `config/AGENTS.md` between `intents:` markers, so Codex and Cursor get the phrase -> skill map too.
  `sync.sh` regenerates it and CI runs `--check`.
- **`config/hooks/intent-router.sh`** runs on `UserPromptSubmit` and on `PreToolUse` for `Bash` and the MCP
  integration tools. A phrase injects "skill X; run <command>"; a tool or `gh`/`git` command injects "load skill X
  first". Once per session per skill (marker under `$XDG_RUNTIME_DIR/agents-intents/<session>/`), silent inside
  subagents, English text, guidance only: it never blocks and always exits 0. A hook can't invoke a skill, so
  injecting the skill name and the approved command is the closest equivalent; the `permissions.ask` rules from
  ADR 0016 still gate anything outbound.
- **`<base>`** in a command is resolved per repo: `scripts/gh-flow.sh` present -> `dev`; an AGENTS.md
  "Base branch is `x`" rule; the matching organization's `defaults.base_branch`; `origin/HEAD`; `main`.
- **Plugins by scope.** `vercel` and `playwright` are off in `settings.base.json`. `scopes.json` stacks carry a
  `plugins` list (`next`: both, `react-vite`: playwright) and `project-agents.sh` merges it into the project's
  `.claude/settings.json` `enabledPlugins`; `--plugin` forces it. Other plugins stay global. Where plugin skills
  overlap the hub's, `config/CLAUDE.md` names one default per task (planning, TDD and unknown-cause debugging
  from superpowers; TypeScript review from `code-review-safety`; git always through `git-workflow`).
- **SessionStart checks the project state** and only proposes, never writes: repo without `AGENTS.md` ->
  `project-init`; repo with `AGENTS.md` and no `.agents/project.json` or `.claude/skills` -> the command
  `project-agents.sh --stack <detected> --dry-run` (`scripts/detect-stack.sh`); workspace folder -> read its
  `AGENTS.md`; any other folder -> a one-line notice.
- **Workspace** = a folder that is not a git repo and carries its own `AGENTS.md` whose first line is
  `<!-- workspace-init -->`. The marker is explicit on purpose: inferring it from "a folder with 2+ repos" would
  also catch `~/projects`, which holds unrelated projects. `project-init`'s workspace mode
  (`devops/project-init/scripts/workspace.sh`) interviews, then writes the repo map, how the repos talk, the
  cross-repo flow and, with an org, its policies and skills (`project-agents.sh --no-packs`; the `always` packs
  assume a repo and `gh-flow.sh`). Stack skills stay in each repo.
- **Where a workspace's config is versioned.** With an org: `organizations/<org>/workspaces/<name>/` in the
  org's private repo, with symlinks into the folder, so nothing company-specific reaches this public repo. Without
  one: the folder itself becomes a local git repo that ignores the child repos; no commit, no remote.

## Consequences
- The router is advisory, like every hook here: the model can still ignore the injected text. It removes
  "forgot to load the skill", not "chose not to".
- The shortcut table can drift from a skill if someone edits a skill without running `gen-intents.sh`; CI
  catches that. Phrase regexes are heuristics: a missed phrase just means no injection, a false hit costs one line
  of context once per session.
- Every repo without `AGENTS.md` (including third-party clones) gets the `project-init` proposal at session start.
- Turning `vercel`/`playwright` off globally means a web repo not set up with `project-agents.sh` won't have
  them until `--plugin` or the stack enables them. `install.sh` applies the change on its next run.
- Not verified in a real session: Claude Code following a `.claude` symlink in a workspace folder, and
  per-project `enabledPlugins` taking effect. Both are checked by hand after the first real workspace is created.
