---
name: ui-review
description: Review pages and components already built - design-system compliance, accessibility, responsive behavior, dark mode, component-library use, architecture and React/TypeScript practices - returning prioritized findings with concrete fixes. Use for "revisá", "auditá", "está bien?", "feedback", "qué mejorarías", "responsive check", "review this UI", "audit", "best practices".
---

# UI review

Read the changed files and the project's design-system skill/docs, then report. Do not edit unless asked.

## Check

- **Tokens and scale**: no literal colors, no arbitrary spacing or type sizes, no stale or invented tokens.
- **Component reuse**: library components used where they exist; no re-implementation of buttons, inputs or modals; shared vs feature-local placement is right.
- **Surfaces**: modal vs wizard vs page vs panel fits the task; no modal over a modal.
- **Accessibility**: keyboard path complete, visible focus, names/roles/labels, contrast through tokens, color not the only signal, target sizes, status messages announced, headings in order, images with alt.
- **Responsive**: smallest and largest supported widths, no horizontal scroll, touch targets.
- **Dark mode** (if supported): every colored element has its dark variant.
- **States**: loading, empty, error and disabled are handled.
- **Architecture and code**: presentational components, logic in hooks, project boundaries respected, no `any`, no unnecessary effects, stable keys, named exports.

## Output

Findings grouped as BLOCKER / SHOULD FIX / NICE TO HAVE, each as `[file:line] problem -> concrete fix`. Finish with what is already good (two or three lines) and the checks run, or not run.
