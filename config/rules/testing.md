---
paths:
  - "**/*.test.ts"
  - "**/*.test.tsx"
  - "**/*.spec.ts"
  - "**/*.spec.tsx"
  - "**/*.e2e-spec.ts"
---

# Tests

## Writing tests

- Test observable behavior, not private implementation.
- Each test is independent and order-free.
- Name by behavior: `should <expected> when <condition>`.
- Cover happy path, edge cases (empty, null, boundary), and expected errors.
- Mock external systems (network, filesystem, clock, DB) at the boundary.
- Do not weaken assertions or skip cases to make a suite pass.
- Match the project's existing framework and file layout; never switch package managers.

To generate a test file, use `unit-test-generator`. To run a suite and fix failures, `execute-test-suite`.
