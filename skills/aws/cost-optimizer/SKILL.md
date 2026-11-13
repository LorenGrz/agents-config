---
name: cost-optimizer
description: >
  Use when estimating, reviewing, or minimizing AWS costs for serverless architectures.
  Covers Lambda, API Gateway, S3, CloudWatch, and data transfer pricing. Optimizes for
  sub-$1/month personal/portfolio workloads and identifies waste in small stacks.
---

# Cost Optimizer

Keep AWS bills at minimum for serverless stacks. A personal portfolio or small API can run
for under $1/month or even free tier with the right defaults.

## Free tier (12 months + always-free)

| Service | Always-free allowance |
|---------|----------------------|
| Lambda | 1M requests/month + 400,000 GB-seconds/month |
| API Gateway REST | 1M API calls/month (first 12 months only) |
| API Gateway HTTP | 1M API calls/month (first 12 months only) |
| S3 | 5 GB storage + 20k GET + 2k PUT requests (first 12 months) |
| CloudWatch | 10 custom metrics + 5 GB log ingestion (first 12 months) |
| DynamoDB | 25 GB storage + 200M requests/month (always free) |
| SES | 62k outbound emails/month from Lambda (always free) |

A portfolio site that gets < 50k visits/month stays in Lambda + API Gateway free tier indefinitely.

## arm64 always

```yaml
Architectures: [arm64]
```

Graviton2 Lambda costs **20% less** per GB-second than x86_64. Zero code changes for Node.js and Python. Always use it.

## Memory sizing matters more than you think

Lambda cost = duration × memory. Halving memory doesn't halve cost if it doubles duration.

Profile with AWS Lambda Power Tuning (open source) or manually:
1. Deploy function at 128 MB
2. Run test invocation, note `Billed duration` and `Max Memory Used` in CloudWatch
3. If `Max Memory Used ≈ configured memory`, increase
4. Find the knee in the duration/cost curve (usually 512–1024 MB for most workloads)

For a simple API returning JSON: 256 MB, < 100 ms duration → ~$0.000000417 per request. 1M requests/month = $0.42 — still in free tier.

## CloudWatch Logs — set retention or pay forever

Default log group retention is **never expire**. This silently accumulates cost.

```yaml
# Always add this for every Lambda function
MyFunctionLogGroup:
  Type: AWS::Logs::LogGroup
  Properties:
    LogGroupName: !Sub '/aws/lambda/${MyFunction}'
    RetentionInDays: 14   # 7–30 days is usually enough; never leave as infinite
```

Or set via CLI for existing functions:
```bash
aws logs put-retention-policy \
  --log-group-name /aws/lambda/my-function \
  --retention-in-days 14
```

## API Gateway: REST API vs HTTP API

| | REST API | HTTP API |
|-|----------|----------|
| Cost per 1M calls | $3.50 | $1.00 |
| Features | Full (custom auth, usage plans, request validation) | Simpler (JWT auth, Lambda proxy) |
| Response streaming | Yes (InvokeWithResponseStream) | No |
| Use when | Need streaming or advanced features | Simple Lambda proxy |

For a personal site or simple API without streaming requirements, HTTP API is 3.5× cheaper.

## S3 — avoid accidental costs

- **Versioning**: disable unless needed — stores every version of every object.
- **Lifecycle policies**: add a rule to expire objects > 90 days in temp buckets.
- **Data transfer (egress)**: S3 → internet costs $0.09/GB. Serve large assets via CloudFront.
- **CloudFront**: has its own free tier (1 TB egress + 10M requests/month, first 12 months). Use it for static sites.

## DynamoDB on-demand vs provisioned

- **On-demand (pay per request)**: best for low/unpredictable traffic. No minimum cost.
- **Provisioned**: cheaper at sustained high traffic. Not suitable for portfolio/learning projects.

Use on-demand unless you can guarantee steady throughput > 5 req/s.

## CloudWatch dashboards and alarms

Set a **billing alarm** immediately after creating any stack:
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name billing-alert-5usd \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --threshold 5 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --dimensions Name=Currency,Value=USD \
  --evaluation-periods 1 \
  --alarm-actions arn:aws:sns:<region>:<account>:<topic>
```

## Common cost traps

| Trap | Cause | Fix |
|------|-------|-----|
| Surprise $5–20 bill | CloudWatch logs set to never expire | Add `RetentionInDays` to every log group |
| NAT Gateway charges | Lambda in VPC uses NAT to reach internet | Remove Lambda from VPC unless RDS is in VPC. Use VPC endpoints for DynamoDB/S3. |
| Data transfer between regions | Cross-region API calls from Lambda | Keep Lambda and downstream services in same region |
| EC2 accidentally left running | Started for testing, forgotten | Use Lambda/Fargate for test workloads; set billing alarm |
| S3 with versioning + frequent writes | Versions accumulate silently | Add S3 lifecycle rule to expire non-current versions after 7 days |
| API Gateway caching enabled | Caching is $0.02–$3.84/hour per stage | Disable caching unless explicitly needed |

## Cost review checklist

Before declaring a stack production-ready:
- [ ] All Lambda log groups have `RetentionInDays` ≤ 30
- [ ] arm64 architecture on all Lambda functions
- [ ] Billing alarm set at $5 or your threshold
- [ ] DynamoDB using on-demand (unless sustained load)
- [ ] No Lambda in VPC without a specific reason
- [ ] S3 versioning disabled or lifecycle rules configured
- [ ] API Gateway stage caching disabled
- [ ] CloudWatch dashboards: only what you'll actually read
