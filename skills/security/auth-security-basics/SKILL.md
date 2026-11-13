---
name: auth-security-basics
description: Use this skill when implementing or reviewing authentication, authorization, token or session handling, secrets, input validation, and secure TypeScript full-stack defaults across NestJS, Next.js, React, and React Native.
metadata:
  version: "0.1.0"
  owner: "typescript-fullstack"
  stack:
    - typescript
    - nestjs
    - nextjs
    - react
    - react-native
  focus:
    - authentication
    - authorization
    - secrets
    - validation
  triggers:
    - auth
    - login
    - token
    - session
    - authorization
    - security
---

# Auth Security Basics

## Objective

Implement authentication and authorization with secure defaults and clear boundaries between client, server, and storage.

## Authentication Rules

- Prefer existing project auth providers and session patterns.
- Keep secrets and private keys server-side only.
- Do not store access tokens in insecure browser or mobile storage when a safer project-approved option exists.
- Use HTTPS-aware cookie settings, CSRF protections, or bearer-token protections according to the project's auth model.
- Validate login, refresh, logout, and expired-session flows.

## Authorization Rules

- Enforce authorization on the server; client-side checks are UX only.
- Put role, ownership, and permission checks near use cases or guards according to the backend architecture.
- Do not trust user IDs, roles, tenant IDs, or permissions sent by the client.
- Return safe error responses for forbidden and unauthenticated states.

## Secrets And Input

- Read secrets from environment or secret managers, never hardcode them.
- Validate environment variables at startup when the project has a validation pattern.
- Validate all external input before domain logic.
- Avoid logging tokens, passwords, personal data, or sensitive headers.

## Validation

- Add tests for unauthenticated, forbidden, expired, and valid access paths.
- Review frontend storage and backend logs for accidental secret exposure.
