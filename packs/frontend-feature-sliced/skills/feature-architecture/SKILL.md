---
name: feature-architecture
description: Feature-sliced frontend architecture - per-feature folder structure, barrel files as the only cross-feature contract, shared layer rules, and the lint/cycle checks that enforce them. Use for "nueva feature", "dónde va este archivo", "estructura del feature", "imports entre features", "new feature", "where do files go", "cross-feature import".
---

# Feature architecture

## Objective

Keep a feature-sliced frontend consistent: per-feature structure, barrel files as the only cross-feature contract, and lint/cycle checks that enforce it.

## Rules

### Structure

```
src/features/<feature>/
  api/          pure HTTP functions, no business logic
  components/   presentational UI: no mutations, no navigation
  pages/        (optional) routed pages
  hooks/        logic: queries, mutations, navigation, local state
  schemas/      validation schemas and inferred types
  types/        extra domain types
  index.ts      the barrel: the feature's public contract
src/shared/     reusable components, lib, hooks (never imports from features)
src/router/     composition root: the only place that mounts pages and guards of several features
```

Use only the folders a feature needs. `pages/` exists when the feature has 3+ pages or mixes pages with layouts, guards or flow modals; otherwise the page lives in `components/` with a `-page.tsx` suffix.

### Feature rules

- A page only calls hooks and renders. Queries, mutations, navigation and error handling live in hooks.
- Components receive data and callbacks through props. Exceptions: guards, layouts and gates may navigate (the router mounts them).
- A feature reaches another one only through its barrel (`@/features/x`), including dynamic `import()`. What is inside is free to move.
- `shared/` never imports from `features/`. If shared needs something, inject it by props or children from the router.
- Where a component goes: component library -> composition of its primitives -> `shared/` if reusable -> feature-local only if specific to that flow. When unsure, `shared/`.
- Files are `kebab-case`, components are `PascalCase` named exports, hooks are `use-*`. Routes come from one central constants file, never string literals.

### Enforcement (set these up, do not rely on discipline)

- ESLint boundaries (`eslint-plugin-boundaries` or `no-restricted-imports` zones): barrel-only access, shared -> features forbidden, page/component layer restrictions.
- Cycle detection with `dependency-cruiser` in CI; the lint checks each import's direction, a cycle is built from individually legal imports.
- Bundle-size exceptions to the barrel rule are listed in one place with the measured size, never with `eslint-disable`.
