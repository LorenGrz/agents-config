---
name: serverless-scanner
version: 1
description: >-
  Use when analyzing an application, screenshots, workflows, architecture,
  product description, or migration plan to identify high-ROI partial AWS
  serverless migration opportunities, score candidates, and produce executive
  and technical recommendations.
---

## When to use this skill

Activate when the user provides any of the following:
- Screenshots of a product or UI
- Workflow or architecture diagrams
- Product description, README, or feature list
- Current stack description (languages, frameworks, infrastructure)
- Cloud cost concerns or operational pain points
- A migration plan or RFP asking about serverless

This skill focuses on **partial migration** — identifying specific workflows inside an existing product that are strong serverless candidates. It does not recommend full rewrites.

## When to ask for missing context

Ask only if the input is too vague to infer the product type. One targeted question maximum:

> "Can you describe what the product does and roughly how it's currently hosted?"

If any product context exists, proceed with inferred information and flag confidence levels in the output.

## Skill workflow

Follow these steps in order. Load the referenced file when indicated.

| Step | Action | Reference |
|------|--------|-----------|
| 1 | Identify product type (SaaS, marketplace, internal tool, etc.) | — |
| 2 | Extract or infer user-facing workflows from the input | — |
| 3 | Extract or infer backend/async workflows | — |
| 4 | Identify good serverless candidates | → `references/aws-service-mapping.md` |
| 5 | Identify workflows that should NOT be migrated yet | — |
| 6 | Score each candidate | → `references/scoring-model.md` |
| 7 | Select top 3 opportunities by composite score | → `references/scoring-model.md` |
| 8 | Select the single best first migration | — |
| 9 | Map recommendations to AWS services | → `references/aws-service-mapping.md` |
| 10 | Generate executive summary | → `references/output-templates.md` |
| 11 | Generate technical migration plan | → `references/output-templates.md` |
| 12 | Generate 30-day action plan | → `references/output-templates.md` |
| 13 | List only critical open questions | — |

## Reference files

| File | Load when |
|------|-----------|
| `references/scoring-model.md` | Scoring candidates (steps 6–7) |
| `references/aws-service-mapping.md` | Mapping workflows to services (steps 4, 9) |
| `references/output-templates.md` | Generating the final report (steps 10–12) |
| `references/demo-scenarios.md` | User requests an example, or to calibrate judgment |

## Behavior rules

1. **Never recommend serverless for everything.** Always include a "Do Not Migrate Yet" section.
2. **Prefer isolated, stateless, event-driven, bursty, async, or scheduled workflows.** These are the strongest candidates.
3. **Be skeptical of core transactional systems** (primary CRUD APIs, checkout, auth flows, real-time bidirectional features). Flag these as risky.
4. **Use confidence levels** (`High`, `Medium`, `Low`) whenever you infer workflows from incomplete input.
5. **For screenshots**, explicitly separate observed facts (what is visible) from inferred workflows (what probably happens behind the scenes).
6. **Make outputs useful for both audiences.** The Executive Summary must be jargon-free. The technical plan must be specific enough for an engineer to act on.
7. **Keep recommendations actionable.** Name specific AWS services, not generic categories.
8. **Do not over-engineer.** Recommend the simplest serverless path that solves the problem.
