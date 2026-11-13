---
name: sam-deploy
description: >
  Use when building or deploying a serverless stack with AWS SAM (Serverless Application Model).
  Covers samconfig.toml, SAM build/deploy pipeline, IAM deploy-user setup, stack outputs,
  response streaming, arm64 Lambda, and common error recovery.
---

# SAM Deploy

Full workflow for packaging and deploying AWS serverless stacks with SAM CLI.

## Pre-flight

Before writing or running any SAM command:
1. Check the project has `template.yaml` and `samconfig.toml`.
2. Confirm the AWS CLI is configured (`aws sts get-caller-identity`).
3. Never use root credentials — see `iam-least-privilege` skill for deploy-user setup.

## samconfig.toml baseline

```toml
version = 0.1

[default.global.parameters]
stack_name     = "<project>-stack"
resolve_s3     = true
capabilities   = "CAPABILITY_IAM"
confirm_changeset = false

[default.deploy.parameters]
region = "us-east-1"
```

- `resolve_s3 = true` auto-creates and reuses the SAM-managed artifact bucket. Never hardcode the bucket name.
- `confirm_changeset = false` is safe for personal/dev stacks; set `true` for production.
- `CAPABILITY_IAM` is required whenever the template creates IAM roles.

## Deploy pipeline

```bash
# Always build before deploy — never skip
sam build

# First deploy (will prompt for missing params and write samconfig.toml if absent)
sam deploy --guided

# Subsequent deploys (reads samconfig.toml)
sam deploy
```

Full one-liner after setup:
```bash
sam build && sam deploy
```

## template.yaml conventions

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31

Resources:
  MyFunction:
    Type: AWS::Serverless::Function
    Properties:
      FunctionName: my-function
      Handler: index.handler
      Runtime: nodejs22.x       # or python3.12
      Architectures: [arm64]    # always prefer arm64 — 20% cheaper, faster
      MemorySize: 256
      Timeout: 29               # max 29s when behind API Gateway REST API (29s proxy limit)
      CodeUri: ./build/         # or src/ if no build step

Outputs:
  FunctionArn:
    Value: !GetAtt MyFunction.Arn
  ApiUrl:
    Value: !Sub "https://${Api}.execute-api.${AWS::Region}.amazonaws.com/prod/"
```

## Lambda response streaming (Node.js)

Required when streaming large payloads through API Gateway:

```js
// Must use InvokeWithResponseStream — configure in template.yaml
import awslambda from 'aws-lambda'

export const handler = awslambda.streamifyResponse(async (event, responseStream, context) => {
  const metadata = { statusCode: 200, headers: { 'Content-Type': 'text/html' } }
  responseStream = awslambda.HttpResponseStream.from(responseStream, metadata)
  responseStream.write('chunk 1')
  responseStream.write('chunk 2')
  responseStream.end()
})
```

API Gateway method must set `ResponseTransferMode: STREAM` in the integration.

## Common errors and fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `No changes to deploy. Stack X is up to date` | Lambda code unchanged from last build | Run `sam build` again — if still same hash, the code genuinely didn't change |
| `CAPABILITY_IAM` missing | Template creates IAM resources | Add `capabilities = "CAPABILITY_IAM"` to samconfig.toml |
| `Missing Authentication Token` from API Gateway | Request URL missing the stage prefix | Ensure all `href` values include the stage path (e.g. `/prod/`) |
| `Error: Running NodejsNpmBuilder:NpmTest` and fails | `test` script exits non-zero | Add `"test": "echo ok"` to package.json if no tests yet |
| `Uploaded artifact is too large` | Lambda ZIP > 50 MB unzipped / 250 MB unzipped layer | Exclude node_modules from CodeUri using `.samignore`; use Lambda Layers for deps |
| `Cannot resolve S3 bucket` | First deploy on fresh account | Run `sam deploy --guided` once to create the SAM managed bucket |

## Deployment verification

After deploy, always verify with:
```bash
# Check stack outputs
aws cloudformation describe-stacks --stack-name <name> --query 'Stacks[0].Outputs'

# Check Lambda last update
aws lambda get-function --function-name <name> --query 'Configuration.LastModified'

# Quick smoke test
curl -s https://<api-id>.execute-api.us-east-1.amazonaws.com/prod/
```

## Stack cleanup

```bash
# Delete the entire stack (irreversible)
sam delete --stack-name <name>
```

Always run `sam delete` rather than manually deleting resources — SAM handles dependency order.
