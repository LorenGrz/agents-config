# 0036 — Un líder por repo cuando el trabajo cruza repos

Estado: aceptado (2026-11-18). Ajusta 0033 en el reparto del Plan L. Ajustado por 0037: el líder también lanza a su
reviewer.
Ajustado por [0052](0052-flujo-de-matt-sin-superpowers.md): `worker` = Opus, y los workers por ticket del Plan L van cada uno en su worktree.

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
- El modelo del líder sale del perfil. Para Loren, un líder es un reasoner: una sesión de Opus en esfuerzo
  alto que consulta al advisor, igual que la sesión principal. No es el subagente `reasoner`, que solo
  devuelve una decisión o un plan.
- El líder implementa con las skills del repo, puede lanzar `worker`, `scout` y su reviewer ahí, commitea en la rama de
  la tarea y hace revisar su diff (`review-handoff`, con la skill de review del repo) antes de devolver el
  trabajo. Nunca pushea ni abre el PR.
- Solo un líder lanza agentes propios: `worker`, `scout` y su reviewer, y el de un workspace, además, los
  líderes de sus repos hijos. `worker`, `scout` y el reviewer no lanzan ninguno.
- Los workers de un líder comparten el worktree de la tarea sobre archivos disjuntos; si se pisan, cada uno
  va en su worktree.
- En un solo repo, el líder es la sesión principal.
- Transporte del líder: en T3 Code, un hilo nuevo con `t3_thread_launch` en el proyecto de ese repo o workspace, seguido
  de `t3_thread_wait` (`delegate_task` solo corre en el proyecto del hilo actual; un Plan L aprobado que
  nombra a los líderes es el pedido del usuario para abrir esos hilos); en Orca, un worker en ese repo o
  workspace; en Claude Code, un subagente general con la ruta en el brief.

## Consecuencias

- Hay dos niveles de delegación, y el líder en Opus cuesta más que un worker en Sonnet.
- En Claude Code un subagente no carga solo las skills de otro repo: el brief le dice que lea su `AGENTS.md`
  y su `.claude/skills` primero.
- Verificado el 2026-11-18, con pruebas de solo lectura:
  - T3 Code, cadena completa: un líder abierto en la carpeta del workspace ve las skills de esa carpeta,
    lanza con `t3_thread_launch` un líder en un repo hijo, y ese arranca un `scout`; también tiene
    `worker` y `reviewer`, y nadie pregunta la lane. El hilo del repo cae en el checkout de ese repo y
    carga su `CLAUDE.md` y la config global.
  - Claude Code: un subagente general tiene la herramienta para lanzar otros (`worker`, `scout`,
    `reviewer`) y arrancó un `scout`; `reviewer` y `scout` no la tienen. El contexto del repo le llega
    solo por las rutas que nombra el brief.
  - Orca: sin verificar. `orchestration worker-start` solo corre desde una terminal de Orca
    (`no_active_sender_terminal` desde afuera), así que hay que probarlo en una sesión de Orca.
- Un líder solo ve las skills instaladas para ese repo o globales: las que viven en la carpeta padre de un
  workspace no le llegan. Por eso, con un workspace, el líder se abre en la carpeta padre.
