# 0003 — Ruteo de modelos por complejidad de la tarea, no por costumbre

Estado: aceptado (2026-10-10). Reemplazado en parte por [0009](0009-opusplan-and-critical-reasoning-hook.md) y
luego [0018](0018-opus-medium-default-reasoner-high.md): la sesión principal corre en Opus con esfuerzo medio
y las decisiones profundas van a `reasoner` (esfuerzo alto). [0006](0006-always-delegate.md) acota la regla de
«≤3 archivos conocidos inline»: vale solo para archivos conocidos; las búsquedas abiertas van a `scout`.
Ajustado por [0052](0052-flujo-de-matt-sin-superpowers.md): `worker` = Opus.

## Contexto

Hay tres subagentes con modelo fijo (`scout` = Haiku, `worker` = Sonnet, `reasoner` = Opus,
`config/agents/*.md`) y superpowers despacha subagentes en `subagent-driven-development`, `executing-plans`,
`dispatching-parallel-agents` y `requesting-code-review`. Sin regla, todo iba a Opus o todo a Sonnet.

## Decisión

- Se rutea por lo que hace el paso, no por qué agente es «mejor»:
  - **Opus** (sesión principal / `reasoner`) solo razona y decide: arquitectura, bugs de causa desconocida,
    revisión de planes, decisiones difíciles de revertir. No hace escritura de worker.
  - **Sonnet** (`worker`) escribe todo el código y la documentación de un plan ya decidido.
  - **Haiku** (`scout`) hace solo búsquedas livianas de lectura.
- El `subagent_type` de superpowers sigue el mismo reparto: tareas de implementer → `worker`; revisores de
  spec y de calidad → `worker` para lo rutinario, `reasoner` solo si el cambio es crítico en seguridad o
  arquitectura; búsquedas de archivos e inventarios → `scout`.
- Un cambio de ≤3 archivos conocidos se hace inline, sin subagente: sale más barato que su arranque en frío.
- Queda en la sección "Agent Routing" de `config/CLAUDE.md` (corta, carga en cada sesión), sin duplicarla en
  `AGENTS.md`, que ya lleva las reglas de orquestación para Codex.

## Consecuencias

- Se puede predecir qué modelo usa cada despacho, y Opus se gasta en decisiones, no en escritura mecánica.
- Si un `worker` falla su check de aceptación dos veces, o la primera hipótesis de un revisor no se reproduce,
  se escala a `reasoner` en vez de reintentar en el mismo nivel (regla de escalado de "Agent Routing", sin
  cambios).
