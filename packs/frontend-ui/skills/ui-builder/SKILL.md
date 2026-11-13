---
name: ui-builder
description: Workflow to build pages and components from a design (Figma, screenshot, description) without drift from the project's tokens, component library and architecture. Use for "crea una page", "nueva pantalla", "componente", "implementá este Figma", "replicá esta imagen", "pixel perfect", "maqueta", "formulario", "modal", "dashboard", "create a page", "new screen", "implement this design", "build the UI".
---

# UI builder

## Objective

Goal: from the design to a verified implementation with no drift. The project's design-system skill or docs (if any) are authoritative for tokens, spacing and typography; this skill is the workflow. On conflict, the design system wins.

## Workflow

Never skip steps 0, 2 or 6.

0. **Read the rules**: the project's design-system skill/docs, `AGENTS.md`, the architecture skill if present (`feature-architecture` or `frontend-ports-adapters`).
1. **Parse the design**: regions, visual hierarchy, states (loading, empty, error), breakpoints.
2. **Map to existing tokens**: every color, spacing and type size must be an existing token or scale step. Never invent a token, never use a literal hex or an arbitrary value.
3. **Choose the surface, then the component.** Surface first: one quick task -> single modal; 2-4 steps -> one dialog with steps inside; many steps or complex data (tables, long lists) -> a page; context-heavy -> a side panel (sheet on small screens). Never a modal on top of a modal. Component order: component library first -> composition of its primitives -> shared component -> feature-local component. If torn between the last two, make it shared.
4. **Scaffold** following the project's architecture (where the page, hooks, schemas and API calls go).
5. **Implement**: pages and components stay presentational; data fetching, mutations and navigation live in hooks. Named exports, one component per file, no `any`. Remote data goes through the project's query client (no hand-rolled caches); keep state local unless several screens need it; prefer composition or a feature hook over deep prop drilling; hooks return small typed APIs named by intent (`useCheckoutForm`). For effects follow `react-component-validator`.
6. **Verify**: every interactive element is keyboard reachable with a visible focus; labels, names and roles are right; color is never the only state signal; touch targets meet the project minimum; works at the smallest and largest supported widths; dark mode if the project has it; loading, empty and error states exist.
7. **Lint and typecheck** with the project's commands; no warnings.

Then run `ui-review` on the result if the user asks for an opinion.
