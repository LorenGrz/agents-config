# 0051 — Contexto de sesión nueva sin duplicados

Estado: aceptado (2026-11-20). Reemplaza la repetición del ruteo en `session-start.sh` de 0008, 0022 y 0025.

## Contexto

Una sesión nueva en la carpeta de un producto de una org arrancaba con unos 75 KB de instrucciones, unos 20 KB
repetidos o ajenos:

- las políticas de la org entraban dos veces (bloque global y carpeta del producto), y en todos los proyectos;
- el hook de inicio repetía la regla de carriles de `AGENTS.md` y `CLAUDE.md`;
- el perfil y `CLAUDE.md` repetían reglas de `AGENTS.md`;
- `claude-obsidian` se cargaba en todos los proyectos;
- el router nunca elegía la skill de la org: buscaba en `organizations/<org>/skills`, y hay orgs que las tienen por
  producto (`organizations/<org>/<producto>/skills`).

## Decisión

- **Hook de inicio:** no repite el ruteo; la regla vive solo en `AGENTS.md` y `CLAUDE.md`. Dentro de una carpeta
  workspace (el padre del repo tiene `AGENTS.md`) tampoco empuja `CONTEXT.md` ni `project-init`.
- **Router (`intent-router.sh`):**
  - busca la skill de reemplazo también en `organizations/<org>/*/skills`;
  - en una carpeta sin `origin` toma la org del primer repo hijo.
- **Perfil y `CLAUDE.md`:** dejan solo lo propio (modelos, mecánica de Claude) y apuntan a `AGENTS.md` para lo
  demás.
- **`claude-obsidian`:** apagado global; se prende por proyecto en su `.claude/settings.json` (`enabledPlugins`;
  hoy, solo el vault).
- **Org instalada global:** las skills y los comandos de la org van en `~/.claude` sin el bloque de políticas (las
  sesiones que arrancan dentro de un repo no leen las skills de la carpeta padre); las políticas entran solo por la
  carpeta del producto.

## Consecuencias

- Si la regla de carriles vuelve a perderse contra el default del harness, la vuelta atrás es la línea del hook,
  no más prosa.
- Las skills de `claude-obsidian` no están fuera del vault.
