# 0018 — Opus con esfuerzo medio por defecto; planificar en alto con `reasoner`

Estado: aceptado (2026-11-09). Reemplaza la elección de modelo de
[0009](0009-opusplan-and-critical-reasoning-hook.md) (el hook de razonamiento crítico de 0009 sigue). El
esfuerzo medio lo reemplaza [0024](0024-opus-high-effort-and-terminal-images.md): la sesión principal corre en
alto.

## Contexto

El dueño quiere la sesión principal en Opus con esfuerzo **medio** y planificar en **alto**, pero Claude Code
no tiene esfuerzo por modo: `effortLevel` y `modelSettings.<model>.effortLevel` son por modelo, y con
`model: opus` el plan mode comparte el esfuerzo de la sesión.

## Decisión

- `config/settings.base.json`: `"model": "opus"`, `"effortLevel": "medium"` y
  `modelSettings.claude-opus-5-5.effortLevel = "medium"`. La entrada por modelo es la que cuenta: según la
  documentación, Opus 5.5 y posteriores ignoran un `effortLevel` de nivel superior en los settings de usuario,
  y el `effortLevel` propio de un modelo gana sobre el de nivel superior en el mismo archivo.
- Merge de `install.sh`: la base gana en `model`, `effortLevel` y las claves de `modelSettings` que define (un
  `high` local viejo para Opus se reemplaza); los `modelSettings` de otros modelos se conservan.
- Planificar con esfuerzo alto va por el subagente `reasoner` (Opus), cuyo frontmatter lleva `effort: high`
  (documentado: pisa el esfuerzo de la sesión; `CLAUDE_CODE_EFFORT_LEVEL` igual gana). El plan mode nativo
  queda con el esfuerzo de la sesión (medio); se sube a mano con `/effort high` para un plan difícil.

## Consecuencias

- La clave de `modelSettings` es el nombre canónico del modelo (`claude-opus-5-5`): cuando salga un Opus
  nuevo, se agrega su clave a la base o arranca con su propio default.
- El método marketplace no puede fijar modelo ni esfuerzo: los dos llegan solo por `install.sh`.
- Si Claude Code suma un esfuerzo por modo, se pasa a él y se reemplaza este ADR.
- El texto de ruteo (`config/CLAUDE.md`, `session-start.sh`, perfil) ya no dice «Sonnet vía `opusplan`»:
  `worker` (Sonnet) implementa, y la sesión principal (Opus) delega e informa.
