---
name: react-component-validator
description: Use this skill when an agent must review or edit React components as an architectural linter, avoiding unnecessary or malformed effects, extracting lifecycle logic into custom hooks, and applying the project's useOnInit-style lifecycle standard.
paths:
  - "**/*.tsx"
metadata:
  version: "0.1.0"
  owner: "platform-automation"
  framework: "react"
  focus:
    - component architecture
    - hooks
    - lifecycle
  triggers:
    - React component
    - useEffect
    - custom hooks
    - useOnInit
---

# React Component Validator

## Objective

Keep React components predictable, readable, and lifecycle-safe by avoiding unnecessary effects and extracting reusable behavior into clean hooks.

## Rules

### Before adding or changing `useEffect`

Ask whether the logic can be expressed through render-time derived values, event handlers, reducer state transitions, server state or query library APIs, a custom hook with explicit inputs and outputs, or a project-standard lifecycle helper such as `useOnInit`.

### Effects

- Do not use `useEffect` to derive state that can be computed during render.
- Do not use `useEffect` to mirror props into local state unless there is a clear reset or synchronization requirement.
- Do not omit dependencies to force one-time execution.
- Do not hide dependency issues with broad eslint disables.
- Do not mix unrelated responsibilities in a single effect.
- Always return cleanup functions for subscriptions, timers, observers, sockets, and external listeners.

### `useOnInit` standard

Use `useOnInit` or the repository's equivalent lifecycle hook for intentional mount-only initialization when the codebase already provides that standard:

```tsx
useOnInit(() => {
  loadInitialData();
});
```

If the project does not provide `useOnInit`, prefer an explicit custom hook for the behavior rather than adding ad hoc lifecycle effects throughout components.

### Custom hooks

Extract a hook when lifecycle logic is reused by multiple components; coordinates async loading, subscriptions, timers, or browser APIs; makes the component difficult to scan; or requires cleanup or cancellation. Expose a small API: `const { data, status, retry } = useFeatureData(featureId);`

### Components

- Keep components focused on rendering and user interaction; async orchestration, subscriptions, and integration logic live outside presentational components.
- Prefer controlled data flow over local synchronization effects.
- Prefer explicit status states over boolean combinations that become ambiguous.
- Preserve existing project conventions for state libraries, query clients, forms, and routing.
- In Next.js, keep components as server components unless interactivity, browser APIs, or client-side hooks require `"use client"`.
- In React Native, account for app lifecycle, platform-specific APIs, and native subscriptions when validating effects.

## Reference

Related skills, each only when installed in the project: `ui-builder` / `ui-review` (frontend-ui pack) for broad frontend build and review; `nextjs-ssr-frontend` for server/client boundaries; `react-native-mobile` when lifecycle behavior depends on mobile APIs.

## Output

When acting as a validator, report issues in this order:

1. Broken lifecycle behavior or stale closure risk.
2. Unnecessary effects that should be render-time derivations.
3. Missing cleanup or cancellation.
4. Hook extraction opportunities.
5. Naming or organization improvements.
