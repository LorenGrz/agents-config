---
name: sam-deploy
description: >
  Use when building or deploying a serverless stack with AWS SAM (Serverless Application Model).
  Covers samconfig.toml, SAM build/deploy pipeline, IAM deploy-user setup, stack outputs,
  response streaming, arm64 Lambda, and common error recovery.
---

# SAM Deploy

## Objective

Full workflow for packaging and deploying AWS serverless stacks with SAM CLI.

## Prerequisites

### Pre-flight

Before writing or running any SAM command:
1. Check the project has `template.yaml` and `samconfig.toml` (no `samconfig.toml` yet: the first `sam deploy --guided` writes it).
2. Confirm the AWS CLI is configured (`aws sts get-caller-identity`).
3. Never use root credentials — see `iam-least-privilege` skill for deploy-user setup.

### samconfig.toml baseline

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

## Workflow

### Deploy pipeline

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

### Deployment verification

After deploy, always verify with:
```bash
# Check stack outputs
aws cloudformation describe-stacks --stack-name <name> --query 'Stacks[0].Outputs'

# Check Lambda last update
aws lambda get-function --function-name <name> --query 'Configuration.LastModified'

# Quick smoke test
curl -s https://<api-id>.execute-api.us-east-1.amazonaws.com/prod/
```

### Stack cleanup

```bash
# Delete the entire stack (irreversible)
sam delete --stack-name <name>
```

Always run `sam delete` rather than manually deleting resources — SAM handles dependency order.

## Rules

### template.yaml conventions

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
      Architectures: [arm64]    # always arm64 — 20% cheaper (see lambda-patterns)
      MemorySize: 256
      Timeout: 29               # max 29s when behind API Gateway REST API (29s proxy limit)
      CodeUri: ./build/         # or src/ if no build step

Outputs:
  FunctionArn:
    Value: !GetAtt MyFunction.Arn
  ApiUrl:
    Value: !Sub "https://${Api}.execute-api.${AWS::Region}.amazonaws.com/prod/"
```

`${Api}` is the logical ID of an explicit `AWS::Serverless::Api` with `StageName: prod`. With SAM's implicit API the ID is `ServerlessRestApi` and the stage is `Prod`.

Handler structure, sizing, and logging: `lambda-patterns`. Log retention and billing alarm: `cost-optimizer`.

## Reference

- `references/troubleshooting.md`: table of common `sam build` / `sam deploy` / API Gateway errors with cause and fix. Read when a build, deploy, or first request fails.
- `references/response-streaming.md`: Node.js `streamifyResponse` handler and the API Gateway integration settings. Read when a response must be streamed through API Gateway.
