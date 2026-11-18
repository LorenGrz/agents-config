# 0011 — Alcance global o por proyecto para skills, rules y MCP

Estado: aceptado (2026-11-02).

## Contexto

Todo se instalaba global: 45 skills y 8 rules en `~/.claude/`, sin importar el repo. Las skills de stack
(NestJS, Next, AWS, APEX...) gastaban contexto en trabajo ajeno, y `project-init` solo armaba enforcement, no
assets de agente.

## Decisión

- `config/scopes.json` lista stacks (`react-vite`, `next`, `nestjs`, `node-ts`, `rn`, `aws`, `python`,
  `kotlin`, `apex`, `docker`, `llm`, `supabase`, `jira`) con sus skills, rules y servidores MCP. **Lo que no
  está listado es global**, y es lo único que instalan `install.sh`/`sync.sh`.
- `scripts/project-agents.sh --stack a,b` (también lo corre `init.sh` de `project-init`, con `--with` para
  extras) copia las skills y rules del stack al `.claude/` del proyecto y fusiona sus MCP en `.mcp.json`.

## Consecuencias

- Menos contexto base por sesión (45 -> 29 skills, 8 -> 3 rules); las skills de stack no se activan en un repo
  que nunca corrió `project-agents.sh`.
- Son copias, no symlinks, para que los repos sean portables en CI y en clones; se refrescan volviendo a
  correr el script. Los conectores de claude.ai (Notion, Miro, Whimsical, Supabase) son de la cuenta y no se
  acotan acá.
