---
name: iam-least-privilege
description: >
  Use when creating IAM users, roles, policies, or reviewing AWS credentials setup.
  Covers the principle of least privilege, deploy-user patterns, execution roles,
  policy structure, conditions, and safe credential practices for CI/CD and local dev.
---

# IAM Least Privilege

## Objective

Grant only the minimum permissions required, to the minimum number of principals, for the minimum time needed.

## Rules

### Core rules (never break these)

1. **Never use root credentials** for anything except creating the first IAM admin and enabling MFA.
2. **Never use `AdministratorAccess`** for deploy users, CI/CD pipelines, or application roles.
3. **One IAM user/role per service or pipeline.** Cross-service reuse of credentials hides blast radius.
4. **Rotate access keys periodically.** Prefer IAM roles over long-lived access keys wherever possible.
5. **Never commit credentials.** Use `~/.aws/credentials`, environment variables, or Secrets Manager.

### IAM entity types and when to use each

| Entity | Use case | Authentication |
|--------|----------|----------------|
| **IAM User + Access Key** | Local dev, CI/CD in environments without OIDC | Static key (`aws configure`) |
| **IAM Role** | Lambda execution, EC2, ECS, CDK bootstrap | Assumed automatically by the service |
| **OIDC Identity Provider** | GitHub Actions, GitLab CI, CircleCI | Short-lived token, no static key needed |

Prefer roles and OIDC. Only create IAM users when there is no alternative.

### Policies

- Always specify the exact resource ARN. Never use `"Resource": "*"` for data-plane actions (DynamoDB, S3 objects, Secrets Manager secrets).
- Deploy user for SAM / CloudFormation: store the policy in `aws/iam-deploy-policy.json` and create the user with `aws/setup-deploy-user.sh` (both templates in `references/policy-templates.md`). Once the stack name is fixed, narrow the template's `function:*` and `role/*` resources to `<stack-name>-*`: `iam:AttachRolePolicy` and `iam:PutRolePolicy` on `role/*` let the deploy user grant itself any permission.
- Lambda execution role: SAM creates a managed one automatically. Customize it only to add resource-level statements on top of `AWSLambdaBasicExecutionRole` (CloudWatch logs only).

### Validating a policy before applying it

Use the IAM Policy Simulator or AWS CLI:
```bash
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::<account>:user/<user> \
  --action-names cloudformation:CreateStack s3:PutObject \
  --resource-arns "*"
```

### Common mistakes

| Mistake | Fix |
|---------|-----|
| `"Action": "*"` or using `AdministratorAccess` | Enumerate only the actions actually used |
| `"Resource": "*"` on data-plane actions | Use specific ARNs: table ARN, bucket ARN, function ARN |
| Same IAM user for dev and prod | Separate users (or OIDC roles) per environment |
| Access keys committed to git | Use `.gitignore`, pre-commit hooks, `git-secrets` |
| Long-lived access keys with no rotation | Set 90-day rotation reminder; prefer OIDC for CI/CD |

## Reference

- `references/policy-templates.md`: the minimal SAM deploy-user policy JSON, the `aws/setup-deploy-user.sh` script, and a custom Lambda execution role in `template.yaml`. Read when creating a deploy user, writing its policy, or customizing an execution role.
