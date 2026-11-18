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
  restricciones. El modelo del líder sale del perfil (Opus en esfuerzo alto para Loren).
- El líder implementa con las skills del repo, puede lanzar `worker` y `scout` ahí, commitea en la rama de
  la tarea y hace revisar su diff (`review-handoff`, con la skill de review del repo) antes de devolver el
  trabajo. Nunca pushea ni abre el PR.
- Solo un líder de repo lanza agentes propios; `worker`, `scout` y el reviewer no lanzan ninguno.
- Los workers de un líder comparten el worktree de la tarea sobre archivos disjuntos; si se pisan, cada uno
  va en su worktree.
- En un solo repo, el líder es la sesión principal.
- Transporte del líder: `delegate_task` en el proyecto de ese repo (T3 Code), un worker de Orca en ese repo
  (Orca), o un subagente con la ruta del repo en el brief (Claude Code).

## Consecuencias

- Hay dos niveles de delegación, y el líder en Opus cuesta más que un worker en Sonnet.
- En Claude Code un subagente no carga solo las skills de otro repo: el brief le dice que lea su `AGENTS.md`
  y su `.claude/skills` primero.
- El transporte del líder en Orca y en Claude Code está escrito pero no verificado.
