# Standards, enforcement and documentation layer
Read when: explaining or changing what a scaffolded repo enforces (ESLint, tsconfig, CI, stack profiles) or which docs it carries.

## Enforcement

- **ESLint** (`eslint.config.*`, `typescript-eslint@8.71.1` as of writing): `no-explicit-any`, `no-floating-promises`, `no-misused-promises`, `consistent-type-imports`, `switch-exhaustiveness-check`, `no-unnecessary-condition` (all type-aware via `projectService: true`), plus `eqeqeq` and `no-console` (errors, allowing `console.warn`/`console.error`). react-vite/next also get `eslint-plugin-jsx-a11y@6.10.2` recommended rules and keep the zero-useEffect config (`eslint-plugin-react-hooks` + `eslint-plugin-react-you-might-not-need-an-effect`).
  - react-vite and nestjs: `pnpm create vite` and `nest new` default to `oxlint` with no ESLint config; this skill writes a flat `eslint.config.js`/`.mjs`, and `--install` points `lint` at `eslint`.
  - next: `eslint-config-next` already registers the `jsx-a11y` plugin (a few rules at `warn`), so the template merges only `eslint-plugin-jsx-a11y`'s recommended **rules** object, not its flat-config object (that crashes with "Cannot redefine plugin"). No direct `typescript-eslint` dependency: `eslint-config-next/typescript` registers `@typescript-eslint`.
  - node-ts: no generator, so the template ships `eslint.config.mjs` (loads regardless of the package `"type"`), a pinned `typescript@^5` (typescript-eslint 8.x doesn't support TypeScript 7, `npm`'s `latest` tag) and `@types/node`.
- **tsconfig strictness**: `init.sh --install` runs `scripts/ensure-tsconfig-strict.js` to turn on `strict`, `noUncheckedIndexedAccess`, `noImplicitOverride`, and `noFallthroughCasesInSwitch` in the project's tsconfig (`tsconfig.app.json` for react-vite, `tsconfig.json` for next/nestjs; node-ts's template ships all four already). All four work on the stock `pnpm create vite@latest --template react-ts`, `pnpm create next-app@latest` and `pnpm dlx @nestjs/cli new` scaffolds (checked October 2026). The script parses the file with the project's own `typescript` and inserts only the missing flags as text, so comments and formatting survive; without `--install` it only prints what it would do.
- **CI** (`.github/workflows/ci.yml`): the `ci` job (branch protection depends on that check name, do not rename it) has a non-blocking `pnpm audit --audit-level high` step (`continue-on-error: true`) and a `docs-check` step (see below). A `secret-scan` job runs `gitleaks/gitleaks-action@v3` with `fetch-depth: 0` (free for personal GitHub accounts, no `GITLEAKS_LICENSE`). Keep `@v3`: `@v2` is EOL since September 2026 per the action's README (same inputs and behavior, different Node runtime).
- CI's lint step is `pnpm run --if-present lint --max-warnings 0`, with no `--` before the flag: pnpm (12.5.1 as of writing) forwards a literal `--` to `eslint`, which breaks its arg parsing.

## Stack profiles

Node stacks use pnpm defaults inside `init.sh`. Other stacks ship `templates/<stack>/stack.env` (commands, lint/format text, allowed commands), optional `@maven/` / `@gradle/` variant overlays and a `setup.sh` that patches the build file (Spotless, ruff/mypy/pytest). Stack files win over `templates/common` (`SKIP_COMMON` drops the ones that don't apply). For non-node stacks `init.sh` writes `.agents/stack.env`, which `scripts/gh-flow.sh pr` and `verify-ci.sh` use instead of `package.json` scripts.

## Documentation layer

`AGENTS.md`'s "Documentation map" points a new session, in order, to:

1. `.agents/CONTEXT.md`: current stack/architecture snapshot.
2. `docs/plans/HANDOFF.md`: current state + how to resume mid-flight work.
3. `docs/architecture.md`: overview/modules/data model/flows/env/deploy skeleton.
4. `docs/decisions/`: ADRs for trade-offs, starting at `0001-record-architecture-decisions.md`, new ones copied from `0000-template.md`.
5. `.scratch/<slug>/`: spec and tickets of the work in progress, local and gitignored, never committed; what must outlive them goes to an ADR.
6. `docs/prompts.md`: every AI prompt the app sends, verbatim, with its history; deleted if the app calls no model.

`AGENTS.md`'s "Documentation rules" section says when each gets written and keeps `AGENTS.md` itself capped at ~150 lines. The PR template checklist and a non-blocking `docs-check` step in CI (`scripts/docs-check.sh`, warns via `::warning::` when a PR touches deps/env/docker/workflows/top-level folders without touching docs) nudge docs to stay current; neither blocks a merge.
