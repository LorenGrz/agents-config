---
paths:
  - "**/*.tsx"
  - "**/*.jsx"
---

# React / frontend

## Zero `useEffect` for logic

- Derived values: compute during render, not in an effect + state. `useMemo` only once you've measured the computation is actually expensive.
- Responses to a user event (click, submit, input change): put the logic in the event handler, not in an effect watching state the handler just set.
- Don't mirror a prop into local state with an effect; read the prop directly, or derive from it during render.
- Need to reset a component's state when an id/prop changes? Use `key={id}` on the component, not an effect that resets state.
- Data loading lives in a custom hook per screen/resource (`useBookDetail`, `useHomeCatalog`), or in TanStack Query / your framework's loaders / React Server Components — never as an inline effect bolted onto a component. The hook owns fetch state (data/loading/error) and exposes a reload function; nothing else in the component reaches for `useEffect` to fetch.
- `useEffect` is allowed only to synchronize with something outside React: subscriptions, browser APIs (resize, media queries, `localStorage` events), non-React widgets. If it subscribes, it must return a cleanup function.
- One effect doing several unrelated things is always wrong — split it into one effect per external system, or remove it entirely if none of the pieces actually need one.

## Components

- Split presentational components (props in, markup out) from containers (own hooks, compose presentational children).
- One responsibility per component; if a component both fetches/owns state and renders a non-trivial tree, split it.
- Accessible markup by default: labels, roles, keyboard paths.

## Tests — Vitest + React Testing Library

- Assert behavior (what the user sees/can do), not implementation details (internal state, hook call counts).
- New component/hook ships with a test; `pnpm lint` passes with `--max-warnings 0`; `pnpm test` green.

## Enforcement

Projects scaffolded with the `project-init` skill enforce this doctrine with
`eslint-plugin-react-hooks` (compiler rules such as `set-state-in-effect`) and
`eslint-plugin-react-you-might-not-need-an-effect`. Run `pnpm lint` and fix the
violation — don't disable the rule.

Reference implementation (one example pattern, not the only valid one):
`~/projects/booklibre/frontend` — `useOnInit` + a hook per screen + domain classes.

For effects and lifecycle use `react-component-validator`; for building and reviewing UI use the project's `ui-builder` / `ui-review` skills when installed.
