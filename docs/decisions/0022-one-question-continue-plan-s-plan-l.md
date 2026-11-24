# 0022 — Una pregunta decide el proceso: Continuar, Plan S o Plan L

Estado: aceptado (2026-11-09); ADR 0025 agrega el hook que impone el orden y la entrevista de grilling.
Reemplaza la elección de lane de ADR 0020 y acota ADR 0006 (la delegación aplica al trabajo que sale de un
plan aprobado). Ajustado por 0037: Plan S lanza subagentes cuando el trabajo los pide.
Reemplazado en parte por [0052](0052-flujo-de-matt-sin-superpowers.md): el Plan L ya no usa `brainstorming` ni `writing-plans`, sino `grilling`, `to-spec`, `to-tickets` e `implement-spec`, con spec y tickets en `.scratch/`.

## Contexto

Con ADR 0020 el trabajo sin plan no tenía regla, `using-superpowers` empuja `brainstorming` "before any
creative work" y elegir proceso llevaba dos pasos. Lo caro es por tarea: `brainstorming`, `writing-plans` y
`subagent-driven-development` suman ~11k tokens al cargar, y cada arranque de `worker` o `reasoner` ~4–6k.

## Decisión

- **Cambio puntual** (un archivo, intención clara): se hace directo. Sin pregunta, sin plan, sin lane.
- **Más de un archivo, o alcance poco claro** (incluidos los bugs de causa desconocida): antes de editar, un
  `AskUserQuestion` con exactamente tres opciones, siempre en este orden:
  - **Continuar:** directo, sin plan.
  - **Plan S:** plan mode con un plan corto (archivos, cambio, check), ejecutado inline, sin brainstorming,
    sin docs de spec y sin `worker`/`reasoner`.
  - **Plan L:** plan mode con `brainstorming`, después `writing-plans` en `docs/superpowers/`, después
    `worker`/`reasoner`, o caolg entre repos.
- La opción recomendada se marca con una línea de por qué, sin reordenar. Plan S o L entra en plan mode
  (`EnterPlanMode`). Una causa desconocida empieza con `systematic-debugging`. Un plan mode que el usuario
  abre directo termina con "Plan S/L because …".
- **Fuera de un plan** no se invocan `brainstorming`, `writing-plans`, `executing-plans`,
  `subagent-driven-development`, `worker` ni `reasoner` salvo pedido. Esto pisa `using-superpowers`, que pone
  las instrucciones del usuario por encima de las skills. `scout` sigue permitido para búsquedas abiertas:
  saca los volcados de archivos de la ventana principal.
- **Sin suposiciones** (regla personal, en el perfil): si el alcance, un requisito o una elección no están
  claros, se pregunta, aun en tareas triviales; se supone solo cuando el usuario lo dice. Es una versión más
  estricta de `karpathy-guidelines` §1.
- **La regla vive en `config/CLAUDE.md`, no en un hook.** `critical-reasoning.sh` ahora pide la pregunta de
  tres opciones y nombra `reasoner` para Plan L; `session-start.sh` repite la regla en una línea.
- Descartado: imponerla con un hook, porque entrar en plan mode con `EnterPlanMode` no manda un prompt nuevo y
  `UserPromptSubmit` no se dispararía.

## Consecuencias

- Verificado en vivo con `claude -p --model sonnet`: un pedido de un archivo se hizo directo; uno de dos
  archivos frenó con las tres opciones en orden, sin editar nada. En `claude -p` no hay `AskUserQuestion`
  interactivo: la pregunta vuelve como texto.
- Codex y las demás CLI no cambian: plan mode y la pregunta son de Claude Code.
