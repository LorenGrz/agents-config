# 0036 — Un líder por repo cuando el trabajo cruza repos

Estado: aceptado (2026-11-18). Ajusta 0033 en el reparto del Plan L.

## Contexto

El ADR 0033 repartía un Plan L en «un worker por repo o capa, cada uno en su worktree», y prohibía que un
agente lanzado con un brief lanzara otros. Un worker así no carga las skills ni las restricciones del repo
donde trabaja, y Loren pidió el 2026-11-18 que cada repo se trabaje con las suyas.

## Decisión

- La sesión principal planifica, escribe los briefs e integra; en Plan L no escribe código.
- Cuando el trabajo cruza repos (backend, frontend), cada repo tiene un líder: una sesión abierta en ese
  repo, en el único worktree de la rama de la tarea, para que valgan su `AGENTS.md`, sus skills y sus
  restricciones.
- Si los repos viven en una carpeta de workspace que tiene sus skills, el líder se abre en esa carpeta y
  puede mandar un líder a cada repo hijo, que a su vez lanza workers.
- Un líder es un reasoner: para Loren, Opus en esfuerzo alto que consulta al advisor. La sesión principal
  también lo es, así que una decisión se queda en ella o en el líder, sin pasar por el subagente `reasoner`.
- El líder implementa con las skills del repo, puede lanzar `worker` y `scout` ahí, commitea en la rama de
  la tarea y hace revisar su diff (`review-handoff`, con la skill de review del repo) antes de devolver el
  trabajo. Nunca pushea ni abre el PR.
- Solo un líder lanza agentes propios: `worker` y `scout`, y el de un workspace, además, los líderes de sus
  repos hijos. `worker`, `scout` y el reviewer no lanzan ninguno.
- Los workers de un líder comparten el worktree de la tarea sobre archivos disjuntos; si se pisan, cada uno
  va en su worktree.
- En un solo repo, el líder es la sesión principal.
- Transporte del líder: en T3 Code, un hilo nuevo con `t3_thread_launch` en el proyecto de ese repo o workspace, seguido
  de `t3_thread_wait` (`delegate_task` solo corre en el proyecto del hilo actual; un Plan L aprobado que
  nombra a los líderes es el pedido del usuario para abrir esos hilos); en Orca, un worker en ese repo; en
  Claude Code, un subagente con la ruta del repo en el brief.

## Consecuencias

- Hay dos niveles de delegación, y el líder en Opus cuesta más que un worker en Sonnet.
- En Claude Code un subagente no carga solo las skills de otro repo: el brief le dice que lea su `AGENTS.md`
  y su `.claude/skills` primero.
- Verificado en T3 Code el 2026-11-18 con un hilo de solo lectura en otro repo: cae en el checkout de ese
  repo, carga su `CLAUDE.md` y la config global, tiene `worker` y `scout` y no pregunta la lane. El
  transporte en Orca y en Claude Code está escrito pero no verificado.
- Un líder solo ve las skills instaladas para ese repo o globales: las que viven en la carpeta padre de un
  workspace no le llegan. Por eso, con un workspace, el líder se abre en la carpeta padre.
