# Pricing and cost traps

Read when: estimating a bill, answering "is this free?", choosing between REST and HTTP API, right-sizing Lambda memory, or diagnosing an unexpected charge. Prices are list prices for `us-east-1`; confirm against the AWS pricing pages before quoting them as current.

## Free tier

Accounts created before 2025-07-15 have the 12-month free tier below. Accounts created after that date get free-plan credits instead of the 12-month allowances; the always-free rows apply to both.

| Service | Allowance | Duration |
|---------|-----------|----------|
| Lambda | 1M requests/month + 400,000 GB-seconds/month | Always free |
| API Gateway REST | 1M API calls/month | First 12 months only |
| API Gateway HTTP | 1M API calls/month | First 12 months only |
| S3 | 5 GB storage + 20k GET + 2k PUT requests | First 12 months |
| CloudWatch | 10 custom metrics + 10 alarms + 3 dashboards + 5 GB log ingestion | Always free |
| CloudFront | 1 TB egress + 10M requests/month | Always free |
| DynamoDB | 25 GB storage + 25 provisioned WCU/RCU (about 200M requests/month) | Always free; on-demand requests are not covered |
| SES | 3,000 message charges/month | First 12 months |

A portfolio site that gets < 50k visits/month stays inside the Lambda always-free tier indefinitely. API Gateway is free only for the first 12 months; after that the same traffic costs cents ($1.00–$3.50 per 1M calls).

## Lambda cost math

Lambda cost = duration × memory, plus $0.20 per 1M requests.

For a simple API returning JSON: 256 MB, < 100 ms duration → ~$0.000000417 compute per request on x86_64 (~$0.000000333 on arm64). 1M requests/month = $0.42 compute + $0.20 requests, still inside the free tier.

## Memory profiling

Profile with AWS Lambda Power Tuning (open source) or manually:
1. Deploy function at 128 MB
2. Run test invocation, note `Billed duration` and `Max Memory Used` in CloudWatch
3. If `Max Memory Used ≈ configured memory`, increase
4. Find the knee in the duration/cost curve (usually 512–1024 MB for CPU-bound workloads; a simple JSON API stays at 128–256 MB)

## API Gateway: REST API vs HTTP API

| | REST API | HTTP API |
|-|----------|----------|
| Cost per 1M calls | $3.50 | $1.00 |
| Features | Full (custom auth, usage plans, request validation) | Simpler (JWT auth, Lambda proxy) |
| Response streaming | Yes (InvokeWithResponseStream) | No |
| Use when | Need streaming or advanced features | Simple Lambda proxy |

For a personal site or simple API without streaming requirements, HTTP API is 3.5× cheaper.

## S3

- **Versioning**: disable unless needed — stores every version of every object.
- **Lifecycle policies**: add a rule to expire objects > 90 days in temp buckets.
- **Data transfer (egress)**: S3 → internet costs $0.09/GB. Serve large assets via CloudFront.
- **CloudFront**: use it for static sites (free tier above).

## DynamoDB on-demand vs provisioned

- **On-demand (pay per request)**: best for low/unpredictable traffic. No minimum cost, but not covered by the always-free tier.
- **Provisioned**: cheaper at sustained high traffic, and the only mode the always-free 25 WCU/RCU applies to. Not suitable for portfolio/learning projects with unpredictable traffic.

## Common cost traps

| Trap | Cause | Fix |
|------|-------|-----|
| Surprise $5–20 bill | CloudWatch logs set to never expire | Add `RetentionInDays` to every log group |
| NAT Gateway charges | Lambda in VPC uses NAT to reach internet | Remove Lambda from VPC unless RDS is in VPC. Use VPC endpoints for DynamoDB/S3. |
| Data transfer between regions | Cross-region API calls from Lambda | Keep Lambda and downstream services in same region |
| EC2 accidentally left running | Started for testing, forgotten | Use Lambda/Fargate for test workloads; set billing alarm |
| S3 with versioning + frequent writes | Versions accumulate silently | Add S3 lifecycle rule to expire non-current versions after 7 days |
| API Gateway caching enabled | Caching is $0.02–$3.80/hour per stage | Disable caching unless explicitly needed |
| Extra dashboards | Each dashboard beyond the 3 free ones is billed monthly | Keep only what you'll actually read |
