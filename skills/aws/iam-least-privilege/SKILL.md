---
name: iam-least-privilege
description: >
  Use when creating IAM users, roles, policies, or reviewing AWS credentials setup.
  Covers the principle of least privilege, deploy-user patterns, execution roles,
  policy structure, conditions, and safe credential practices for CI/CD and local dev.
---

# IAM Least Privilege

Grant only the minimum permissions required, to the minimum number of principals, for the minimum time needed.

## Core rules (never break these)

1. **Never use root credentials** for anything except creating the first IAM admin and enabling MFA.
2. **Never use `AdministratorAccess`** for deploy users, CI/CD pipelines, or application roles.
3. **One IAM user/role per service or pipeline.** Cross-service reuse of credentials hides blast radius.
4. **Rotate access keys periodically.** Prefer IAM roles over long-lived access keys wherever possible.
5. **Never commit credentials.** Use `~/.aws/credentials`, environment variables, or Secrets Manager.

## IAM entity types and when to use each

| Entity | Use case | Authentication |
|--------|----------|----------------|
| **IAM User + Access Key** | Local dev, CI/CD in environments without OIDC | Static key (`aws configure`) |
| **IAM Role** | Lambda execution, EC2, ECS, CDK bootstrap | Assumed automatically by the service |
| **OIDC Identity Provider** | GitHub Actions, GitLab CI, CircleCI | Short-lived token, no static key needed |

Prefer roles and OIDC. Only create IAM users when there is no alternative.

## Deploy-user pattern (SAM / CloudFormation)

Minimal IAM policy for a SAM deploy user. Store in `aws/iam-deploy-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudFormation",
      "Effect": "Allow",
      "Action": [
        "cloudformation:CreateStack",
        "cloudformation:UpdateStack",
        "cloudformation:DeleteStack",
        "cloudformation:DescribeStacks",
        "cloudformation:DescribeStackEvents",
        "cloudformation:DescribeStackResources",
        "cloudformation:GetTemplate",
        "cloudformation:ValidateTemplate",
        "cloudformation:CreateChangeSet",
        "cloudformation:DescribeChangeSet",
        "cloudformation:ExecuteChangeSet",
        "cloudformation:DeleteChangeSet",
        "cloudformation:ListStackResources"
      ],
      "Resource": "*"
    },
    {
      "Sid": "S3ArtifactBucket",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:ListBucket", "s3:CreateBucket", "s3:GetBucketLocation"],
      "Resource": [
        "arn:aws:s3:::aws-sam-cli-managed-default-samclisourcebucket-*",
        "arn:aws:s3:::aws-sam-cli-managed-default-samclisourcebucket-*/*"
      ]
    },
    {
      "Sid": "Lambda",
      "Effect": "Allow",
      "Action": [
        "lambda:CreateFunction",
        "lambda:UpdateFunctionCode",
        "lambda:UpdateFunctionConfiguration",
        "lambda:GetFunction",
        "lambda:GetFunctionConfiguration",
        "lambda:DeleteFunction",
        "lambda:ListFunctions",
        "lambda:AddPermission",
        "lambda:RemovePermission",
        "lambda:GetPolicy",
        "lambda:InvokeFunction"
      ],
      "Resource": "arn:aws:lambda:*:*:function:*"
    },
    {
      "Sid": "ApiGateway",
      "Effect": "Allow",
      "Action": [
        "apigateway:GET",
        "apigateway:POST",
        "apigateway:PUT",
        "apigateway:DELETE",
        "apigateway:PATCH"
      ],
      "Resource": "arn:aws:apigateway:*::/*"
    },
    {
      "Sid": "IAMPassRoleToLambda",
      "Effect": "Allow",
      "Action": ["iam:PassRole"],
      "Resource": "*",
      "Condition": {
        "StringEquals": { "iam:PassedToService": "lambda.amazonaws.com" }
      }
    },
    {
      "Sid": "IAMForSAMExecutionRole",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:GetRole",
        "iam:GetRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:TagRole"
      ],
      "Resource": "arn:aws:iam::*:role/*"
    }
  ]
}
```

## Lambda execution role (least privilege)

SAM creates a managed execution role automatically. To customize:

```yaml
# template.yaml
MyFunctionRole:
  Type: AWS::IAM::Role
  Properties:
    AssumeRolePolicyDocument:
      Version: "2012-10-17"
      Statement:
        - Effect: Allow
          Principal: { Service: lambda.amazonaws.com }
          Action: sts:AssumeRole
    ManagedPolicyArns:
      - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole  # CloudWatch logs only
    Policies:
      - PolicyName: DynamoDBReadWrite
        PolicyDocument:
          Version: "2012-10-17"
          Statement:
            - Effect: Allow
              Action: ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"]
              Resource: !GetAtt MyTable.Arn  # resource-level, not *
```

Always specify the exact resource ARN. Never use `"Resource": "*"` for data-plane actions (DynamoDB, S3 objects, Secrets Manager secrets).

## Setup script pattern

```bash
#!/usr/bin/env bash
# aws/setup-deploy-user.sh
set -euo pipefail

USER="my-service-deploy"
POLICY="my-service-deploy-policy"

aws iam create-user --user-name "$USER"
aws iam create-policy \
  --policy-name "$POLICY" \
  --policy-document file://aws/iam-deploy-policy.json
aws iam attach-user-policy \
  --user-name "$USER" \
  --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/$POLICY"
aws iam create-access-key --user-name "$USER"
```

## Validating a policy before applying it

Use the IAM Policy Simulator or AWS CLI:
```bash
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::<account>:user/<user> \
  --action-names cloudformation:CreateStack s3:PutObject \
  --resource-arns "*"
```

## Common mistakes

| Mistake | Fix |
|---------|-----|
| `"Action": "*"` or using `AdministratorAccess` | Enumerate only the actions actually used |
| `"Resource": "*"` on data-plane actions | Use specific ARNs: table ARN, bucket ARN, function ARN |
| Same IAM user for dev and prod | Separate users (or OIDC roles) per environment |
| Access keys committed to git | Use `.gitignore`, pre-commit hooks, `git-secrets` |
| Long-lived access keys with no rotation | Set 90-day rotation reminder; prefer OIDC for CI/CD |
