# Organizations

Each organization (employer, client) is **its own private git repo** cloned into `organizations/<name>/`. This public repo never tracks them (`.gitignore`), never stores their URL, and `scripts/leak-guard.sh` fails if one gets tracked. Manage them with `scripts/orgs.sh`.

An org adds its policies, skills, commands and interview questions on top of the base. The working rules every org repo inherits (branch per task from the remote base, never commit on `main`/`dev`, ask before push/PR, approve tracker text, suggest issues) live in `config/AGENTS.md` § Organizations. It may override conventions (base branch, PR format, language, tracker, design system) but never `config/baseline.md`; when it replaces a base practice, the project records an ADR.

## Contract

```
organizations/<name>/
  org.json        required
  POLICIES.md     required: a summary of about 10 lines first, then one section per topic
  skills/<name>/SKILL.md
  commands/<name>.md
  interview.md    extra questions for project-init (optional)
```

`org.json`:

```json
{
  "name": "acme",
  "version": "0.1.0",
  "extends": "agents-config>=0.1.0",
  "match": { "gh_owners": ["acme-inc"], "remote_patterns": [] },
  "defaults": { "base_branch": "dev", "pr_language": "en", "tracker": "none" },
  "blocklist_terms": ["acme"],
  "replaces": { "ui-builder": "acme-ui-builder", "/smart-commit": "/acme-commit" },
  "assets": { "commands/acme-commit.md": { "stacks": ["react-vite"] } },
  "index": [{ "when": "Create a ticket", "use": "acme-ticket" }],
  "critical": [{ "skill": "acme-erp", "keywords": "erp|invoice sync" }]
}
```

- `match`: how project-init and the global index recognize the org (GitHub owner or a regex on the remote URL).
- `blocklist_terms`: words that must never appear in the public repo; `orgs.sh` merges them into the local leak-guard blocklist.
- `replaces`: base pack skills (`name`) or commands (`/name`) that the org replaces with its own, so both do not trigger.
- `assets`: optional per-file filter by stack; a file without an entry is installed for every stack.
- `index` / `critical`: rows for the project's keyword table and `.agents/critical.json`, merged before the packs' own. A row may carry `"stacks": [...]` to apply only to projects of those stacks.
- Commands installed from packs that point at a replaced skill are rewritten to point at the org's replacement.

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
