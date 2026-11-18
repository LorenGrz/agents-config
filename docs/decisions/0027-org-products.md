# 0027 — Organizaciones con productos

Estado: aceptado (2026-11-13). Se apoya en ADR 0012 (organizaciones) y 0026 (repos de org autosuficientes).

## Contexto

Una organización puede tener varias líneas de producto con stacks y equipos distintos. Su repo guardaba todas
las skills en un `skills/` plano, así un proyecto de un producto recibía también las del otro.

## Decisión

- **`products` en `org.json`** (opcional): `{"<product>": {"remote_patterns": [regex, ...]}}`. Con él, cada
  producto tiene su carpeta `<product>/` con `skills/`, `commands/` y un `POLICIES.md` completo. El
  `POLICIES.md` raíz sigue: es el núcleo de toda la org que importan el índice global y `~/.claude`.
- **`orgs.sh validate`** revisa cada carpeta de producto (existe, tiene `POLICIES.md`, skills y comandos bien
  formados, sin debilitar el baseline) y acepta un destino de `replaces` que exista en cualquier producto.
- **`project-agents.sh`** acepta `--product <name>`, o elige el producto cuyos patrones coinciden con el
  `origin` del proyecto (en una carpeta workspace, con los de sus repos hijos). Si no hay una sola
  coincidencia, falla cerrado con la lista de productos. Lo demás (filtros de stack, `replaces`, filas de
  índice y críticas) funciona sobre el producto elegido como antes sobre la raíz de la org.
- Cómo mantiene una org sincronizadas las copias de sus skills comunes entre productos es asunto del repo de
  la org (la forma esperada es un script de sync con `--check`); el hub lee solo las carpetas de producto.
- Descartado: partir la org en dos repos, porque duplicaría las políticas comunes y las skills de herramientas
  (GitHub, tracker, chat), que terminarían divergiendo.
- La plantilla de POLICIES de ADR 0026 aplica al `POLICIES.md` de cada producto; el raíz lleva el resumen, el
  núcleo y la sección de proyecto, sin secciones de producto.

## Consecuencias

- Una org sin `products` funciona igual que antes.
- Un proyecto o workspace cuyos remotos no coinciden con ningún producto (o con varios) tiene que pasar
  `--product`.
- `.agents/skills.lock` registra el nombre y la versión de la org, no el producto; los archivos instalados
  muestran cuál es.
