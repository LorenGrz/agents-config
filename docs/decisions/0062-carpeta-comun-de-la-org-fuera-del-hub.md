# 0062 — Una carpeta común de la org que el hub valida pero no copia

Estado: aceptado (2026-11-25). Suma el campo `shared` al contrato de `org.json` (`organizations/README.md`).

## Contexto

Una org con `products` tenía todo por producto: las skills comunes (git, tracker, chat) iban copiadas en la
carpeta de cada producto, y un script las mantenía iguales. Las copias llegaban a cada repo y a cada carpeta
que agrupa repos, y se desincronizaban entre instalaciones: un agente leía una política vieja en un lugar y la
nueva en otro. Además, los permisos y hooks de una carpeta no se heredan a sus repos hijos, así que las guardas
de la org no corrían donde más se trabaja.

La org pasó lo común a un plugin de Claude Code instalado a nivel usuario: una sola copia, con hooks que corren en
cualquier carpeta. `orgs.sh validate` buscaba los destinos de `replaces` solo en las carpetas de producto y dejó
de validar la org.

## Decisión

- `org.json` acepta `shared`: el nombre de una carpeta de la org con `skills/` y `commands/` comunes a todos los
  productos.
- `orgs.sh validate` la revisa como a un producto (frontmatter, línea de base) y acepta ahí los destinos de
  `replaces`.
- `project-agents.sh` no la copia: llega por fuera del hub. Un `replaces` que apunta a ella igual saca del
  proyecto el ítem base que reemplaza.

## Consecuencias

- Un proyecto armado con `project-agents.sh --org` sin el plugin instalado no tiene las skills comunes: la org
  documenta cómo instalarlo.
- El `intent-router` ya encontraba los destinos de `replaces` en cualquier subcarpeta de la org, así que no cambia.
