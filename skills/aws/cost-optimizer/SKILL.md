---
name: cost-optimizer
description: >
  Use when estimating, reviewing, or minimizing AWS costs for serverless architectures.
  Covers Lambda, API Gateway, DynamoDB, S3, CloudWatch, CloudFront, and data transfer pricing. Optimizes for
  sub-$1/month personal/portfolio workloads and identifies waste in small stacks.
---

# Cost Optimizer

## Objective

Keep AWS bills at minimum for serverless stacks. A personal portfolio or small API can run
for under $1/month or even free tier with the right defaults.

## Rules

### Defaults for every stack

- **arm64 always**: `Architectures: [arm64]` costs **20% less** per GB-second than x86_64, with zero code changes for Node.js and Python (exception and sizing table: `lambda-patterns`).
- **Log retention on every Lambda log group.** Default retention is **never expire** and silently accumulates cost. 7–30 days is usually enough; never leave as infinite.
- **Billing alarm** immediately after creating any stack (command below).
- **HTTP API unless you need REST features**: $1.00 vs $3.50 per 1M calls (3.5× cheaper). REST API only for response streaming, usage plans, request validation, or stage caching.
- **DynamoDB on-demand** unless you can guarantee steady throughput > 5 req/s; provisioned is not suitable for portfolio/learning projects.
- **No Lambda in VPC** without a specific reason (NAT Gateway charges).
- **S3**: versioning disabled unless needed, or a lifecycle rule that expires non-current versions; lifecycle rule to expire objects > 90 days in temp buckets; serve large assets and static sites via CloudFront, not S3 egress.
- **API Gateway stage caching disabled** unless explicitly needed.
- **CloudWatch dashboards**: only what you'll actually read.
- Memory: Lambda cost = duration × memory, so halving memory doesn't halve cost if it doubles duration. Right-size with the profiling steps in `references/pricing.md`.

### Log retention

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

### Billing alarm

Billing metrics exist only in `us-east-1` and only after "Receive Billing Alerts" is enabled in the account's Billing preferences; the SNS topic must be in `us-east-1` too.

```bash
aws cloudwatch put-metric-alarm \
  --region us-east-1 \
  --alarm-name billing-alert-5usd \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --threshold 5 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --dimensions Name=Currency,Value=USD \
  --evaluation-periods 1 \
  --alarm-actions arn:aws:sns:us-east-1:<account>:<topic>
```

## Reference

- `references/pricing.md`: free tier allowances, per-request cost math, memory profiling steps, REST vs HTTP API comparison, S3/DynamoDB pricing notes, and the table of common cost traps. Read when estimating a bill, answering "is this free?", choosing between API types, or diagnosing an unexpected charge.

## Verification

Before declaring a stack production-ready:
- [ ] All Lambda log groups have `RetentionInDays` ≤ 30
- [ ] arm64 architecture on all Lambda functions
- [ ] Billing alarm set at $5 or your threshold
- [ ] DynamoDB using on-demand (unless sustained load)
- [ ] No Lambda in VPC without a specific reason
- [ ] S3 versioning disabled or lifecycle rules configured
- [ ] API Gateway stage caching disabled
- [ ] CloudWatch dashboards: only what you'll actually read
