# Policy templates

Read when: creating a SAM deploy user, writing its policy, or customizing a Lambda execution role.

## Deploy-user policy (SAM / CloudFormation)

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

## Setup script

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

## Lambda execution role (least privilege)

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
