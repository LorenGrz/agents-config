# aws

Skills para trabajar con infraestructura serverless en AWS. Cada una es un `SKILL.md` autocontenido que
Claude lee cuando hace falta, para aplicar patrones de mínimo privilegio y bajo costo.

## Skills

| Skill | Cuándo cargarla |
|-------|-------------|
| [`serverless-scanner`](./serverless-scanner/SKILL.md) | Analizar productos existentes para encontrar migraciones a serverless con buen retorno |
| [`sam-deploy`](./sam-deploy/SKILL.md) | Construir y deployar stacks con AWS SAM CLI: `samconfig.toml`, pipeline de build/deploy, response streaming, errores comunes |
| [`lambda-patterns`](./lambda-patterns/SKILL.md) | Escribir handlers de Lambda: arm64, memoria, cold starts, ESM, Python, logs de CloudWatch, manejo de errores |
| [`iam-least-privilege`](./iam-least-privilege/SKILL.md) | Crear usuarios, roles y políticas de IAM: usuario de deploy, roles de ejecución, plantillas de políticas, scripts de setup |
| [`cost-optimizer`](./cost-optimizer/SKILL.md) | Mantener el costo de AWS al mínimo: free tier, arm64, retención de logs, alarmas de facturación, trampas de costo |

## Uso

Viven dentro de este hub en `skills/aws/<skill>/SKILL.md` (entraron con `git subtree`, ver
`docs/decisions/0001-single-repo.md`), no en un repo aparte.

Son **de proyecto**, no globales: las cinco están en el stack `aws` de `config/scopes.json`, así que
`sync.sh` no las espeja en `~/.claude/skills` e `install.sh` no las instala. Se suman a un proyecto con
`scripts/project-agents.sh`, que las copia al `.claude/skills/` del proyecto:

```bash
scripts/project-agents.sh --stack aws --dir ~/projects/my-app
# project-init hace lo mismo: init.sh --stack nestjs --with aws ...
```

Ver «Alcance global o por proyecto» en `config/README.md` y el ADR 0011.
