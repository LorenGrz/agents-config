# agents-config

You've just opened **agents-config**: a portable agent config + skill library. One repo
configures every coding AI a user runs (Claude Code, Codex CLI, Cursor, Google Antigravity)
the same way, plus an on-demand skill library they all share. See `README.md` for the full
picture; this file is the map for an agent working *in this repo*, not the config it ships
(that's `config/AGENTS.md`, personal content in `config/profiles/<name>.md`).

## If the user asks to install or set up this repo

Use the `agents-config-setup` skill (`skills/meta/agents-config-setup/SKILL.md`) if it's available;
otherwise follow the same steps by hand:

1. Read this repo's `README.md` "Install" section.
2. Run `./install.sh --dry-run` and show the user the plan before touching anything real.
3. Ask the user for their profile name. If `config/profiles/<name>.md` doesn't exist yet,
   offer to create it from `config/profiles/_template.md` by asking: their name, preferred
   language, whether they want English-coaching notes, their GitHub owner/username, and
   their current stack/learning stage.
4. Run `./install.sh --profile <name>` only after the user confirms the dry-run plan.
5. Verify: `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md` exist and import files that
   actually exist; `~/.claude/{rules,hooks,agents}` are symlinks into this repo;
   `~/.claude/skills` is populated (`readlink` a few entries).

Never overwrite a user's existing `~/.claude/` or `~/.codex/` files without going through
`install.sh` — it backs up anything it doesn't already own (`.bak.<timestamp>`) before
writing. Don't hand-edit those generated files; edit the repo and re-run `install.sh`.

## Adding or editing a skill

1. Create or edit `skills/<category>/<skill>/SKILL.md` (categories: `aws/`, `development/`,
   `devops/`, `integrations/`, `meta/`, `productivity/`, `quality/`, `security/`; `external/`
   holds gitignored symlinks to skills installed outside the hub). Each skill is a directory
   with its own `SKILL.md`; frontmatter needs `name` and a `description` that states when to
   use it.
2. Decide its scope: generic skills are global by default; stack-specific ones go under a stack in
   `config/scopes.json` (installed per project by `scripts/project-agents.sh`, ADR 0011). Then run
   `./sync.sh` to refresh the flat `~/.claude/skills` mirror (global skills only).
3. Commit with a Conventional Commit subject (`feat:`, `fix:`, `docs:`, `refactor:`, ...).

## Repo conventions

- Commits follow [Conventional Commits](https://www.conventionalcommits.org/).
- Structural/trade-off decisions about this hub's own layout go in `docs/decisions/` as
  ADRs (copy the newest one's shape; see `docs/decisions/0001-single-repo.md` onward).
- `config/` is the global, machine-wide layer — see `config/README.md`. Per-repo scaffolding
  (for repos *other than this one*) is `skills/devops/project-init`.
- Personal content (names, paths, learning stage, GitHub owner) belongs in
  `config/profiles/<name>.md`, never in `config/AGENTS.md` or `config/CLAUDE.md` — those two
  must stay shareable with anyone who clones this repo.
- Two independent ways to consume this repo: `install.sh` (full — config + rules + hooks +
  subagents + skills) or the Claude Code plugin marketplace (`.claude-plugin/`, skills +
  agents + hooks only, no rules). Pick one method per machine; see `README.md`.
