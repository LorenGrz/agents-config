---
name: react-component-validator
description: Use this skill when an agent must review or edit React components as an architectural linter, avoiding unnecessary or malformed effects, extracting lifecycle logic into custom hooks, and applying the team's useOnInit-style lifecycle standard.
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

## Validation Checklist

Before adding or changing `useEffect`, ask whether the logic can be expressed through:

- Render-time derived values.
- Event handlers.
- Reducer state transitions.
- Server state or query library APIs.
- A custom hook with explicit inputs and outputs.
- A project-standard lifecycle helper such as `useOnInit`.

## Effect Rules

- Do not use `useEffect` to derive state that can be computed during render.
- Do not use `useEffect` to mirror props into local state unless there is a clear reset or synchronization requirement.
- Do not omit dependencies to force one-time execution.
- Do not hide dependency issues with broad eslint disables.
- Do not mix unrelated responsibilities in a single effect.
- Always return cleanup functions for subscriptions, timers, observers, sockets, and external listeners.

## `useOnInit` Standard

Use `useOnInit` or the repository's equivalent lifecycle hook for intentional mount-only initialization when the codebase already provides that standard.

Expected usage pattern:

```tsx
useOnInit(() => {
  loadInitialData();
});
```

If the project does not provide `useOnInit`, prefer an explicit custom hook for the behavior rather than adding ad hoc lifecycle effects throughout components.

## Custom Hook Guidance

Extract a hook when lifecycle logic:

- Is reused by multiple components.
- Coordinates async loading, subscriptions, timers, or browser APIs.
- Makes the component difficult to scan.
- Requires cleanup or cancellation.

Custom hooks should expose a small API:

```tsx
const { data, status, retry } = useFeatureData(featureId);
```

## Component Rules

- Keep components focused on rendering and user interaction.
- Keep async orchestration, subscriptions, and integration logic outside presentational components.
- Prefer controlled data flow over local synchronization effects.
- Prefer explicit status states over boolean combinations that become ambiguous.
- Preserve existing project conventions for state libraries, query clients, forms, and routing.
- In Next.js, keep components as server components unless interactivity, browser APIs, or client-side hooks require `"use client"`.
- In React Native, account for app lifecycle, platform-specific APIs, and native subscriptions when validating effects.

## Review Output

When acting as a validator, report issues in this order:

1. Broken lifecycle behavior or stale closure risk.
2. Unnecessary effects that should be render-time derivations.
3. Missing cleanup or cancellation.
4. Hook extraction opportunities.
5. Naming or organization improvements.

## Compatibility Notes

- Pair this skill with `ui-builder` / `ui-review` (frontend-ui pack) for broad frontend build and review.
- Pair this skill with `nextjs-ssr-frontend` when reviewing server/client boundaries.
- Pair this skill with `react-native-mobile` when lifecycle behavior depends on mobile APIs.
