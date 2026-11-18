# 0020 — Hooks que reconocen CAO, presupuesto de contexto y lanes de trabajo

Estado: aceptado (2026-11-09); el «modo CAO» lo elimina ADR 0028.

## Contexto

Los hooks corrían también en los agentes que caolg lanza por CAO y contradecían sus perfiles (subagentes,
`project-init`, `git-workflow` ante un `git commit`). Saltaban además en las notificaciones de tareas, sin
tope, y `config/CLAUDE.md` había vuelto a 5.9 KB / 73 líneas (sesión limpia: ~15–18k tokens fijos).

## Decisión

- **Modo CAO.** Con `CAO_TERMINAL_ID` definido (CAO lo pone en cada panel; nada distingue líder de worker):
  `session-start.sh` y `critical-reasoning.sh` callan; `intent-router.sh` rutea solo las herramientas MCP de
  integración (`mcp__*`), no las frases del prompt (el prompt de un worker es el texto de la asignación) ni
  `Bash`.
- **`critical-reasoning.sh`**: el recordatorio de `reasoner` va una vez por sesión cuando hay `session_id`
  (mismo directorio de marcadores que el router de intenciones); calla en plan mode
  (`permission_mode == "plan"`, que ya decide) y en prompts que parecen notificaciones de tareas; el texto
  nombra al `reasoner` de esfuerzo alto (ADR 0018) en vez de "Sonnet". La sugerencia de skill desde
  `.agents/critical.json` no cambia y no tiene tope.
- **Notificaciones de tareas**: se reconocen por heurística (`<task-notification>` o un `[system notification`
  al inicio), porque Claude Code no documenta un campo que las distinga de un prompt del usuario. Si lo
  agrega, se reemplaza la heurística.
- **Presupuesto de `config/CLAUDE.md`: ≤60 líneas, ≤4.2 KB** (era 73 / 5.9 KB; los 3.1 KB de ADR 0004 ya no
  entran con las reglas que tiene que llevar). Se saca la lista de skills que repetía sus descripciones y
  nombraba skills no globales; el ruteo se dice una vez; `session-start.sh` apunta a él en una línea corta.
- **Lanes de trabajo** en `config/CLAUDE.md`. Lane S (causa conocida, ≤3 archivos, sin decisión de contrato,
  schema, migración, auth o arquitectura): inline, test enfocado, el check más chico, sin brainstorming, sin
  plan en docs, sin subagentes. Lane L (todo lo demás): brainstorming, writing-plans, `worker`/`reasoner`, o
  caolg entre repos. Causa desconocida: primero `systematic-debugging`. El plan mode termina con "Lane S/L
  because …". Las instrucciones del usuario pisan el proceso propio de una skill, así que lane S saltea
  brainstorming.
- **PonyTail** (`DietrichGebert/ponytail`, un plugin que empuja al agente a reusar código) se nombra como
  ayuda opcional para lane S. Este repo **no lo instala ni lo activa**: inyecta texto en cada turno con hooks
  de Node y sus ahorros publicados son autodeclarados. Se prueba primero en un proyecto, midiendo lo que suma
  por turno, antes de decidir entre alcance global o por stack.
- Este cambio no desactiva ningún plugin.

## Consecuencias

- Los tests de cada regla están en `scripts/test-intents.sh` y `scripts/test-packs.sh`.
- `install.sh` solo agrega a `enabledPlugins`: un plugin que se saca del archivo base sigue prendido en
  `~/.claude/settings.json`, salvo que la base lo ponga en `false` (como con vercel y playwright).
- No verificado: si la salida de `SessionStart` y `UserPromptSubmit` llega a los subagentes (no está
  documentado).
