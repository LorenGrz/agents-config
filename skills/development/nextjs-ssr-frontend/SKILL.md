---
name: nextjs-ssr-frontend
description: Use this skill when building, reviewing, or refactoring a Next.js TypeScript frontend with SSR, App Router, server components, route handlers, caching, metadata, and production-safe frontend architecture.
metadata:
  version: "0.1.0"
  owner: "typescript-fullstack"
  stack:
    - typescript
    - nextjs
    - react
  focus:
    - ssr
    - app router
    - server components
    - frontend architecture
  triggers:
    - Next.js
    - SSR
    - App Router
    - server component
    - route handler
---

# Next.js SSR Frontend

## Objective

Build Next.js applications that use server rendering deliberately, keep client JavaScript small, and preserve type-safe integration with backend APIs.

## Core Rules

- Prefer the App Router when the project already uses it or when creating new Next.js code.
- Keep components server-side by default; add `"use client"` only for state, browser APIs, event handlers, or client-only libraries.
- Fetch data in server components, route handlers, or server actions when that keeps secrets and backend access off the client.
- Keep route handlers thin; move reusable business or integration logic into services.
- Define loading and error states for async routes that can suspend or fail.
- Use `metadata` or `generateMetadata` for SEO-relevant pages.
- Avoid reading secrets in client components or bundling server-only code into client paths.

## Data Fetching And Caching

- Choose cache behavior intentionally: static, revalidated, dynamic, or no-store.
- Do not add `cache: "no-store"` by default; use it when data is user-specific, sensitive, or must be fresh.
- Co-locate route-specific data loading with the route unless the logic is shared.
- Normalize backend error responses before rendering UI states.

## Component Boundaries

- Use server components for layout, data loading, and composition.
- Use client components for interactive islands.
- Pass serializable props across the server/client boundary.
- Do not pass functions, class instances, database records, or non-serializable values from server components to client components.

## Validation

- Run the project test, lint, and typecheck scripts when present.
- For UI changes, verify desktop and mobile layouts.
- For SSR changes, check for hydration warnings and accidental client-only API usage during server render.
