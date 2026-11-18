# 0035 — En Jira se confirma solo crear tickets y comentar

Estado: aceptado (2026-11-18). Ajusta las barandas de 0016 para Jira.

## Contexto

El ADR 0016 puso en `permissions.ask` toda escritura de Jira, y las skills pedían el OK sobre el texto exacto
para crear, editar, comentar, transicionar, cargar horas y linkear. El 2026-11-18 Loren pidió que solo se
confirmen la creación de tickets y los comentarios.

## Decisión

- En Jira esperan el OK del usuario, con el texto exacto a la vista, solo dos cosas: crear un ticket y agregar
  un comentario. Editar un ticket, transicionar, cargar horas y linkear se hacen sin preguntar y se informan en
  una línea.
- Crear o editar páginas de Confluence sigue pidiendo OK. GitHub, Slack y Google no cambian.
- `config/settings.base.json` saca de `permissions.ask` a `editJiraIssue`, `addWorklogToJiraIssue` y
  `createIssueLink`; quedan `createJiraIssue`, `addCommentToJiraIssue`, `createConfluencePage` y
  `updateConfluencePage`.
- La regla está en `config/AGENTS.md` («Organizations»), `skills/integrations/jira-usage` y
  `skills/integrations/github-usage`. Una org puede sumar restricciones en su `POLICIES.md`.

## Consecuencias

- Una edición equivocada de un ticket ya no tiene freno previo: queda el historial de Jira y el informe de una
  línea.
- `install.sh` une `permissions.ask` con lo que ya había, así que una máquina instalada antes de este ADR
  conserva las tres entradas hasta que se borran a mano de `~/.claude/settings.json`.
