---
paths:
  - "**/*.kt"
  - "**/*.controller.ts"
  - "**/*.service.ts"
  - "**/*.resolver.ts"
  - "**/*.guard.ts"
  - "**/*.middleware.ts"
  - "**/*.dto.ts"
  - "**/security/**"
  - "**/auth/**"
  - "**/*ecurityConfig*"
  - "**/*.config.ts"
---

# Security

Every item below is a real defect class from a full-stack review, and blocking.

## Authorization — bind to the authenticated principal, not to a request param

- Never take `userId` / `ownerId` / `accountId` from a query param, path, or request body to decide *whose* data to read or write. Derive the acting identity from the authenticated principal (`Authentication` / `req.user` / JWT `sub`).
  - Anti-pattern: a "create reservation" endpoint that reserves for `body.userId`; a "my reservations" / "get user" endpoint keyed off a client-supplied id — any authenticated caller then acts as, or reads, anyone.
- Every object-level read/write of a user-owned resource checks ownership (or an explicit role): a check like BookLibre's `PUT /api/usuarios/{id}` (`isAdmin || isOwner`) goes on the GET and every sibling endpoint too.
- Role change is not self-service. A profile update must not let the caller widen its own role/permissions.
- Authorization rules that overlap: order from most specific to least, and verify a broad `permitAll`/`*` matcher earlier in the chain doesn't shadow a later `hasRole` (first match wins).

## Auth, tokens, sessions

- Secrets fail fast: refuse to boot if a JWT/signing secret is missing or equals a placeholder. Never ship a real default (`${JWT_SECRET:some-literal}` in a committed file is a forgeable-token bug).
- Issue the token in one place: HttpOnly cookie OR response body, never both (a body copy defeats HttpOnly against XSS).
- Distinguish token types on use: a refresh token must be rejected at access-token endpoints and vice-versa (check a `type` claim).
- Rotate refresh tokens on use and support revocation (denylist / version column); otherwise a leaked long-lived refresh token is unrevocable account access.
- Rate-limit / back off `login`, `register`, token, and refresh endpoints.
- Generic auth failures ("usuario o contraseña incorrectos"); don't confirm which was wrong, and avoid account-existence oracles on register where feasible.
- Hash passwords with bcrypt/argon2. No plaintext-comparison method anywhere in the domain, even unused.

## CSRF, CORS, cookies

- Cookie auth + `SameSite=None` + CSRF disabled = CSRF on every mutation. Fix with same-site deployment + `SameSite=Lax`, or a CSRF token / required custom header, or move mutations to an `Authorization` header. CORS is not a CSRF control.
- CORS: exact origin allowlist (`allowedOrigins`), never a wildcard or broad pattern, especially with `allowCredentials=true`. Don't use `allowedOriginPatterns` unless a pattern is truly required.

## Input validation

- Validate every request body/param at the edge (`@Valid` / class-validator / zod) before it reaches a service.
- Persisted user-supplied URLs/HTML (`imagenUrl`, bios) are validated (scheme allowlist, host checks) and escaped on render — otherwise stored XSS / SSRF.
- Parameterised queries only; never string-build SQL/JPQL/Mongo filters from input.

## Config & error handling

- No secrets or real credentials in committed files (even local profiles). `.env` gitignored and never committed.
- Production error responses are generic. Turn off `server.error.include-message: always`; a catch-all handler logs the detail server-side and returns a fixed message + status — never `error.message` to the client.
- Disable GraphQL introspection and set query depth/complexity limits in production.

For a full pass use the `auth-security-basics` skill; for LLM-facing input, `prompt-injection-defense`.
