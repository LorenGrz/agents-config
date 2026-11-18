# 0037 — El reviewer es un agente Opus; otro proveedor, solo a pedido

Estado: aceptado (2026-11-18). Ajusta 0033 (reviewer de otro proveedor) y 0031 (Plan S sin subagentes).

## Contexto

El ADR 0033 puso como reviewer a un modelo de otro proveedor (Gemini 4 Argon por `agy`). En un día de
trabajo con una revisión y una re-revisión por rama se gastó casi toda la cuota semanal de Gemini, y Loren
pidió el 2026-11-18 que revise un agente Opus y que el otro proveedor quede opcional. En el mismo pedido
resolvió que el Plan S pueda lanzar subagentes cuando el trabajo los pida.

## Decisión

- El reviewer por defecto es un agente aparte del que escribió el código: para Loren, un subagente
  `reasoner` nuevo (Opus en esfuerzo alto). Sigue revisando antes de cada PR y antes del merge de un Plan L,
  sin editar, con una sola re-revisión. Puede correr en cualquier lane.
- Un modelo de otro proveedor (Gemini por `agy`, Codex por `codex-review`) revisa solo cuando el usuario lo
  pide. Si ese proveedor no está disponible, revisa el reviewer por defecto y se avisa en una línea.
- La skill `review-handoff` lleva los dos caminos; el modelo sale del perfil.
- Plan S: sigue sin entrevista, sin brainstorming y sin specs, y lanza `worker` o `scout` solo cuando el
  trabajo los necesita.

## Consecuencias

- La revisión deja de gastar cuota de otro proveedor, a cambio de perder la mirada de un modelo distinto:
  el reviewer y el autor son la misma familia de modelo, en contextos separados.
- Las revisiones corren sobre la cuota de Anthropic.
- `gemini-delegate` y `codex-review` quedan como herramientas a pedido.
