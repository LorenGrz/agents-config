# AWS Service Mapping

Map detected workflow patterns to the most appropriate AWS serverless service. Always recommend the simplest service that solves the problem.

## Pattern → Service Map

| Workflow Pattern | Primary AWS Service | Supporting Services | Notes & Caveats |
|-----------------|--------------------|--------------------|-----------------|
| **Webhook receiver** (Stripe, GitHub, Twilio, etc.) | API Gateway + Lambda | EventBridge (fan-out), SQS (buffer) | Keep Lambda idempotent — webhooks retry. Validate signatures in Lambda, not API Gateway. |
| **Scheduled / cron job** | EventBridge Scheduler | Lambda | Use ScheduleV2 (not legacy cron rules). For jobs > 15 min, use Step Functions or ECS Fargate on schedule. |
| **File processing on upload** (image resize, CSV import, PDF parse) | S3 Event Notification → Lambda | S3, Textract (OCR), Rekognition (vision) | Lambda max 15 min, 10 GB ephemeral disk. For larger files use S3 Batch or Step Functions. |
| **Email sending** (transactional, marketing) | SES + Lambda | EventBridge, SQS | SES for sending; Lambda to template and trigger. Do not call SES directly from your primary API — decouple via queue. |
| **Push / SMS notifications** | SNS + Lambda | EventBridge | SNS for fan-out to multiple subscribers. Use Lambda to build the payload before publishing. |
| **Report generation** (PDF, Excel, CSV exports) | Lambda | S3 (store output), SES (email delivery), Step Functions (multi-step) | Pre-sign S3 URL and email the link rather than attaching large files. |
| **AI / LLM workflows** (summarization, classification, extraction) | Lambda + Bedrock | S3 (docs), DynamoDB (results cache), Step Functions (chains) | Bedrock InvokeModel for sync; InvokeModelWithResponseStream for streaming. Use Step Functions for multi-step chains. |
| **OCR / document intelligence** | Textract + Lambda | S3, Step Functions, DynamoDB | Textract async API for multi-page PDFs — use SNS callback + Lambda rather than polling. |
| **File / media uploads** | S3 presigned URL | Lambda (generate URL), CloudFront (serve) | Generate presigned URLs in Lambda; upload directly from browser to S3. Never proxy large uploads through Lambda. |
| **Admin / ops jobs** (data migrations, bulk updates, cleanup) | Lambda or Step Functions | DynamoDB, RDS Data API, S3 | Use Step Functions for jobs with retries, branching, or > 15 min runtime. Lambda for simple one-shot tasks. |
| **Authentication** (token validation, MFA, social login) | Cognito | Lambda (custom triggers) | Cognito User Pools for standard flows. Lambda triggers for custom pre/post auth logic. Do not rebuild auth from scratch in Lambda. |
| **State machines / multi-step workflows** | Step Functions | Lambda (each step), DynamoDB, SQS | Step Functions Express for high-volume short workflows; Standard for long-running or auditable flows. |
| **Event fan-out / pub-sub** | EventBridge | SNS, SQS, Lambda | EventBridge for routing by event schema. SNS for simple fan-out. SQS when consumers need independent pace. |
| **Async task queue** | SQS + Lambda | DLQ (SQS), CloudWatch Alarms | Always configure a DLQ. Set visibility timeout to at least 6× the Lambda timeout. |
| **Observability / alerting** | CloudWatch + Lambda | EventBridge, SNS, Chatbot | Lambda for custom metrics publishing. EventBridge rules to trigger alerts. Chatbot to route to Slack. |
| **GraphQL / REST API** (new or additive endpoints) | API Gateway + Lambda | DynamoDB, RDS Data API | Good for new, low-coupling endpoints. Do not migrate your entire monolith API — add new endpoints serverlessly. |
| **Search** | OpenSearch Serverless | Lambda (indexing), API Gateway | Use Lambda to index on DynamoDB Streams. OpenSearch Serverless for query. |
| **Caching** | ElastiCache Serverless | Lambda | Add caching in Lambda using the ElastiCache SDK. Keep Lambda warm-start time in mind — connection reuse matters. |

## Decision Shortcuts

**When you see this in the product → reach for this first:**

| Signal | First recommendation |
|--------|---------------------|
| "We send emails every night" | EventBridge Scheduler → Lambda → SES |
| "Users upload files / photos" | S3 presigned URL + S3 Event → Lambda |
| "We receive webhooks from X" | API Gateway + Lambda (idempotent) |
| "We generate reports / exports" | Lambda → S3 → presigned URL via SES |
| "We run a script manually every week" | EventBridge Scheduler → Lambda |
| "We process documents / PDFs" | S3 → Lambda → Textract (async) |
| "We use AI to classify / summarize" | Lambda → Bedrock InvokeModel |
| "We send push notifications" | Lambda → SNS |
| "We have a multi-step approval flow" | Step Functions Standard |
| "We poll an external API every N minutes" | EventBridge Scheduler → Lambda |

## Anti-patterns — do not map these to serverless

| Workflow | Why not |
|---------|---------|
| Primary transactional API (checkout, orders, auth) | High risk, tight coupling, latency-sensitive |
| WebSocket / real-time bidirectional features | Lambda is not persistent; use API Gateway WebSockets only for simple push |
| Long ML training jobs (hours) | Lambda max 15 min; use SageMaker or ECS |
| Heavy in-memory computation with shared state | Lambda is stateless; shared state needs external store |
| High-throughput streaming (> 10k events/sec ingestion) | Kinesis or MSK, not Lambda alone |
