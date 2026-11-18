# 0028 — Se quita la integración con caolg

Estado: aceptado (2026-11-16). Reemplaza ADR 0021 y la parte de «modo CAO» de ADR 0020.

## Contexto

Loren dejó caolg (otro repo que envuelve CAO en tmux para correr un líder con workers entre repos) y pasó a
Orca, que corre el mismo tipo de workers pero deja los repos limpios. agents-config todavía cargaba código que
solo servía bajo caolg, como la clave `agent_providers` de `org.json`.

## Decisión

- `session-start.sh`, `critical-reasoning.sh` e `intent-router.sh` ya no miran `CAO_TERMINAL_ID`: se comportan
  igual en toda sesión. El resto de ADR 0020 (presupuesto de contexto, recordatorio de reasoner una vez por
  sesión, heurística de notificaciones de tareas) sigue.
- `statusline.sh` solo dibuja la línea. Ya no escribe `~/.cache/claude/rate-limits.json` ni
  `~/.cache/claude/ctx/<id>.json`; nada más los leía.
- `gen-cli-baselines.sh` saca el target `opencode-cao` (`~/.aws/opencode`).
- `agent_providers` sale del template de org y del README de organizaciones.
- Se sacan las menciones a caolg de `config/CLAUDE.md`, el perfil y `.agents/CONTEXT.md`. Orca no se nombra en
  su lugar: cómo rutear trabajo a Orca es otra decisión.
- Los ADRs y planes viejos conservan su texto como historia; solo su línea de estado apunta acá.

## Consecuencias

- Una sesión de Claude dentro de un panel de CAO, si se vuelve a usar CAO, recibe el ruteo y los recordatorios
  completos como cualquier otra.
- `CLAUDE_CODE_FORCE_TERMINAL_IMAGES=1` (ADR 0024) sigue: sirve a cualquier sesión dentro de tmux, no solo a
  caolg.
- Los tests de los casos de CAO en `test-intents.sh`, `test-packs.sh` y `test-cli-baselines.sh` se eliminan.
