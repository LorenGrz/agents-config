# Scoring Model

Use this rubric to score each serverless migration candidate. Score every dimension, compute the composite, and assign a priority tier.

## Dimensions

| Dimension | Definition | Score 1 | Score 3 | Score 5 |
|-----------|-----------|---------|---------|---------|
| **Serverless Fit** | How well the workflow matches serverless patterns (stateless, event-driven, bursty, async, short-lived) | Stateful, always-on, long-running, real-time bidirectional | Mixed: some stateless but has persistent connections or shared in-memory state | Fully stateless, event-triggered, runs to completion, no persistent connections |
| **Savings Potential** | Expected reduction in infrastructure cost or operational overhead | Low traffic, already cheap to run; marginal savings | Moderate traffic spikes or significant idle time; meaningful savings likely | High idle time, bursty load, or per-invocation pricing clearly wins vs. always-on server |
| **Complexity** | How hard the migration is (inverse: high score = low complexity) | Requires deep refactor, stateful session handling, or complex data migration | Moderate refactor; some coupling to existing services | Self-contained function, minimal external dependencies, easy to extract |
| **Operational Risk** | Risk of degrading the product if migration goes wrong (inverse: high score = low risk) | Core user-facing flow; outage = major business impact | Secondary flow; degraded experience if it fails but not catastrophic | Background/async; users unaffected if it fails or is slow |
| **Confidence** | How certain the scoring is given available information | Inferred from vague description; product type unclear | Partial context (architecture described but not confirmed) | Confirmed from diagram, code, or explicit description |

## Composite Score Formula

```
Composite = (Serverless Fit × 0.30) + (Savings Potential × 0.20) + (Complexity × 0.25) + (Operational Risk × 0.15) + (Confidence × 0.10)
```

| Composite Score | Priority Tier |
|----------------|---------------|
| 4.0 – 5.0 | **High** — recommend immediately |
| 2.5 – 3.9 | **Medium** — recommend with caveats |
| < 2.5 | **Low** — do not migrate yet |

## Worked Examples

### High-Score Workflows (strong candidates)

| Workflow | Serverless Fit | Savings | Complexity | Op. Risk | Confidence | Composite | Tier |
|----------|---------------|---------|-----------|---------|-----------|-----------|------|
| Nightly report email to users | 5 | 4 | 5 | 5 | 4 | **4.60** | High |
| PDF generation on demand | 5 | 4 | 4 | 4 | 5 | **4.35** | High |
| Image resize on upload | 5 | 5 | 5 | 5 | 5 | **5.00** | High |
| Webhook receiver (Stripe, GitHub) | 5 | 4 | 4 | 4 | 4 | **4.30** | High |
| Scheduled database cleanup job | 5 | 3 | 5 | 4 | 4 | **4.30** | High |

### Low-Score Workflows (poor candidates)

| Workflow | Serverless Fit | Savings | Complexity | Op. Risk | Confidence | Composite | Tier |
|----------|---------------|---------|-----------|---------|-----------|-----------|------|
| Primary REST API (checkout, orders) | 2 | 2 | 2 | 1 | 5 | **1.90** | Low |
| WebSocket live chat or notifications | 1 | 2 | 1 | 2 | 5 | **1.45** | Low |
| Core auth / session management | 2 | 2 | 2 | 1 | 5 | **1.90** | Low |
| Heavy ML training job (hours-long) | 1 | 2 | 1 | 3 | 4 | **1.65** | Low |
| High-throughput streaming ingestion | 2 | 3 | 2 | 2 | 4 | **2.25** | Low |

## Scoring Notes

- **Always score Confidence honestly.** A Medium-confidence High workflow is not the same as a confirmed High. Flag it in the output.
- **Complexity scores the migration effort, not the current code complexity.** A complex feature can still be easy to extract if it is already isolated.
- **Operational Risk is about blast radius if the migration fails**, not about how hard it is to build. A background job that fails silently is low risk even if it is important.
- **Do not inflate scores to justify a recommendation.** If a workflow scores Low, say so and explain why it should wait.
