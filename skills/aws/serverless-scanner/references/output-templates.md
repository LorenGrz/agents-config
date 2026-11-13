# Output Templates

Use these templates verbatim as the structure for every Serverless Scanner Report. Fill in the bracketed placeholders. Do not skip sections.

---

## Full Report Template

```markdown
# Serverless Scanner Report

## Executive Summary

[2–4 sentences. Jargon-free. Answer: what does this product do, what is the single best serverless opportunity, what is the expected benefit, and what is the recommended first step. Write as if presenting to a CEO who has 30 seconds.]

---

## Product Understanding

**Product type:** [SaaS / marketplace / internal tool / ecommerce / etc.]
**Current stack (inferred/confirmed):** [Language, framework, hosting]
**Confidence:** [High / Medium / Low] — [one sentence explaining why]

[2–3 sentences describing what the product does and how it currently works, based on the input provided.]

---

## Detected Workflows

### User-facing workflows
- [Workflow name] — [one-line description] *(confidence: High/Medium/Low)*
- ...

### Backend / async workflows
- [Workflow name] — [one-line description] *(confidence: High/Medium/Low)*
- ...

> **Note:** Workflows marked Medium or Low confidence are inferred. Confirm with the team before scoring.

---

## Top Serverless Opportunities

| Workflow | Serverless Fit | Savings Potential | Complexity | Operational Risk | Confidence | Composite | AWS Target | Reason |
|----------|:--------------:|:-----------------:|:----------:|:----------------:|:----------:|:---------:|-----------|--------|
| [Workflow 1] | [1–5] | [1–5] | [1–5] | [1–5] | [1–5] | **[X.XX]** | [AWS service] | [One sentence] |
| [Workflow 2] | [1–5] | [1–5] | [1–5] | [1–5] | [1–5] | **[X.XX]** | [AWS service] | [One sentence] |
| [Workflow 3] | [1–5] | [1–5] | [1–5] | [1–5] | [1–5] | **[X.XX]** | [AWS service] | [One sentence] |

*Scoring formula: (Fit × 0.30) + (Savings × 0.20) + (Complexity × 0.25) + (Risk × 0.15) + (Confidence × 0.10)*

---

## Recommended First Migration

**Workflow:** [Name]
**AWS target:** [Service(s)]
**Why this one first:** [3–5 sentences. Cover: why it scores highest, why it is low risk to start, what the team learns from it, and what it unlocks for future migrations.]

---

## Do Not Migrate Yet

| Workflow | Reason | Revisit when |
|----------|--------|--------------|
| [Workflow A] | [Why it is a poor candidate now] | [Condition that would change the recommendation] |
| [Workflow B] | [Why it is a poor candidate now] | [Condition that would change the recommendation] |

---

## AWS Target Architecture

For the recommended top opportunities:

| Workflow | Trigger | Lambda / Service | Downstream | Notes |
|----------|---------|-----------------|-----------|-------|
| [Workflow 1] | [Event source] | [Service] | [Output destination] | [Any caveat] |
| [Workflow 2] | [Event source] | [Service] | [Output destination] | [Any caveat] |
| [Workflow 3] | [Event source] | [Service] | [Output destination] | [Any caveat] |

---

## 30-Day Migration Plan

### Week 1–2: Foundation
- [ ] [Concrete task — e.g., "Create IAM role for Lambda with least-privilege policy"]
- [ ] [Concrete task — e.g., "Set up the target AWS service (e.g., EventBridge Scheduler)"]
- [ ] [Concrete task — e.g., "Extract workflow logic into a standalone function locally"]
- [ ] [Concrete task — e.g., "Write unit tests for the extracted function"]

### Week 3: Deploy and validate
- [ ] [Concrete task — e.g., "Deploy Lambda using SAM or CDK to staging environment"]
- [ ] [Concrete task — e.g., "Run shadow traffic: trigger both old and new paths, compare outputs"]
- [ ] [Concrete task — e.g., "Set up CloudWatch alarm for Lambda error rate > 1%"]

### Week 4: Cut over and observe
- [ ] [Concrete task — e.g., "Disable old cron job / scheduled task on the server"]
- [ ] [Concrete task — e.g., "Monitor Lambda invocations and error rate for 5 business days"]
- [ ] [Concrete task — e.g., "Decommission the server process if metrics are clean"]
- [ ] [Concrete task — e.g., "Document the pattern for the next migration"]

---

## Open Questions

Only list questions that are **blocking** — i.e., the answer would materially change the recommendation.

1. [Question] — *needed to [confirm/score/design X]*
2. [Question] — *needed to [confirm/score/design X]*

> If no critical information is missing, write: *No blocking questions. Proceed with the plan above.*
```

---

## Section-Only Templates

### Executive Summary (standalone)

```markdown
## Executive Summary

[Product] currently runs [workflow] on a dedicated server. Moving it to AWS Lambda + [service] would eliminate idle server costs and remove the need for manual maintenance. Based on the information provided, [workflow] is the strongest first candidate — it is self-contained, low-risk, and can be migrated in under 30 days. Expected outcome: [specific benefit, e.g., "~$X/month savings" or "eliminate 4h/week of manual ops"].
```

### Opportunity Table (standalone)

```markdown
| Workflow | Serverless Fit | Savings Potential | Complexity | Operational Risk | Confidence | Composite | AWS Target | Reason |
|----------|:--------------:|:-----------------:|:----------:|:----------------:|:----------:|:---------:|-----------|--------|
| | | | | | | | | |
```

### Recommended First Migration (standalone)

```markdown
## Recommended First Migration

**Workflow:** 
**AWS target:** 
**Why this one first:** 
**Estimated effort:** [hours / days]
**Estimated savings:** [$/month or ops hours saved/week]
```

### Do Not Migrate Yet (standalone)

```markdown
## Do Not Migrate Yet

These workflows are poor candidates for the first migration. Do not recommend them as starting points.

| Workflow | Reason | Revisit when |
|----------|--------|--------------|
| | | |
```

### 30-Day Plan (standalone)

```markdown
## 30-Day Migration Plan

### Week 1–2: Foundation
- [ ] 
- [ ] 

### Week 3: Deploy and validate
- [ ] 
- [ ] 

### Week 4: Cut over and observe
- [ ] 
- [ ] 
```
