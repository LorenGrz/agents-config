---
paths:
  - "**/*.tsx"
  - "**/*.jsx"
---

# React / frontend

## Zero `useEffect` for logic

- Derived values: compute during render, not in an effect + state. `useMemo` only when measured as expensive.
- User events (click, submit, input change): logic goes in the event handler, not in an effect watching state the handler set.
- Don't mirror a prop into local state with an effect; read it directly or derive from it during render.
- Reset a component's state when an id/prop changes with `key={id}`, not an effect.
- Data loading lives in a custom hook per screen/resource (`useBookDetail`, `useHomeCatalog`), or in TanStack Query / the framework's loaders / React Server Components, never in an inline effect in a component. The hook owns fetch state (data/loading/error) and exposes a reload function; nothing else in the component uses `useEffect` to fetch.
- `useEffect` is allowed only to synchronize with something outside React: subscriptions, browser APIs (resize, media queries, `localStorage` events), non-React widgets. If it subscribes, it must return a cleanup function.
- Never one effect for several unrelated things: one effect per external system, or none if no piece needs one.

## Components

- Split presentational components (props in, markup out) from containers (own hooks, compose presentational children).
- One responsibility per component; if a component both fetches/owns state and renders a non-trivial tree, split it.
- Accessible markup by default: labels, roles, keyboard paths.

## Tests — Vitest + React Testing Library

- Assert behavior (what the user sees/can do), not implementation details (internal state, hook call counts).
- New component/hook ships with a test; `pnpm lint` passes with `--max-warnings 0`; `pnpm test` green.

## Enforcement

`project-init` projects enforce this with `eslint-plugin-react-hooks` (compiler rules such as
`set-state-in-effect`) and `eslint-plugin-react-you-might-not-need-an-effect`. Run `pnpm lint` and fix the
violation; don't disable the rule.

Reference implementation (one valid pattern, not the only one): `~/projects/booklibre/frontend`
(`useOnInit` + a hook per screen + domain classes).

For effects and lifecycle use `react-component-validator`; for building and reviewing UI use the project's `ui-builder` / `ui-review` skills when installed.
