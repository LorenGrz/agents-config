---
name: git-workflow
description: Use this skill before committing, pushing, merging, or opening a PR in any repo - the GitHub push workflow (gitignore gate, branch, verify, commit, push, merge, update AGENTS.md) and, for repos that match an organization, the work-repo rules (base branches, PR flow, tracker writes, issue suggestions).
metadata:
  version: "0.1.0"
  owner: "loren-local"
  source: "moved out of config/AGENTS.md so it loads only when git work happens"
  triggers:
    - commit
    - push
    - merge
    - open a PR
    - create a branch
---

# Git workflow

The always-loaded `config/AGENTS.md` keeps only the hard git rules (no destructive commands, no force-push
to shared branches, ask before pushing in work repos). This skill holds the full procedure.

If the repo has `scripts/gh-flow.sh` (repos scaffolded with `project-init`), use it: the repo's AGENTS.md
flow (base `dev`, PR + squash) overrides this workflow.

## GitHub push workflow (personal repos)

Detect the default branch first: `git symbolic-ref --short refs/remotes/origin/HEAD` (falls back to `main`;
some repos use `master`). Use that name wherever `<default>` appears.

1. **`.gitignore` gate.** Before the first commit in a repo, make sure `.gitignore` exists and covers, at minimum:
   - dependencies: `node_modules/`, `.pnp*`, `.venv/`, `venv/`, `__pycache__/`, `*.py[cod]`
   - env & secrets: `.env`, `.env.*` (but `!.env.example`), `*.pem`, `*.key`, `*credentials*.json`, `*secret*.json`
   - build output: `dist/`, `build/`, `out/`, `.next/`, `.turbo/`, `coverage/`, `*.tsbuildinfo`
   - logs & caches: `*.log`, `.cache/`, `tmp/`
   - OS/editor: `.DS_Store`, `Thumbs.db`, `.idea/`, `.vscode/*` (but `!.vscode/extensions.json`)
   Base it on the github/gitignore template for the stack. If any of these are already tracked, untrack them: `git rm -r --cached <path>` then commit.

2. **Sync `<default>`:** `git checkout <default> && git pull origin <default>`.

3. **Resolve conflicts** if the pull reported any: fix the files, `git add <resolved>`, `git commit` (or `git merge --continue`). Only then continue.

4. **Branch:** `git checkout -b <type>/<slug>` where `<type>` is `feat`, `refactor`, or `fix` and `<slug>` is a short kebab-case summary.

5. **Verify the touched layer**, then **stage & commit.** Run the checks for what changed and fix failures before committing:
   - frontend (React/TS): `pnpm lint` (must pass at `--max-warnings 0`) and `pnpm test run`
   - backend (Kotlin/Spring): `./gradlew test`
   - other stacks: the project's own lint + typecheck + unit tests
   Then review `git status --short`; if unrelated changes are mixed in, ask before continuing. Otherwise `git add .` then `git commit -m "<Conventional Commit subject>"`.

6. **Push the branch:** `git push -u origin <type>/<slug>`.

7. **Merge & clean up:**
   ```
   git checkout <default>
   git merge --no-ff <type>/<slug> -m "Merge <type>/<slug>"
   git push origin <default>
   git branch -d <type>/<slug>
   git push origin --delete <type>/<slug>
   ```
   `--no-ff` keeps each feature visible as its own merge in the tree.

8. **Update project context after merging into `<default>`/`main`/`master`.** If the merged changes alter stack, architecture, modules, env vars, deploy/infra, commands, or known issues, update the project's `AGENTS.md` (and `CLAUDE.md` only if it holds Claude-specific content, plus `.agents/CONTEXT.md` if present) to match the code, commit it as `docs: update AGENTS.md after <branch> merge`, and push it in the same session. Skip only when nothing documented changed, and say so.

If the repo has branch protection or a PR-based flow, stop after step 6 and open a PR with `gh pr create` instead of merging locally.

## Organizations (work repos)

Applies to every repo that matches an organization (`organizations/INDEX.md`); personal repos keep the
lighter flow above. An org's `POLICIES.md` may add to these rules, never relax them.

- **Never commit on the base or release branches** (`main`, `master`, `dev`). Each task starts on a new branch
  named after what it solves, cut from the remote base: `git fetch` then
  `git checkout -b <type>/<scope>-<topic> origin/<base>`. If the org's base branch does not exist yet, cut
  from `origin/main` and rebase onto the base when it appears. Check before the first commit with
  `git merge-base --is-ancestor origin/<base> HEAD`. Never stack a task on an old working branch.
- **Ask before every push or PR**, even when the plan already mentions it. A slash command the user invokes
  for that run (e.g. a ship command) counts as asking.
- **PR flow.** With the user's OK, the PR opens against the org's base branch with the explanation already
  agreed. Opening it also, without asking again: posts a short closing comment on each ticket (the cause and
  what changed, as already explained in the PR, in one or two lines, plus the PR link) and moves each ticket to the project's
  review/test status.
- **Everything else on the tracker is asked first.** Proposals, questions, new tickets, edits or any
  transition outside the PR flow above are shown first and published only after the user's explicit OK on
  that exact text. An approved plan that contains the text does not count.
- **Suggest issues, don't fix them in passing.** Anything found along the way that is out of scope but has
  real impact (security, a user-visible bug, docs that mislead the next person) and is simple to explain is
  proposed at the end of the task: title, impact in one line, proposal in one line, priority and evidence
  (`path:line`). No lint warnings or style preferences, nothing unverified. Filed only with the user's OK.
- **Say exactly where work landed.** Report the branch name; never write "committed to main" for work on a
  branch cut from main.

## Shortcuts
<!-- parsed by scripts/gen-intents.sh -->
- bash: `^git (commit|push|merge|rebase)|^gh pr (create|merge)`
- intent: pull changes — `traete los cambios|tra[eé] los cambios|baj[aá] los cambios|actualiz[aá] la rama|(pull|fetch|get) (the )?(latest )?changes|pull latest` → `git pull origin <base>`
- intent: new branch — `nueva rama|cre[aá] una rama|new branch|start a branch` → `git fetch && git checkout -b <type>/<scope>-<topic> origin/<base>` (never commit on the base branch)
- intent: commit — `(hac[eé]|hacer|hag[aá]) (un )?commit|commite[aá]|commit (my|the) changes|commit this` → `Conventional Commit on a task branch, after git status and verification (see Workflow)`
- intent: push — `sub[ií] los cambios|push[eé]a|(hac[eé]|hacer) (un )?push|push (my|the) changes|git push` → `git push -u origin <branch>` (ask the user first when the repo matches an organization)
- intent: open PR — `abr[ií] (un )?pr|cre[aá] (un )?pr|open (a )?pr|create (a )?pull request` → `gh pr create --base <base>` (show the text and ask first)
