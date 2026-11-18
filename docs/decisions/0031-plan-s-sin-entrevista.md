# 0031 — Plan S sin la entrevista de grilling

Estado: aceptado (2026-11-18). Enmienda ADR 0025 en la entrevista; el orden de las lanes queda igual. Ajustado por 0037: Plan S lanza subagentes cuando el trabajo los pide.

## Contexto

ADR 0025 hizo obligatoria la entrevista antes de todo plan. El 2026-11-18, tras un Plan S con tres rondas de
preguntas, Loren pidió: «a partir de ahora el plan corto no va a tener entrevista, sino para lo crítico me va
a hacer las preguntas clave de decisiones importantes, dejamos la entrevista para el plan L con subagentes y
que estos se envíen a los worktree que correspondan».

## Decisión

- **Plan S:** sin entrevista. El agente investiga y pregunta, en una sola tanda, solo las decisiones críticas
  que no puede deducir.
- **Plan L:** mantiene la entrevista de grilling, y su trabajo va a subagentes o workers, cada uno en el
  worktree de la rama que toca.
- `lane-guard.sh` exige grilling en `ExitPlanMode` solo cuando la última lane elegida en la sesión (una
  respuesta de `AskUserQuestion` `="Plan L…"`) es Plan L. Plan S, o un plan sin pregunta de lane, no se
  revisa.
- Las opciones de lane llevan descripciones mínimas: «directo», «plan corto», «plan complejo».
- `config/AGENTS.md`, `config/CLAUDE.md`, `session-start.sh` y `critical-reasoning.sh` repiten la regla.

## Consecuencias

- Un plan que el usuario abre directo, sin pregunta de lane, ya no pasa forzosamente por una entrevista.
  `scripts/test-lane-guard.sh` cubre Plan S, Plan L y el caso en que gana la última lane elegida.
