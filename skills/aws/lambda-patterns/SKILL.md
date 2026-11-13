---
name: lambda-patterns
description: >
  Use when writing, reviewing, or debugging AWS Lambda functions. Covers arm64,
  handler structure, cold starts, memory/timeout sizing, environment variables,
  CloudWatch logs, error handling, and Node.js/Python patterns (response streaming
  lives in sam-deploy).
---

# Lambda Patterns

## Objective

Write efficient, cost-effective Lambda functions with the right defaults for every runtime.

## Rules

### Always use arm64

```yaml
Architectures: [arm64]
```

20% cheaper per GB-second than x86_64, equal or better performance for most workloads, and no code changes for pure JS/TS or Python. Exception: binaries compiled only for x86 (rare; check first with `file <binary>`).

### Memory and timeout sizing

| Use case | Memory | Timeout |
|----------|--------|---------|
| Simple API proxy / CRUD | 128–256 MB | 10–15 s |
| Report / PDF generation | 512–1024 MB | 60–120 s |
| ML inference (small model) | 1024–3008 MB | 60–300 s |
| Behind API Gateway REST proxy | any | **max 29 s** (default integration timeout) |
| Background / async (SQS, EventBridge) | 256–512 MB | up to 900 s |

Start at 256 MB. Use CloudWatch `Duration` and `Max Memory Used` metrics to right-size.

### Handler structure

- Node.js: ESM preferred (`index.mjs`, or `"type": "module"` in package.json). Templates for Node.js and Python: `references/handler-templates.md`.
- Initialize SDK clients and read environment variables once at module load, outside the handler (reused across warm invocations). Fail at load when a required variable is missing.
- Set variables under `Environment: Variables:` in `template.yaml` (`TABLE_NAME: !Ref MyTable`, `LOG_LEVEL: INFO`, `NODE_ENV: production`).
- Do not hardcode region or account ID — use the `AWS_REGION` env var or `!Sub '${AWS::Region}'`.

### Cold starts — minimize them

- **Keep imports lean**: only import what the handler needs.
- **Avoid large local dependencies**: use Lambda Layers for heavy libraries (Puppeteer, PIL, etc.).
- **Provisioned Concurrency** is the only setting that keeps instances warm; use it only for latency-critical, high-traffic paths because it adds cost. Reserved concurrency caps and guarantees capacity but does not pre-warm anything.

### Logging

- Every `console.log` / `print` goes to CloudWatch Logs automatically. Log JSON, not plain strings — enables structured querying with CloudWatch Insights.
- Never log: tokens, passwords, credit card data, PII, full request bodies from auth flows. That rules out logging the whole `event` (it carries headers and bodies).
- Never log environment variables — they may contain secrets.
- **Set log retention** in the template — default is never-expire (costly). Add an `AWS::Logs::LogGroup` named `/aws/lambda/${MyFunction}` with `RetentionInDays: 14`; full snippet in `cost-optimizer`.

### Error handling rules

- Return structured error responses (`statusCode: 4xx/5xx` + `body: JSON`) from API-facing handlers.
- For async handlers (SQS, EventBridge): throw the error — Lambda retries according to the event source or async invocation settings.
- Configure a failure destination for every async source. Asynchronous invocations (EventBridge, S3, SNS):
```yaml
EventInvokeConfig:
  DestinationConfig:
    OnFailure:
      Type: SQS
      Destination: !GetAtt DeadLetterQueue.Arn
```
  SQS event sources ignore `EventInvokeConfig`: set a `RedrivePolicy` with a Dead Letter Queue (DLQ) on the source queue instead.

### Avoid

- Calling external services synchronously inside Lambda without timeout/retry logic.
- Relying on `/tmp` for persistent state across invocations — it may persist but is not guaranteed.
- Writing to files outside `/tmp` — Lambda filesystem is read-only except `/tmp` (512 MB–10 GB).
- Lambda for tasks > 15 min — use Step Functions + ECS Fargate instead.

## Reference

- `references/handler-templates.md`: Node.js ESM and Python handler skeletons (client init, structured logging, error response) and the environment-variable snippet. Read when writing a new handler or reviewing one against the rules above.
- Response streaming through API Gateway: `sam-deploy` (`references/response-streaming.md`).
