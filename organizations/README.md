# Organizations

Each organization (employer, client) is **its own private git repo** cloned into `organizations/<name>/`. This public repo never tracks them (`.gitignore`), never stores their URL, and `scripts/leak-guard.sh` fails if one gets tracked. Manage them with `scripts/orgs.sh`.

An org adds its policies, skills, commands and interview questions on top of the base. The working rules every org repo inherits (branch per task from the remote base, never commit on `main`/`dev`, ask before push/PR, approve tracker text, suggest issues) live in `config/AGENTS.md` § Organizations. It may override conventions (base branch, PR format, language, tracker, design system) but never `config/baseline.md`; when it replaces a base practice, the project records an ADR.

## Contract

```
organizations/<name>/
  org.json          required
  POLICIES.md       required: a summary of 15 lines or fewer first, then one section per topic
  skills/<name>/SKILL.md
  commands/<name>.md
  interview.md      extra questions for project-init (optional)
  scripts/          helper scripts the org's skills and commands call (optional, not copied into projects)
  workspaces/<slug>/  multi-repo workspace configs, written by project-init's workspace.sh (optional)
```

An org repo can also be **self-sufficient**, so a teammate can use it without this hub. It then adds:

```
  .claude-plugin/   plugin.json + marketplace.json: install it as a Claude Code plugin
  hooks/            hooks.json + scripts: a SessionStart hook that shows the POLICIES.md summary
  install.sh        installs skills, commands and POLICIES.md into ~/.claude, or into a project with
                    --project <path>; keeps a manifest, supports --dry-run and --uninstall; refuses
                    a project that already runs agents-config
  AGENTS.md         map of the org repo for any agent
  README.md         the two ways to install it
```

The hub reads only `org.json`, `POLICIES.md`, `skills/`, `commands/`, `interview.md` and `workspaces/`; the
self-sufficient files are ignored by `orgs.sh` and `project-agents.sh`. `project-agents.sh` refuses an org
directory that contains symlinks, so keep dependencies out of the repo (install them elsewhere, e.g. under
`~/.cache`).

`org.json`:

```json
{
  "name": "acme",
  "version": "0.1.0",
  "extends": "agents-config>=0.1.0",
  "match": { "gh_owners": ["acme-inc"], "remote_patterns": [] },
  "agent_providers": ["claude_code"],
  "defaults": {
    "base_branch": "dev",
    "commit_language": "en",
    "pr_title_language": "en",
    "pr_body_language": "en",
    "tracker": "none",
    "tracker_project": ""
  },
  "blocklist_terms": ["acme"],
  "replaces": {
    "ui-builder": "acme-ui-builder",
    "github-usage": "acme-github",
    "/smart-commit": "/acme-commit"
  },
  "assets": { "commands/acme-commit.md": { "stacks": ["react-vite"] } },
  "index": [{ "when": "Create a ticket", "use": "acme-ticket" }],
  "critical": [{ "skill": "acme-erp", "keywords": "erp|invoice sync" }]
}
```

| Key | Required | Read by | Meaning |
|---|---|---|---|
| `name` | yes | `orgs.sh`, `project-agents.sh` | Same as the directory name; lowercase letters, digits and `-` |
| `version` | yes | `orgs.sh status`, `.agents/skills.lock` | The org's own version; projects freeze it |
| `extends` | no | `orgs.sh status` | Minimum base version, `agents-config>=x.y.z`; status warns when the base is older |
| `match` | yes | `orgs.sh detect`, `init.sh`, the global index | `gh_owners` (GitHub owners) and `remote_patterns` (regex on the remote URL); at least one entry in total |
| `agent_providers` | no | caolg | CAO providers allowed for agents in the org's repos (e.g. `["claude_code"]`); caolg's leader only opens workers of these providers. Missing means all, so drop the key to allow any model |
| `defaults` | no | agents (and `intent-router.sh` for `base_branch`) | Org conventions in one place: `base_branch`, `commit_language`, `pr_title_language`, `pr_body_language`, `tracker`, `tracker_project`, and any extra descriptive key (stack summary, tracker projects by repo, ...). Only `base_branch` is read by a script; `POLICIES.md` is the human-readable source for the rest |
| `blocklist_terms` | no | `orgs.sh` | Words that must never appear in the public repo; merged into the local leak-guard blocklist together with `name` and `match.gh_owners` |
| `replaces` | no | `orgs.sh validate`, `project-agents.sh` | Flat map `base name -> org name`. A skill is a plain name, a command starts with `/`; a skill can only be replaced by a skill and a command by a command. The target must exist in the org's `skills/` or `commands/`. The base item can be a pack skill, a stack skill or a hub integration skill (`github-usage`, `jira-usage`, ...) |
| `assets` | no | `project-agents.sh` | Per-file stack filter, keyed `skills/<name>` or `commands/<name>.md`; a file without an entry is installed for every stack |
| `index` / `critical` | no | `project-agents.sh` | Rows for the project's keyword table and `.agents/critical.json`, merged before the packs' own. A row may carry `"stacks": [...]` |

Notes:

- `pr_title_language` and `pr_body_language` are separate on purpose: an org can ask for English
  Conventional Commit titles and a Spanish body, or the other way round. They replace the older single
  `pr_language`.
- `blocklist_terms` must not keep the template's `acme` placeholder (validation fails).
- When a replacement applies to a project, `project-agents.sh` removes the replaced skill or command from
  the project's `.claude/`, rewrites references to it in the skills and commands it installed, and points
  the index and critical rows at the replacement.

## Use

```
scripts/orgs.sh add <name> <git-url>     clone and register
scripts/orgs.sh add <name> --init        start a new local org from _template/
scripts/orgs.sh validate <name|path>     check the contract
scripts/orgs.sh detect <owner|remote>    which org owns this repo
scripts/orgs.sh status | pull | push     one repo at a time, push asks first
```

project-init asks which org a project belongs to (proposing the detected one), then `project-agents.sh --org <name>` copies the org's skills and commands, merges its index and critical entries, and copies `POLICIES.md` to `.agents/POLICIES.md`. The project freezes the base and org versions in `.agents/skills.lock`; updates are always explicit.

`orgs.sh validate` runs automatically on `add`, `pull` and before `project-agents.sh --org` installs anything (fail closed). It is advisory: it catches mistakes and obvious phrases that weaken the baseline, it does not make an untrusted org safe. `init.sh` asks before copying an org's `POLICIES.md` into a project whose owner is not one of the org's `gh_owners` (`--allow-org-mismatch` to proceed).

To create an org for a new client, use the `org-creator` skill.
