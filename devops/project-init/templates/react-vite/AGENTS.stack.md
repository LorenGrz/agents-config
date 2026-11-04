## React + Vite conventions

Zero-useEffect doctrine, enforced by `eslint.config.js` (`react-hooks/set-state-in-effect`, `react-you-might-not-need-an-effect/*`):

- Derived values are computed in render, never copied into state inside an effect.
- Responses to user actions live in event handlers, not effects.
- Data loading lives in a custom hook per screen/resource (or TanStack Query) - not an ad-hoc `useEffect` + `useState` pair.
- `useEffect` is only for syncing with something outside React (subscriptions, browser APIs, a WebSocket) - always with a cleanup function if it subscribes.
- Before adding an effect, run the `react-component-validator` checklist: can this be a render-time derivation, an event handler, or a custom hook instead?

Structure and components, reviewed with `ui-review`:

- Feature-oriented folders unless the repo already defines a convention; shared UI stays generic, domain behavior stays inside the feature.
- Split presentational components (props in, markup out) from containers (own hooks, compose children); one responsibility per component.
- Model loading/empty/error/success states explicitly; stable keys from domain data, never array indexes.
- Accessible markup - labels, roles, keyboard paths on every interactive element (not just native `<button>`/`<a>`) - enforced by `eslint-plugin-jsx-a11y` in `eslint.config.js`.

Tests: Vitest + React Testing Library, colocated as `*.test.tsx`, asserting behavior not implementation.
