# Workspace mode
Read when: the target is a plain folder (not a git repo) that holds 2 or more repos of one product side by side, e.g. a frontend and a backend.

Use `scripts/workspace.sh`. Per-repo setup (init or adopt) is unchanged and stays inside each repo; the workspace layer only adds what is shared: a map of the repos, how they talk, the cross-repo flow and, for an organization, its policies and skills.

1. **Recognize it**: the folder has no `.git` and no `AGENTS.md`, and the user confirms it is one product. A workspace is marked by its own `AGENTS.md` (first line `<!-- workspace-init -->`); never infer it from the folder shape alone (a folder of unrelated projects is not a workspace).
2. **Interview** (ask, don't assume): which child dirs are repos and the role of each (frontend, backend, ...); each one's stack (a `config/scopes.json` stack or `-`); how the repos talk (HTTP API, events, shared types) and where the contract lives; the cross-repo flow if it differs from the default; the organization, if any (propose the detected one with `bash scripts/orgs.sh detect <owner>`, run from the hub root).
3. **Dry run first, then apply** (same command without `--dry-run`):
   ```
   bash scripts/workspace.sh --dir <workspace> --name <slug> --repo <dir>:<role>:<stack> --repo ... [--org <name>] [--comm "<text>"] [--cross "<text>"] --dry-run
   ```
   It writes `AGENTS.md` and a `CLAUDE.md` that only says `@AGENTS.md`, both carrying the marker. A workspace is not a repo, so the "no `CLAUDE.md`" rule for repos does not apply to it.
   - **With `--org`**: the config is written to `organizations/<org>/workspaces/<slug>/` (the org's private repo) and the workspace folder gets symlinks to it, so it is versioned and nothing company-specific enters this public repo. Org skills and `POLICIES.md` are installed there with the hub's `project-agents.sh --org <org> --no-packs`.
   - **Without `--org`**: files go in the folder itself, which becomes its own local git repo (child repos git-ignored). No commit and no remote are made; the user decides those.
4. **Never overwrite**: an existing `AGENTS.md`/`CLAUDE.md` without the marker is skipped and reported; merge by hand. Re-running refreshes only files that carry the marker.
5. Show the generated files and the commit command; commit in the org repo (or the local workspace repo) and create any remote only with the user's OK.

Open Claude in the workspace folder for cross-repo work. For code changes, work inside the right repo: its own `AGENTS.md`, `.claude/skills` and hooks apply there. SessionStart tells the agent when it starts in a workspace folder.
