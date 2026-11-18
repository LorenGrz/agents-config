# 0029 — El trabajo en un repo va por defecto a un worker en segundo plano

Estado: aceptado (2026-11-17). Enmienda la regla "≤3 known files stay inline" de "Agent Routing" en
`config/CLAUDE.md` y el límite "`worker` only from an approved plan".

## Contexto

La regla anterior dejaba inline los cambios de hasta 3 archivos conocidos y `worker` solo dentro de un plan
aprobado, y Loren no podía seguir trabajando mientras un arreglo chico corría inline. El 2026-11-17 pidió el
default opuesto.

## Decisión

- Todo cambio no trivial en un repo va a un `worker`, dentro o fuera de un plan, en segundo plano
  (`run_in_background`), en su propio worktree y en la rama de la tarea.
- El brief lleva los archivos exactos, el cambio decidido y un comando de aceptación, y le dice al worker que
  lea primero `AGENTS.md`/`CLAUDE.md` y `.claude/skills` del repo, y que no commitee ni pushee: la sesión
  principal revisa el diff y los checks reportados, y commitea.
- Los cambios triviales (una línea, o un archivo sin checks: un typo, un texto, un valor de config) quedan
  inline.
- No cambian la pregunta de lane (Continuar / Plan S / Plan L) ni las reglas de las orgs. Queda escrito en
  "Agent Routing" de `config/CLAUDE.md`, "Workflow lanes" de `config/AGENTS.md`, el recordatorio de
  `session-start.sh` y "Model routing" del perfil.

## Consecuencias

- La sesión principal queda libre mientras se escribe el código, a cambio de un arranque en frío por tarea y
  de briefs completos (el worker no ve la conversación).
