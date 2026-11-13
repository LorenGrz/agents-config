# aws-skills

Claude Code skills for working with AWS serverless infrastructure. Each skill is a self-contained `SKILL.md` that Claude reads on demand to apply consistent, least-privilege, cost-aware patterns.

## Skills

| Skill | When to load |
|-------|-------------|
| [`serverless-scanner`](./serverless-scanner/SKILL.md) | Analyzing existing products to identify high-ROI serverless migration opportunities |
| [`sam-deploy`](./sam-deploy/SKILL.md) | Building and deploying stacks with AWS SAM CLI — `samconfig.toml`, build/deploy pipeline, response streaming, common errors |
| [`lambda-patterns`](./lambda-patterns/SKILL.md) | Writing Lambda handlers — arm64, memory sizing, cold starts, ESM, Python, CloudWatch logs, error handling |
| [`iam-least-privilege`](./iam-least-privilege/SKILL.md) | Creating IAM users/roles/policies — deploy-user pattern, execution roles, policy templates, setup scripts |
| [`cost-optimizer`](./cost-optimizer/SKILL.md) | Keeping AWS costs minimal — free tier, arm64, log retention, billing alarms, cost traps |

## Usage

These skills live inside this hub at `aws/<skill>/SKILL.md` (folded in via `git subtree`,
see `docs/decisions/0001-single-repo.md`) — not a separate repo. `install.sh`'s `sync.sh`
step mirrors them flat into `~/.claude/skills`, so Claude Code loads them by name
(`sam-deploy`, `lambda-patterns`, `iam-least-privilege`, `cost-optimizer`,
`serverless-scanner`) once the hub itself is installed. No extra clone or setup step is
needed.
