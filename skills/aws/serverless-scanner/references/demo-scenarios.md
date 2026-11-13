# Demo Scenarios

Six worked examples for calibration and demonstration. Each follows the full Serverless Scanner output format.

---

## Scenario 1: Gym Booking SaaS

**Product summary:** A SaaS platform for gym chains. Members book classes, coaches manage schedules, and gym owners see revenue dashboards. Hosted on a single Rails monolith on EC2.

### Top 3 Opportunities

| Workflow | Serverless Fit | Savings | Complexity | Op. Risk | Confidence | Composite | AWS Target | Reason |
|----------|:--------------:|:-------:|:----------:|:--------:|:----------:|:---------:|-----------|--------|
| Booking confirmation emails | 5 | 4 | 5 | 5 | 4 | **4.60** | Lambda + SES | Pure async, zero user-facing risk, already decoupled |
| Daily class reminder notifications | 5 | 4 | 5 | 5 | 5 | **4.75** | EventBridge Scheduler + Lambda + SNS | Perfect cron candidate, no stateful dependencies |
| Monthly revenue PDF report | 5 | 3 | 4 | 5 | 4 | **4.30** | Lambda + S3 + SES | Heavy on EC2 today; runs once/month = pure idle waste |

**Recommended first migration:** Daily class reminder notifications. Already a scheduled background job, zero coupling to the booking flow, fast to extract. Teaches EventBridge Scheduler + Lambda in one migration.

**Do Not Migrate Yet:**
- **Booking API (create/cancel):** Core transactional flow, latency-sensitive. High risk if Lambda cold starts impact UX.
- **Coach schedule management:** Complex stateful CRUD with file uploads. Too many dependencies for a first migration.

---

## Scenario 2: Ecommerce Store

**Product summary:** Mid-size ecommerce store (~2k orders/day). Django app on EC2. Product catalog, cart, checkout, order tracking. AWS S3 for images already.

### Top 3 Opportunities

| Workflow | Serverless Fit | Savings | Complexity | Op. Risk | Confidence | Composite | AWS Target | Reason |
|----------|:--------------:|:-------:|:----------:|:--------:|:----------:|:---------:|-----------|--------|
| Product image resizing on upload | 5 | 5 | 5 | 5 | 5 | **5.00** | S3 Event + Lambda | Textbook Lambda use case; already using S3 |
| Order confirmation + invoice email | 5 | 4 | 5 | 4 | 5 | **4.65** | Lambda + SES | Async, already triggered by order event |
| Nightly inventory sync from supplier | 5 | 4 | 5 | 4 | 4 | **4.55** | EventBridge Scheduler + Lambda | Runs once/night, self-contained, easy to extract |

**Recommended first migration:** Product image resizing. Zero user-facing risk (async post-upload), S3 is already in use, near-zero idle cost with pay-per-invocation, and teaches the S3 → Lambda pattern used in many future migrations.

**Do Not Migrate Yet:**
- **Checkout flow:** Revenue-critical, latency-sensitive, complex transaction logic. Do not touch.
- **Cart / session management:** Stateful; requires external session store before Lambda is viable.

---

## Scenario 3: Marketplace

**Product summary:** Two-sided marketplace connecting freelancers with clients. Node.js + PostgreSQL on a VPS. Payments via Stripe webhooks. Messaging between users.

### Top 3 Opportunities

| Workflow | Serverless Fit | Savings | Complexity | Op. Risk | Confidence | Composite | AWS Target | Reason |
|----------|:--------------:|:-------:|:----------:|:--------:|:----------:|:---------:|-----------|--------|
| Stripe webhook processing | 5 | 3 | 4 | 4 | 5 | **4.30** | API Gateway + Lambda + SQS | Event-driven, idempotent, already isolated in codebase |
| Payout notification emails | 5 | 3 | 5 | 5 | 4 | **4.45** | Lambda + SES | Triggered by payment event, pure async |
| Weekly earnings summary email | 5 | 3 | 5 | 5 | 4 | **4.45** | EventBridge Scheduler + Lambda + SES | Cron pattern, no user-facing risk |

**Recommended first migration:** Stripe webhook processing. Already event-driven, can be extracted without touching the core API, and adding SQS buffering makes it more reliable than the current synchronous handler.

**Do Not Migrate Yet:**
- **User messaging:** Real-time bidirectional; WebSockets on Lambda require careful design and are high-risk for a first migration.
- **Job matching algorithm:** Complex, CPU-intensive, likely stateful. Not a serverless pattern.

---

## Scenario 4: Document Processing Product

**Product summary:** B2B SaaS that ingests contracts (PDFs), extracts key clauses using AI, and produces structured summaries for legal teams. Python + Celery workers on EC2.

### Top 3 Opportunities

| Workflow | Serverless Fit | Savings | Complexity | Op. Risk | Confidence | Composite | AWS Target | Reason |
|----------|:--------------:|:-------:|:----------:|:--------:|:----------:|:---------:|-----------|--------|
| PDF text extraction (OCR) | 5 | 5 | 4 | 4 | 5 | **4.65** | S3 + Lambda + Textract | Async, bursty, pay-per-page beats idle Celery workers |
| AI clause extraction (LLM call) | 5 | 5 | 4 | 4 | 5 | **4.65** | Lambda + Bedrock | Stateless inference call; no persistent compute needed |
| Completed summary email delivery | 5 | 3 | 5 | 5 | 5 | **4.60** | Lambda + SES | Pure async notification, trivial to extract |

**Recommended first migration:** PDF OCR via Textract. The Celery worker currently runs on EC2 24/7 waiting for infrequent uploads. Replacing it with S3 → Lambda → Textract eliminates idle cost and scales automatically to burst. The async Textract callback pattern also sets up the architecture for the LLM step.

**Do Not Migrate Yet:**
- **Document ingestion API (upload endpoint):** User-facing, needs presigned URL refactor first. Do after S3 event pattern is proven.
- **User authentication / session:** Out of scope for serverless migration; use Cognito only if rebuilding auth.

---

## Scenario 5: Internal Admin Tool

**Product summary:** Internal ops tool for a logistics company. Built in Flask, runs on a single EC2 instance. Features: bulk shipment status updates, Excel report exports, automated carrier notifications.

### Top 3 Opportunities

| Workflow | Serverless Fit | Savings | Complexity | Op. Risk | Confidence | Composite | AWS Target | Reason |
|----------|:--------------:|:-------:|:----------:|:--------:|:----------:|:---------:|-----------|--------|
| Excel / CSV report export | 5 | 4 | 4 | 5 | 4 | **4.45** | Lambda + S3 + SES | Triggered on demand, heavy on EC2, easy to isolate |
| Carrier notification emails | 5 | 3 | 5 | 5 | 4 | **4.45** | Lambda + SES | Pure async, no user-facing dependency |
| Daily shipment status sync from carrier API | 5 | 4 | 4 | 4 | 3 | **4.05** | EventBridge Scheduler + Lambda | Cron pattern; confidence Medium because carrier API details unknown |

**Recommended first migration:** Excel/CSV report export. Currently blocks the EC2 instance for minutes per export. Lambda handles it in isolation, stores output in S3, and emails a download link. Internal tool = low blast radius if something goes wrong.

**Do Not Migrate Yet:**
- **Bulk shipment update UI:** Complex form with validation and DB writes. High coupling.
- **Core Flask app / routing:** No benefit to migrating a low-traffic internal tool's web layer.

---

## Scenario 6: Education Platform

**Product summary:** Online learning platform with video courses, quizzes, and certificates. Ruby on Rails + PostgreSQL on Heroku. ~50k students. Video hosted on S3/CloudFront already.

### Top 3 Opportunities

| Workflow | Serverless Fit | Savings | Complexity | Op. Risk | Confidence | Composite | AWS Target | Reason |
|----------|:--------------:|:-------:|:----------:|:--------:|:----------:|:---------:|-----------|--------|
| Certificate PDF generation on course completion | 5 | 4 | 4 | 5 | 5 | **4.65** | Lambda + S3 + SES | Event-driven, async, bursty at cohort end dates |
| Quiz result + progress emails | 5 | 3 | 5 | 5 | 5 | **4.60** | Lambda + SES | Pure notification, zero coupling to quiz logic |
| AI quiz question generation | 5 | 4 | 4 | 4 | 3 | **4.15** | Lambda + Bedrock | Confidence Medium — LLM integration not confirmed |

**Recommended first migration:** Certificate PDF generation. Bursty (spikes at end of cohort), currently runs synchronously blocking the Rails process, and students wait for it. Lambda makes it async: trigger on completion event → generate PDF → store in S3 → email presigned link. Immediate UX improvement and cost savings.

**Do Not Migrate Yet:**
- **Video streaming / playback:** CloudFront already handles this. Nothing to migrate.
- **Quiz engine (scoring logic):** Core learning flow, low latency required. Risk outweighs benefit.
- **User enrollment / payments:** Transactional, revenue-critical. Do not touch.
