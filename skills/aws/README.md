# aws

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

These skills live inside this hub at `skills/aws/<skill>/SKILL.md` (folded in via `git subtree`,
see `docs/decisions/0001-single-repo.md`), not in a separate repo.

They are **project-scoped**, not global: all five are listed under the `aws` stack in
`config/scopes.json`, so `sync.sh` does not mirror them into `~/.claude/skills` and `install.sh` does not
install them. Add them to a project with `scripts/project-agents.sh`, which copies them into the project's
`.claude/skills/`:

```bash
scripts/project-agents.sh --stack aws --dir ~/projects/my-app
# project-init does the same: init.sh --stack nestjs --with aws ...
```

See "Global vs project scope" in the root `README.md` and ADR 0011.
