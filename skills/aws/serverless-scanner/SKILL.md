---
name: serverless-scanner
version: 1
description: >-
  Use when analyzing an application, screenshots, workflows, architecture,
  product description, or migration plan to identify high-ROI partial AWS
  serverless migration opportunities, score candidates, and produce executive
  and technical recommendations.
---

## Objective

Identify high-ROI **partial** AWS serverless migration opportunities inside an existing product, score them, and produce executive and technical recommendations. Never a full rewrite.

## When to use

The user provides screenshots, workflow or architecture diagrams, a product description, README or feature list, the current stack, cloud cost or operational pain points, or a migration plan or RFP asking about serverless.

Ask only if the input is too vague to infer the product type, and one targeted question maximum:

> "Can you describe what the product does and roughly how it's currently hosted?"

If any product context exists, proceed with inferred information and flag confidence levels in the output.

## Workflow

Follow these steps in order.

1. Identify product type (SaaS, marketplace, internal tool, etc.).
2. Extract or infer user-facing workflows from the input.
3. Extract or infer backend/async workflows.
4. Identify good serverless candidates.
5. Identify workflows that should NOT be migrated yet.
6. Score each candidate.
7. Select top 3 opportunities by composite score.
8. Select the single best first migration.
9. Map recommendations to AWS services.
10. Generate executive summary.
11. Generate technical migration plan.
12. Generate 30-day action plan.
13. List only critical open questions.

## Rules

1. **Never recommend serverless for everything.** Always include a "Do Not Migrate Yet" section.
2. **Prefer isolated, stateless, event-driven, bursty, async, or scheduled workflows.** These are the strongest candidates.
3. **Be skeptical of core transactional systems** (primary CRUD APIs, checkout, auth flows, real-time bidirectional features). Flag these as risky.
4. **Use confidence levels** (`High`, `Medium`, `Low`) whenever you infer workflows from incomplete input.
5. **For screenshots**, explicitly separate observed facts (what is visible) from inferred workflows (what probably happens behind the scenes).
6. **Make outputs useful for both audiences.** The Executive Summary must be jargon-free. The technical plan must be specific enough for an engineer to act on.
7. **Keep recommendations actionable.** Name specific AWS services, not generic categories.
8. **Do not over-engineer.** Recommend the simplest serverless path that solves the problem.

## Reference

| File | Load when |
|------|-----------|
| `references/aws-service-mapping.md` | Mapping workflows to services (steps 4, 9) |
| `references/scoring-model.md` | Scoring candidates (steps 6–7) |
| `references/output-templates.md` | Generating the final report (steps 10–12) |
| `references/demo-scenarios.md` | User requests an example, or to calibrate judgment |
