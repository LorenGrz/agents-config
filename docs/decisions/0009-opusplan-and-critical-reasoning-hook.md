# 0009 — `opusplan` como modelo por defecto y un hook de razonamiento crítico

Estado: aceptado (2026-10-31). La elección de modelo la reemplaza
[0018](0018-opus-medium-default-reasoner-high.md); el hook sigue.

## Contexto

ADRs 0003 y 0006 suponían una sesión principal en Opus que delega lo mecánico, pero seguía buscando y editando
inline, y las reglas en prosa perdían contra el default del harness. Pedirle al usuario que cambie de modelo a
mano no escala.

## Decisión

- **Modelo por defecto `opusplan`** (`config/settings.base.json`): Opus en plan mode, Sonnet para todo lo
  demás. Los planes los hace siempre Opus sin cambio manual; la ejecución es barata por defecto.
- **`config/hooks/critical-reasoning.sh`** en `UserPromptSubmit` y `PreToolUse(Edit|Write|MultiEdit)`: si el
  prompt o el archivo parece caro de errar (arquitectura, seguridad, migraciones, prod, IAM, CI, bugs de causa
  desconocida) inyecta `additionalContext` para que la sesión principal delegue la decisión a `reasoner`
  (Opus). Calla dentro de subagentes y siempre sale con 0.
- El método marketplace también lleva el hook (`hooks/hooks.json`) pero no puede fijar el modelo: `opusplan`
  llega solo por `install.sh`.

## Consecuencias

- Un hook no puede cambiar el modelo: es un empujón, no una imposición. Si resulta flojo, el paso siguiente es
  un `PreToolUse` más estricto que pregunte antes de ediciones sensibles de la sesión principal.
- Las listas de palabras y rutas son heurísticas: habrá falsos positivos (baratos) y omisiones.
- Quien quiera otro modelo lo cambia en `config/settings.base.json` de su clon: en el merge de `install.sh` la
  base gana para `model`, así que editar `~/.claude/settings.json` se pisa en la siguiente corrida.
