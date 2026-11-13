---
name: agents-config-setup
description: Use this skill when the user wants to install, set up, update, or personalize agents-config (this repo) — "install this repo", "set up my profile", "update my agent config", or any request to run/repair install.sh. Guides the install.sh --profile flow end to end.
---

# agents-config Setup

## Objective

Guide a user through installing or updating this repo's config on their machine. Never run
a real (non-dry-run) install without the user confirming the plan first — `install.sh`
touches `~/.claude/` and `~/.codex/`.

## Workflow

1. **Dry run.** From the repo root, run `./install.sh --dry-run` (add `--profile <name>` if
   the user already told you their profile). Show the plan: what it would generate, link,
   or back up. Nothing changes yet.

2. **Resolve the profile.**
   - If the user already has `config/profiles/<name>.md`, confirm that's the one to use.
   - If not, ask: their name, preferred language for replies, whether they want a 2-line
     `English note` + `Better` line added when they write partly/fully in English, their
     GitHub owner/username (for `skills/devops/project-init` defaults), and a short line on their
     current stack/learning stage. Create `config/profiles/<name>.md` from
     `config/profiles/_template.md` with their answers filled in. Don't put any of this in
     `config/AGENTS.md` or `config/CLAUDE.md` — those must stay shareable.
   - `install.sh` without `--profile` also auto-detects via `gh api user --jq .login` and
     persists the choice to `~/.config/agents-config/profile`; mention this but still confirm
     with the user rather than relying on it silently.

3. **Real install**, only after the user confirms the dry-run plan:
   ```
   ./install.sh --profile <name>
   ```
   This generates `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md` (backing up any
   pre-existing real file once, as `.bak.<timestamp>`), symlinks
   `~/.claude/{rules,hooks,agents}` into the repo, mirrors skills into `~/.claude/skills`
   via `sync.sh`, and merges `config/settings.base.json` into `~/.claude/settings.json`.

4. **Verify:**
   - `cat ~/.claude/CLAUDE.md` — should be a generated file (header comment) importing
     `config/AGENTS.md`, the chosen profile, and `config/CLAUDE.md`; confirm each imported
     path exists.
   - `cat ~/.codex/AGENTS.md` — should start with the same header comment, followed by
     `config/AGENTS.md` and the profile content concatenated.
   - `readlink ~/.claude/rules ~/.claude/hooks ~/.claude/agents` — each resolves into the
     repo.
   - `ls ~/.claude/skills | head` — populated; `readlink ~/.claude/skills/<any-name>`
     resolves to a real `<category>/<skill>/` directory in the repo.
   - Re-running `./install.sh --profile <name>` should report everything already up to
     date (idempotent) — run it once more to prove that.

5. **Optional extras**, each asked about before running, never bundled silently:
   - `--with-rulesync`: also generates Cursor and Google Antigravity (Gemini) global config
     via `config/rulesync/`. Explain: Codex and Claude Code already work without it; this is
     only useful if the user also drives those two tools. Requires `pnpm dlx` (network).
   - `--with-rtk`: installs [`rtk`](https://github.com/rtk-ai/rtk), a separate token-
     reduction tool, and runs `rtk init -g`. Explain it's unrelated to the config above —
     skip unless the user specifically wants it.

### Alternative: the plugin marketplace

If the user only wants skills/agents/hooks (not rules, not the generated `CLAUDE.md`/
`AGENTS.md`, not `settings.json` merging), point them at
`claude plugin marketplace add <this-repo>` instead of `install.sh` — see `README.md`'s
Install section. The two methods aren't meant to be combined on the same machine.

## Rules

- `install.sh` never deletes a real file; it backs up anything it doesn't already own
  before writing over it. If something looks wrong after install, check for a
  `.bak.<timestamp>` sibling next to the file in question.
- If `gh` isn't installed/authenticated and the user gave no `--profile`, `install.sh`
  falls back to `config/profiles/_template.md` directly — point this out so the user
  doesn't end up running with unfilled placeholder content by accident.
