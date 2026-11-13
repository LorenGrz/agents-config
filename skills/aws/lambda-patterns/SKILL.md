---
name: lambda-patterns
description: >
  Use when writing, reviewing, or debugging AWS Lambda functions. Covers runtime selection,
  arm64, handler structure, cold starts, memory/timeout sizing, environment variables,
  CloudWatch logs, response streaming, error handling, and Node.js/Python patterns.
---

# Lambda Patterns

Write efficient, cost-effective Lambda functions with the right defaults for every runtime.

## Always use arm64

```yaml
Architectures: [arm64]
```

- 20% cheaper per GB-second than x86_64
- Equal or better performance for most workloads (Node.js, Python)
- No code changes required for pure JS/TS or Python
- Exception: binaries compiled only for x86 (rare; check first with `file <binary>`)

## Memory and timeout sizing

| Use case | Memory | Timeout |
|----------|--------|---------|
| Simple API proxy / CRUD | 128–256 MB | 10–15 s |
| Report / PDF generation | 512–1024 MB | 60–120 s |
| ML inference (small model) | 1024–3008 MB | 60–300 s |
| Behind API Gateway REST proxy | any | **max 29 s** (hard limit) |
| Background / async (SQS, EventBridge) | 256–512 MB | up to 900 s |

Start at 256 MB. Use CloudWatch `Duration` and `Max Memory Used` metrics to right-size.

## Node.js handler — ESM (preferred)

```js
// index.mjs — use .mjs or set "type": "module" in package.json

// Initialize SDK clients OUTSIDE the handler (reused across warm invocations)
import { DynamoDBClient, GetItemCommand } from '@aws-sdk/client-dynamodb'
const db = new DynamoDBClient({ region: process.env.AWS_REGION })

export const handler = async (event) => {
  // Structured log — visible in CloudWatch
  console.log(JSON.stringify({ event, requestId: event.requestContext?.requestId }))

  try {
    const result = await db.send(new GetItemCommand({ /* ... */ }))
    return { statusCode: 200, body: JSON.stringify(result) }
  } catch (err) {
    console.error(JSON.stringify({ error: err.message, stack: err.stack }))
    return { statusCode: 500, body: JSON.stringify({ error: 'Internal error' }) }
  }
}
```

## Python handler

```python
import json, os, logging, boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize clients outside handler
dynamodb = boto3.resource('dynamodb', region_name=os.environ['AWS_DEFAULT_REGION'])
table = dynamodb.Table(os.environ['TABLE_NAME'])

def handler(event, context):
    logger.info(json.dumps({'event': event, 'request_id': context.aws_request_id}))
    try:
        result = table.get_item(Key={'id': event['pathParameters']['id']})
        return {'statusCode': 200, 'body': json.dumps(result.get('Item', {}))}
    except Exception as e:
        logger.error(json.dumps({'error': str(e)}))
        return {'statusCode': 500, 'body': json.dumps({'error': 'Internal error'})}
```

## Cold starts — minimize them

- **Keep imports lean**: only import what the handler needs.
- **Initialize SDK clients once** at module load, not inside the handler.
- **Avoid large local dependencies**: use Lambda Layers for heavy libraries (Puppeteer, PIL, etc.).
- **Set reserved concurrency** if cold starts matter — keeps instances warm.
- **Provisioned Concurrency** only for latency-critical, high-traffic paths; adds cost.

## Environment variables

```yaml
# template.yaml
Properties:
  Environment:
    Variables:
      TABLE_NAME: !Ref MyTable
      LOG_LEVEL: INFO
      NODE_ENV: production
```

In code, read at module load time (not inside handler) for efficiency:
```js
const TABLE_NAME = process.env.TABLE_NAME
if (!TABLE_NAME) throw new Error('Missing TABLE_NAME env var')
```

Never log environment variables — they may contain secrets.

## CloudWatch logs

- Every `console.log` / `print` goes to CloudWatch Logs automatically.
- **Set log retention** in the template — default is never-expire (costly):

```yaml
MyFunctionLogGroup:
  Type: AWS::Logs::LogGroup
  Properties:
    LogGroupName: !Sub '/aws/lambda/${MyFunction}'
    RetentionInDays: 14
```

- Log JSON, not plain strings — enables structured querying with CloudWatch Insights.
- Never log: tokens, passwords, credit card data, PII, full request bodies from auth flows.

## Error handling rules

- Return structured error responses (`statusCode: 4xx/5xx` + `body: JSON`) from API-facing handlers.
- For async handlers (SQS, EventBridge): throw the error — Lambda will retry according to the event source mapping.
- Configure a Dead Letter Queue (DLQ) for all async Lambda event sources:
```yaml
EventInvokeConfig:
  DestinationConfig:
    OnFailure:
      Type: SQS
      Destination: !GetAtt DeadLetterQueue.Arn
```

## Avoid

- Hardcoding region or account ID — use `AWS_REGION` env var or `!Sub '${AWS::Region}'`.
- Calling external services synchronously inside Lambda without timeout/retry logic.
- Relying on `/tmp` for persistent state across invocations — it may persist but is not guaranteed.
- Writing to files outside `/tmp` — Lambda filesystem is read-only except `/tmp` (512 MB–10 GB).
- Lambda for tasks > 15 min — use Step Functions + ECS Fargate instead.
