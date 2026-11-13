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

- Server Components by default. Add `'use client'` only on the interactive leaf
  (the button, the form, the thing with state/handlers) — not on a whole page.
- Fetch data in Server Components or route handlers, not in a client-side
  `useEffect`. Mutations go through Server Actions, validated with `zod` before
  touching anything, then `revalidatePath`/`revalidateTag` (or `updateTag` on
  Cache Components) to refresh stale data.
- Never import server-only code (db clients, secrets, server actions' internals)
  into a client component. Mark server-only modules with the `server-only`
  package so a wrong import fails the build instead of leaking at runtime.
- Secrets live only in server env vars. `NEXT_PUBLIC_*` is for values that are
  genuinely safe to ship to the browser — never a key or token.
- Each route segment that can fail or take time gets its own `loading.tsx` and
  `error.tsx`; don't spinner-and-catch by hand inside the page.
- Use the Metadata API (`generateMetadata` / the `metadata` export) for
  title/description/OG tags, not manual `<head>` manipulation.
- Inside a `'use client'` component, `useEffect` follows the same doctrine as
  `react.md`: only to synchronize with something outside React (browser APIs,
  subscriptions, third-party widgets), always with cleanup when it subscribes.

For App Router architecture and caching strategy, use `nextjs-ssr-frontend`.
