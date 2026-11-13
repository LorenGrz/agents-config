---
name: component-a11y-guard
description: Accessibility floor and change-completeness gate for a reusable UI component library. Invoke whenever a component is created, edited, restyled or reviewed under src/components, or when asked for "revisá la accesibilidad del componente", "component a11y", "WCAG del componente". Maps the WCAG 2.2 criteria a component author controls to the library's tokens and patterns, then enforces the "complete the change" checklist (exports, stories/docs, prop docs, build, typecheck, lint).
---

# Component a11y + completeness guard

## Objective

Run it when you change what a component renders or exports. Reuse the project's existing tokens, focus-ring class and primitives (a headless library such as Radix supplies name/role/keyboard; do not strip what it provides). A missing token is a design-token issue, not a local workaround.

## Rules

### Accessibility floor (what the component author controls)

| WCAG | Rule |
|---|---|
| 1.4.3 / 1.4.6 | Text uses audited text tokens, never a fill token; no off-palette colors or hex |
| 1.4.11 | Interactive borders, focus indicators and state graphics reach 3:1 |
| 1.4.1 | Color is never the only signal: pair with icon or text |
| 1.4.13 | Hover/focus content is dismissable, hoverable and persistent: use the Tooltip/Popover primitives |
| 2.1.1 / 2.1.2 / 2.4.3 | Fully keyboard operable, only modals trap focus, DOM order is logical |
| 2.4.7 / 2.4.11 | Visible focus on every interactive element using the project's canonical ring; `outline-none` without a replacement is a blocker; sticky chrome must not hide a focused element |
| 2.5.3 | Visible label is contained in the accessible name; icon-only controls require `aria-label` |
| 2.5.8 / 2.5.5 | Target size: the project's mobile floor (44px) with the documented dense-grid exception |
| 3.2.1 / 3.2.2 | Focus or a value change alone never navigates or submits: emit events, let the consumer decide |
| 4.1.2 | Correct role, name and state exposed; decorative icons `aria-hidden`; form controls wired through the Field primitives |
| 4.1.3 | Component-local status messages use `role="status"`/`role="alert"` with polite live regions |
| 1.3.1 / 1.3.5 | Structure is real (labels, `th`/`td`, error association); pass through `autoComplete`/`type` |
| 2.3.3 | Non-essential motion respects `prefers-reduced-motion`; use the project's animation tokens |

Not the library's job (do not "fix" them in a component): skip links, page titles, language, focus on route change, app-wide live regions, timeouts, page reflow.

### Complete the change

- [ ] Folder shape (`<Name>/{<Name>.tsx, stories, index.ts}`) and re-export from the package entry, including the `${Name}Props` type
- [ ] JSDoc on every public prop, with `@default` where applicable
- [ ] Generated docs refreshed and committed if the project generates them
- [ ] Build passes, including any variant-presence or bundle audit; typecheck and lint (with a11y rules) clean
- [ ] Conventional Commit (`feat!:` for breaking changes)
