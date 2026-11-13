## Next.js conventions

Zero-useEffect doctrine, adapted for the App Router and enforced by `eslint.config.mjs` (`react-hooks/set-state-in-effect`, `react-you-might-not-need-an-effect/*`):

- Data fetching happens in Server Components or route handlers, not a client-side `useEffect`.
- Mutations go through Server Actions, validated (e.g. with `zod`) before touching anything, then `revalidatePath`/`revalidateTag` to refresh stale data.
- `'use client'` only at the leaves of the tree (the interactive component itself), never on a whole route segment.
- `useEffect` in a Client Component is only for syncing with something outside React (subscriptions, browser APIs) - never to set state from props or other state.

Rendering and data, reviewed against `nextjs-ssr-frontend`:

- Choose cache behavior intentionally (static, revalidated, dynamic, `no-store`); don't default to `no-store`.
- Never import server-only code (db clients, secrets) into a client component; mark server-only modules with the `server-only` package.
- Each route segment that can fail or take time gets its own `loading.tsx` and `error.tsx`.
- Use the Metadata API (`generateMetadata` / the `metadata` export) for title/description/OG tags, not manual `<head>` manipulation.
- Secrets live only in server env vars; `NEXT_PUBLIC_*` is for values genuinely safe to ship to the browser.

Tests: Vitest + React Testing Library for client components; colocated as `*.test.tsx`.
