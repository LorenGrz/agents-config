# 0004 — Presupuesto de tokens para los archivos que cargan siempre

Estado: aceptado (2026-10-10). Presupuesto revisado en ADR 0020 (2026-11-09): ≤60 líneas y ≤4.2 KB, porque el
objetivo de 3.1 KB ya no entra con las reglas que el archivo tiene que llevar.

## Contexto

`config/CLAUDE.md` carga al inicio de cada sesión de Claude Code, en cada proyecto. Tenía 63 líneas / 5879
bytes y duplicaba `config/AGENTS.md` (que importa con `@`): una sección "Roadmap" completa, un texto largo de
Orchestrator mode y una tabla de Agent Routing vieja, sin la regla de ADR 0003.

## Decisión

- `config/CLAUDE.md` se trata como presupuesto de tokens: objetivo ≤60 líneas.
- Queda solo lo específico de Claude Code que se usa en cada sesión: el import `@AGENTS.md`, un párrafo corto
  de ubicación de skills y workflow, la lista de ruteo de skills y la sección Agent Routing reescrita.
- El detalle que se usa poco va a lo que describe, cargado a pedido: el roadmap completo pasa de la sección
  "Roadmap" de `AGENTS.md` a `meta/roadmap-coach/references/roadmap-detail.md` (reference de la skill
  `roadmap-coach`); `AGENTS.md` deja un puntero de 2 líneas.
- `CLAUDE.md` no repite nada de `AGENTS.md`: suma, nunca copia.
- Resultado: `config/CLAUDE.md` pasó de 63 líneas / 5879 bytes a 48 / 3124; `config/AGENTS.md`, de 107 / 6986
  a 93 / 6741 (ganó una regla corta de la capa de docs y perdió el roadmap).

## Consecuencias

- La skill roadmap-coach es la única fuente del detalle del roadmap: se actualiza ahí cuando cambia la etapa.
- Antes de agregar algo a `CLAUDE.md` se pregunta si aplica a todas las sesiones; si no, va a una skill, rule
  o reference cargada a pedido.
