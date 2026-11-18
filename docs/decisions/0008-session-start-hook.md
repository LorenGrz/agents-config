# 0008 — Hook SessionStart para el ruteo y el mapa del código

Estado: aceptado (2026-10-23).

## Contexto

Las reglas en prosa de `CLAUDE.md` pierden contra los defaults del harness (como "don't spawn subagents unless
asked") y se diluyen en sesiones largas, así que el ruteo de ADR 0006 se ignoraba seguido. Además los repos
grandes se exploran de cero si `.agents/CONTEXT.md` falta o está desactualizado.

## Decisión

- Un hook `SessionStart`, `config/hooks/session-start.sh` (registrado en `config/settings.base.json` y
  `hooks/hooks.json`), que:
  - reinyecta la regla de ruteo de agentes como `additionalContext` en cada inicio de sesión;
  - en repos git con al menos 200 archivos versionados (`AGENTS_MAP_MIN_FILES`), sugiere correr la skill
    `repository-context-maintainer` cuando `.agents/CONTEXT.md` falta o está 30 commits o más detrás de HEAD
    (`AGENTS_MAP_STALE_COMMITS`); si no, dice que se lea.
- Es un sustituto barato de graphify: sin grafo de dependencias ni de llamadas, solo el mapa en prosa que
  mantiene la skill.

## Consecuencias

- Unos 60 tokens de contexto por sesión; umbrales ajustables por variables de entorno.
- Sigue siendo guía, no imposición: el modelo lo puede ignorar.
