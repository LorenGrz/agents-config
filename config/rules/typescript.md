---
paths:
  - "**/*.ts"
  - "**/*.tsx"
---

# TypeScript

## Types and boundaries

- No `any`. Use `unknown` at untrusted boundaries (HTTP, env, storage, 3rd-party) and narrow it.
- Validate external input at the boundary; convert to domain types before business logic.
- Discriminated unions for state machines, async states, and result variants.
- Avoid non-null assertions unless the invariant is already enforced nearby.
- Keep DTOs, API response types, and domain types separate when they mean different things.
- Treat a typecheck failure as a test failure.

For depth, use the `typescript-code-quality` skill.
