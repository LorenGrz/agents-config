---
name: database-persistence-patterns
description: Use this skill when implementing or reviewing NestJS persistence with repositories, migrations, transactions, seeds, local Docker-backed databases, and clean separation between domain logic and storage concerns.
paths:
  - "**/*.entity.ts"
  - "**/*.repository.ts"
  - "**/*.repository.spec.ts"
  - "**/migrations/**"
metadata:
  version: "0.1.0"
  owner: "typescript-fullstack"
  stack:
    - typescript
    - nestjs
    - database
  focus:
    - persistence
    - repositories
    - migrations
    - transactions
  triggers:
    - database
    - repository
    - migration
    - transaction
    - seed
---

# Database Persistence Patterns

## Objective

Implement persistence code that protects domain boundaries, keeps schema changes reproducible, and works reliably with local development databases.

## Repository Rules

- Repositories persist and retrieve data; they do not own business decisions.
- Define repository ports/interfaces in the application or domain boundary when using clean architecture.
- Implement database-specific logic in infrastructure adapters.
- Map between persistence records and domain objects explicitly.
- Do not leak ORM entities into controllers or domain models.

## Migrations And Seeds

- Use migrations for schema changes; do not rely on implicit production synchronization.
- Keep seeds deterministic and safe for development/test environments.
- Do not modify historical migrations unless the project explicitly allows it and the migration has not been shared.

## Transactions

- Use transactions for multi-write operations that must succeed or fail together.
- Keep transaction boundaries in application services or unit-of-work abstractions, not controllers.
- Avoid long-running external calls inside database transactions.

## Local Validation

- Use `run-docker-environment` when a local database is declared with Docker Compose.
- Verify migrations apply against a clean local database when practical.
- Run repository and integration tests when present.
