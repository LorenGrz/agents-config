# 0033 — Orquestador con workers por capa y reviewer de otro proveedor

Estado: aceptado (2026-11-18). Ajusta 0029 en el transporte del worker en segundo plano. Ajustado por 0036: el
reparto del Plan L pasa a un líder por repo, que sí puede lanzar `worker` y `scout`. Ajustado por 0037: el reviewer
por defecto es un agente Opus y otro proveedor queda a pedido.

## Contexto

Nadie revisaba el código generado contra el pedido original con un modelo distinto del que lo escribió. La
delegación solo estaba escrita para Claude Code CLI (ADR 0029), y un hijo de `delegate_task` es una sesión
nueva: `session-start.sh` le inyecta la pregunta de lane y puede frenarlo.

## Decisión

- Plan L: un worker por repo o capa, en paralelo, cada uno en su worktree. El orquestador escribe los
  briefs, integra y commitea; no escribe código.
- Un reviewer de otro proveedor, nombrado en el perfil (Gemini 4 Argon para Loren, reemplazo `reasoner`),
  revisa el diff antes de cada PR y antes del merge que cierra un Plan L: solo lee y corre checks, con una
  sola re-revisión. El brief y el ciclo de hallazgos están en la skill `review-handoff`.
- Transporte por harness, para el worker y para el reviewer: Claude Code usa `worker` en segundo plano y
  `gemini-delegate`; T3 Code usa `delegate_task` para los dos; Orca usa workers de Orca (`orchestration`).
- Un agente lanzado con un brief lo ejecuta: sin pregunta de lane ni subagentes propios.
- Descartado: un subagente `config/agents/reviewer.md` (solo existe en Claude Code) y ponerlo todo en
  `config/CLAUDE.md` (ya pasa el tope del ADR 0004).

## Consecuencias

- Cada revisión gasta cuota de Gemini.
- El transporte de Orca está escrito pero no verificado.
- «Nunca edita» no lo impone el harness: se controla comparando `git status` y `HEAD` antes y después.
