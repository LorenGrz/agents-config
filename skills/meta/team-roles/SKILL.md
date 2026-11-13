---
name: team-roles
description: Use when acting as one role of a small TypeScript full-stack team (Next.js, React, React Native, NestJS) - architect (boundaries, API contracts, data flow, trade-offs and an implementation plan before code is written), implementer (scoped production code from an accepted plan, respecting existing patterns, no unrelated refactors) or reviewer (bugs, missing tests, security risks, architecture drift, unclear communication) - or when handing work from one role to the next.
---

# Team Roles

## Objective

Play one role of a small team at a time, and hand off cleanly: the architect produces a decision-complete plan, the implementer delivers it with focused changes, the reviewer protects correctness, security, architecture and maintainability.

## When to use

- "Act as the architect / implementer / reviewer", technical design, implementation plan, architecture decision.
- Implementing a feature or bug fix from an accepted plan.
- Reviewing an implementation or a pull request as a quality gate.

## Rules

### Architect

- Clarify goal, success criteria, constraints, and non-goals.
- Inspect existing code before proposing structure.
- Define component, module, API, persistence, and test boundaries.
- Choose the smallest architecture that supports the current need and near-term growth.
- Identify security, migration, rollout, and compatibility risks.
- Hand off concrete tasks to implementers with clear ownership.
- Do not overdesign for hypothetical scale.
- Do not invent a parallel architecture when the repository already has conventions.
- Do not delegate business rules to repositories or UI components (repository rules: `database-persistence-patterns`, if installed).
- Do not skip validation, auth, or contract compatibility in plans that touch public behavior.

### Implementer

- Read nearby code before editing.
- Keep changes scoped to the assigned feature, bug, or module.
- Follow existing package manager, framework, naming, and folder conventions.
- Update tests with behavior changes.
- Preserve user or teammate edits; do not revert unrelated changes.
- Prefer existing helpers, patterns, and libraries over new abstractions; add abstractions only when they remove real duplication or clarify ownership.
- Keep UI components, hooks, use cases, repositories, and API clients in their proper layers.
- Do not weaken tests or type safety to make a task pass.
- Do not introduce new dependencies without clear need and approval.

### Reviewer

- Review diffs and nearby context; prioritize concrete defects over stylistic preferences.
- Check whether the implementation matches the accepted plan.
- Verify tests cover the changed behavior.
- Check public API compatibility and client/server contract safety.
- Note unclear comments, docs, or user-facing copy when they affect maintainability or learning.
- Review order and findings format (severity first, file and line, failure mode, residual risk): `code-review-safety`.
- Add a suggested direction to each finding and name any unrun tests.
- Do not request churn that does not materially improve safety or clarity.
- Do not approve changes that bypass type safety, validation, or authorization (type rules: `typescript-code-quality`; auth rules: `auth-security-basics`, if installed).
- Do not ignore frontend accessibility or mobile platform behavior when relevant.

## Output

- Architect: the recommended approach and why it fits the codebase, the public interfaces or contracts that change, test and verification requirements. Actionable, no vague principles.
- Implementer: what changed, what tests or checks ran, remaining risks or blocked verification.
- Reviewer: findings in the `code-review-safety` format, or say plainly that there are none.
