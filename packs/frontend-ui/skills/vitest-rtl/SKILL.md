---
name: vitest-rtl
description: Conventions for unit tests of React + TypeScript with Vitest and React Testing Library - behavior over implementation, accessible queries, hooks, stores, mocking. Use for "escribir tests", "tests del componente/hook", "cobertura", "write tests", "test this component", "RTL". Not for e2e. React Native projects: same principles with the project's runner (Jest + @testing-library/react-native).
---

# Vitest + React Testing Library

- Test observable behavior and the public API, never internals. Prefer accessible queries (`getByRole`, `findByRole`, `getByLabelText`); interact with `@testing-library/user-event`.
- Tests sit next to the file: `<file>.test.ts(x)`. Reuse the project's existing helpers, fixtures and patterns before adding new ones.
- Cover what applies: happy path, edge cases, invalid input, errors, loading, empty, public callbacks, relevant state transitions. No artificial cases for coverage numbers.
- Components: conditional rendering, user interactions, accessibility. Hooks: `renderHook`, initial state, transitions, side effects, reaction to input changes.
- Mock only external dependencies (HTTP, contexts, external stores, navigation, time, browser APIs) with `vi.mock`/`vi.fn`/`vi.spyOn`; small and specific. Never mock the unit under test; use the real thing when it does not make the test brittle.
- Stores: reset state before each test; assert public behavior; no dependence on test order.
- One behavior per test, independent, descriptive names; avoid helpers that hide what is verified.

Before writing: read the unit, its direct dependencies and existing tests. After: run the touched tests, typecheck and lint; do not change production code just to pass a test unless it shows a real defect.

A good test protects behavior the code must keep, not how it is implemented.
