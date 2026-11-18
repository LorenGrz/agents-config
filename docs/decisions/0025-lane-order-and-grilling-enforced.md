# 0025 — Orden de las lanes y entrevista de grilling, impuestos por un hook

Estado: aceptado (2026-11-13). Enmienda ADR 0022 («la regla vive en `config/CLAUDE.md`, no en un hook») en
estos dos puntos.

## Contexto

El 2026-11-13 el agente puso primero la recomendada (Plan S) pese al orden de ADR 0022: la descripción de
`AskUserQuestion` dice "put the recommended option first" y ganó. Ese día Loren pidió una entrevista
obligatoria antes de todo plan, hasta no dejar nada por suponer; `mattpocock-skills:grilling` ya la hace.

## Decisión

- `config/hooks/lane-guard.sh`, registrado como PreToolUse en `AskUserQuestion|ExitPlanMode`:
  - **AskUserQuestion:** si las opciones de una pregunta nombran lanes, tienen que ser exactamente Continuar,
    Plan S, Plan L, en ese orden. Si no, la llamada se niega (exit 2) con el motivo.
  - **ExitPlanMode:** el transcript tiene que mostrar `mattpocock-skills:grilling` cargado (como llamada a
    Skill o como slash command) después del último `EnterPlanMode`. Si el plan mode se abrió a mano (sin
    llamada a `EnterPlanMode`), cuenta cualquier grilling anterior de la sesión. Si no, la llamada se niega.
  - No revisa subagentes, y deja pasar la llamada cuando no puede leer el transcript.
- El flujo (lanes y entrevista) pasa a `config/AGENTS.md` "Workflow lanes", neutral respecto del agente,
  porque es como Loren trabaja con cualquiera; `config/CLAUDE.md` deja solo la mecánica de Claude Code
  (`AskUserQuestion`, `EnterPlanMode`, PonyTail, el hook). Primero el grilling, después el plan. En Plan L
  sigue `brainstorming` sin volver a preguntar lo ya respondido; ese orden fue una suposición que se le
  declaró a Loren al hacer el cambio.
- Los recordatorios de `critical-reasoning.sh` y `session-start.sh` repiten las dos reglas.

## Consecuencias

- El orden y la entrevista ya no se pueden saltear en silencio: una llamada negada vuelve al agente con el
  motivo, y el agente reintenta.
- Cada entrevista cuesta unos 1–2k tokens al cargar la skill, más las preguntas.
- El hook depende del formato del transcript de Claude Code (JSONL con bloques `tool_use`). Si cambia, el
  chequeo de ExitPlanMode falla cerrado y niega todo plan hasta que se arregle el hook.
- Verificado con `scripts/test-lane-guard.sh` (15 casos sin red).
