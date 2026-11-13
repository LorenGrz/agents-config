# Handler templates

Read when: writing a new Lambda handler, or reviewing one against the rules in `SKILL.md`.

## Node.js handler — ESM (preferred)

```js
// index.mjs — use .mjs or set "type": "module" in package.json

// Initialize SDK clients OUTSIDE the handler (reused across warm invocations)
import { DynamoDBClient, GetItemCommand } from '@aws-sdk/client-dynamodb'
const db = new DynamoDBClient({ region: process.env.AWS_REGION })

export const handler = async (event) => {
  // Structured log — visible in CloudWatch. Log identifiers, never the whole event.
  console.log(JSON.stringify({ requestId: event.requestContext?.requestId }))

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
dynamodb = boto3.resource('dynamodb', region_name=os.environ['AWS_REGION'])
table = dynamodb.Table(os.environ['TABLE_NAME'])

def handler(event, context):
    logger.info(json.dumps({'request_id': context.aws_request_id}))
    try:
        result = table.get_item(Key={'id': event['pathParameters']['id']})
        return {'statusCode': 200, 'body': json.dumps(result.get('Item', {}), default=str)}
    except Exception as e:
        logger.error(json.dumps({'error': str(e)}))
        return {'statusCode': 500, 'body': json.dumps({'error': 'Internal error'})}
```

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
