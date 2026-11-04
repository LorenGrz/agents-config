# AGENTS.md

Single source of truth for humans and AI agents (Codex, Cursor, Claude, others) working on **{{PROJECT}}**. If this file and the code disagree, the code wins - fix this file.

## Documentation map (read this instead of the code)

A new agent session should understand this project from these files alone, in this order:

1. `AGENTS.md` (this file) - map, how we work, engineering standards.
2. `.agents/CONTEXT.md` - current stack/architecture snapshot and repo facts.
3. `docs/plans/HANDOFF.md` - current state and how to resume, read first if work is mid-flight.
4. `docs/architecture.md` - overview, modules, data model, key flows, external services, env, deploy.
5. `docs/decisions/` - ADRs: why a non-trivial trade-off was decided the way it was.
6. `docs/superpowers/specs/` and `docs/superpowers/plans/` - what is being built and how, per unit of work.
7. `docs/prompts.md` - every AI prompt the app sends (verbatim, where it lives, history and lessons). Only if the app calls an AI model.

## Purpose

<!-- One or two sentences: what this project does and for whom. -->

## Stack

- Type: {{STACK}}
- Package manager: {{PKG_MANAGER}}

## Commands

| Command | Purpose |
|---|---|
| `{{CMD_DEV}}` | Run the app locally |
| `{{CMD_TEST}}` | Run the test suite |
| `{{CMD_LINT}}` | {{LINT_DESC}} |
| `{{CMD_TYPECHECK}}` | Type-check without emitting |
| `{{CMD_FORMAT}}` | Auto-format |
| `{{CMD_FORMAT_CHECK}}` | Check formatting without writing |

## How we work (spec-driven, with superpowers)

1. Everything starts as an issue in the Project: `scripts/gh-flow.sh issue <feat|fix|refactor|chore> "<title>"`.
2. Non-trivial `feat`/`refactor` work: superpowers `brainstorming` -> write a spec in `docs/superpowers/specs/` -> superpowers `writing-plans` -> write a plan in `docs/superpowers/plans/`.
3. `fix` work: superpowers `systematic-debugging`; only write a spec if the fix changes behavior.
4. `scripts/gh-flow.sh start <feat|fix|refactor> <slug> --issue N` (or create a worktree with superpowers `using-git-worktrees` for parallel work).
5. Execute with superpowers `subagent-driven-development` + `test-driven-development`.
6. Superpowers `verification-before-completion` -> `scripts/gh-flow.sh pr` -> wait for CI to go green -> `scripts/gh-flow.sh merge`. The issue closes and the Project moves it to Done automatically.
7. Agents without superpowers installed: follow the same seven steps manually.

### Branch and PR rules

- Base branch is `dev`. Never commit or push directly to `dev` or `main`.
- One branch per issue: `feat|fix|refactor/<issue>-<slug>`.
- PR titles are Conventional Commits (`feat: ...`, `fix: ...`, `refactor: ...`, `chore: ...`) - the squash merge uses the PR title as the commit message.
- `main` only changes via `scripts/gh-flow.sh release` (a `dev` -> `main` PR, merged with a merge commit).

### Workflow contract (where each rule is enforced)

These rules live in several places. Changing one (base branch, branch naming, merge strategy, required checks, commit format) means updating **every** row below in the same PR, plus an ADR in `docs/decisions/`. A rule that changes in only one place is a bug.

| Rule | Documented | Enforced by |
|---|---|---|
| No direct commits/pushes to `dev`/`main` | this section | `.claude/hooks/guard-branch.sh`, `.githooks/pre-push`, GitHub branch protection |
| Branch naming `feat\|fix\|refactor/<issue>-<slug>` | this section | `scripts/gh-flow.sh start` |
| PR to `dev`, squash merge, delete branch | this section | `scripts/gh-flow.sh pr\|merge`, repo merge settings |
| Conventional Commit PR titles | this section | `.github/workflows/pr-title.yml` |
| Lint/typecheck/test/build must pass | Definition of done | `.github/workflows/ci.yml` (`ci` check, required by branch protection), `scripts/gh-flow.sh pr` |
| Releases `dev` -> `main` | this section | `scripts/gh-flow.sh release` |
| Issues tracked in the Project | Project backlog | `.github/ISSUE_TEMPLATE/*.yml` (`projects:`), `scripts/gh-flow.sh issue` |

GitHub-side settings (branch protection, merge strategy) are not in the repo: change them with `gh` and record the change in the ADR. CI warns (`scripts/docs-check.sh`) when a PR touches an enforcement file without touching `AGENTS.md`.

## Engineering standards

Mechanical rules live in {{ENFORCEMENT_FILES}} - this section is what no linter catches.

{{LANG_STANDARD}}
- **Validation**: validate every external input (HTTP, env, storage, third-party) at the boundary before it reaches business logic; never trust a shared type as runtime validation.
- **Errors**: typed result objects or domain-specific error classes; preserve cause when wrapping; never leak stack traces or internals through a public API.
- **API contracts**: request/response DTOs at the boundary, consistent machine-readable error shapes, backward-compatible changes. Deeper: `api-contract-design`.
- **Persistence**: repositories persist/retrieve only, no business decisions; migrations for schema changes; transaction boundaries in the application layer, never spanning an external call. Deeper: `database-persistence-patterns`.
- **Security & secrets**: every repo here is public - never commit `.env`, keys, or credentials; read secrets from env vars; authorize from the authenticated principal server-side, never a client-supplied id. Deeper: `auth-security-basics`.
- **LLM-facing code** (only if this app sends untrusted text to an LLM): separate instructions from data, validate model output against a schema, least-privilege tools, human approval for high-risk actions. Deeper: `prompt-injection-defense`.
- **Testing**: behavior over implementation, name by `should <expected> when <condition>`, mock at the boundary, cover happy path + edge cases + errors. Deeper: `unit-test-generator` to write, `execute-test-suite` to run and fix.
- **Commits**: Conventional Commits (`type(scope): subject`), one logical change per commit. Deeper: `conventional-commit-generator`.
- **Docs**: see "Documentation rules" below for what gets saved where and when.

{{STACK_CONVENTIONS}}

## Documentation rules

- Every approved spec/plan is saved under `docs/superpowers/specs/` or `docs/superpowers/plans/` before implementation starts. A Claude plan-mode plan (saved outside the repo, in `~/.claude/plans`) must be copied into `docs/superpowers/plans/YYYY-MM-DD-<slug>.md` before work begins.
- Plans and specs created during a session are saved too, not only the first approved one: worker/subagent specs and mid-session follow-up plans go to `docs/superpowers/plans/YYYY-MM-DD-<slug>.md` in the same PR as the work they describe.
- If the app sends prompts to an AI model, every prompt lives in `docs/prompts.md`: a verbatim copy, the file/function that owns it (the code stays the source of truth), and a short history of what was tried and why it changed. Update it in the same PR as any prompt change.
- Any decision with a real trade-off (architecture, a hard-to-reverse library/service choice, data model, security trade-off) gets a new ADR in `docs/decisions/` - copy `docs/decisions/0000-template.md`.
- When work pauses mid-flight, update `docs/plans/HANDOFF.md` before stopping, not after.
- A PR that changes architecture, env vars, commands, or deploy updates `AGENTS.md`, `.agents/CONTEXT.md`, and `docs/architecture.md` in the same PR.
- `docs/superpowers/` is committed; `.superpowers/sdd/` (the working ledger) stays gitignored.
- Keep this file short (~150 lines max) - details belong in `docs/`.

## Definition of done

- [ ] `{{CMD_LINT}}` passes{{LINT_NOTE}}
- [ ] `{{CMD_TYPECHECK}}` passes
- [ ] `{{CMD_TEST}}` passes, and new behavior shipped with a test
- [ ] `{{CMD_BUILD}}` passes
- [ ] `AGENTS.md` / `.agents/CONTEXT.md` / `docs/architecture.md` updated if stack, scripts, or architecture changed
- [ ] No secrets, keys, or credentials in the diff

## Known issues

<!-- Keep this list current; delete the placeholder once there is real content. -->

## Project backlog

https://github.com/users/{{OWNER}}/projects/{{PROJECT_NUMBER}}
