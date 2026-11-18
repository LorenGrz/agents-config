# 0037 — El reviewer es un agente Opus; otro proveedor, solo a pedido

Estado: aceptado (2026-11-18). Ajusta 0033 (reviewer de otro proveedor), 0022 y 0023 (Plan S inline, sin
`worker` ni `reasoner`) y 0010 (delegación a Gemini).

## Contexto

El ADR 0033 puso como reviewer a un modelo de otro proveedor (Gemini 4 Argon por `agy`). En un día de
trabajo con una revisión y una re-revisión por rama se gastó casi toda la cuota semanal de Gemini, y Loren
pidió el 2026-11-18 que revise un agente Opus y que el otro proveedor quede opcional. En el mismo pedido
resolvió que el Plan S pueda lanzar subagentes cuando el trabajo los pida.

## Decisión

- El reviewer por defecto es un agente aparte del que escribió el código: el subagente `reviewer`
  (`config/agents/reviewer.md`, Opus en esfuerzo alto, sin herramientas de edición). Sigue revisando antes
  de cada PR y antes del merge de un Plan L, con una sola re-revisión, y corre en cualquier lane. No se usa
  `reasoner` para esto: su definición devuelve un plan y puede editar. Esto revierte un descarte de 0033
  (un subagente `reviewer.md`, «solo existe en Claude Code»): con el reviewer en Opus, T3 Code y Orca lo
  alcanzan con `delegate_task` o un worker de Orca.
- Un líder puede lanzar a su reviewer. Un agente que no puede lanzar ninguno lo dice antes del PR, en vez de
  saltearse la revisión.
- Un modelo de otro proveedor (Gemini por `agy`, Codex por `codex-review`) revisa solo cuando el usuario lo
  pide. Si ese proveedor no está disponible, revisa el reviewer por defecto y se avisa en una línea.
- La skill `review-handoff` lleva los dos caminos; el modelo sale del perfil.
- La delegación de trabajo a Gemini (`gemini-delegate`) también queda manual: solo cuando el usuario la
  pide. Una tarea grande o mecánica no la dispara por sí sola; se sugiere en una línea.
- Plan S: sigue sin entrevista, sin brainstorming y sin specs. Lo ejecuta la sesión principal y lanza
  subagentes solo cuando el trabajo los necesita.

## Consecuencias

- La revisión deja de gastar cuota de otro proveedor, a cambio de perder la mirada de un modelo distinto:
  el reviewer y el autor son la misma familia de modelo, en contextos separados.
- Las revisiones corren sobre la cuota de Anthropic.
- `gemini-delegate` y `codex-review` quedan como herramientas a pedido; nada gasta cuota de Gemini sin que
  Loren lo pida.
