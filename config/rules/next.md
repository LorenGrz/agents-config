---
paths:
  - "**/app/**/*.tsx"
  - "**/app/**/*.ts"
  - "**/next.config.*"
  - "**/middleware.ts"
  - "**/proxy.ts"
---

# Next.js (App Router)

## Server and client boundaries

- Server Components by default. `'use client'` goes only on the interactive leaf (the part with state or
  handlers), never on a whole page.
- Fetch data in Server Components or route handlers, not in a client-side `useEffect`. Mutations go through
  Server Actions, validated with `zod` first, then `revalidatePath`/`revalidateTag` (or `updateTag` on
  Cache Components).
- Never import server-only code (db clients, secrets, server actions' internals) into a client component.
  Mark server-only modules with the `server-only` package so a wrong import fails the build.
- Secrets live only in server env vars. `NEXT_PUBLIC_*` only for values safe to ship to the browser, never
  a key or token.
- Each route segment that can fail or take time gets its own `loading.tsx` and `error.tsx`; no hand-made
  spinner-and-catch inside the page.
- Title/description/OG tags through the Metadata API (`generateMetadata` / the `metadata` export), not
  manual `<head>` manipulation.
- In a `'use client'` component, `useEffect` follows `react.md`: only to synchronize with something outside
  React (browser APIs, subscriptions, third-party widgets), with cleanup when it subscribes.

For App Router architecture and caching strategy, use `nextjs-ssr-frontend`.
