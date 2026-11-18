# 0015 — Guarda de filtraciones y archivos de plugin generados

Estado: aceptado (2026-11-04).

## Contexto

Los datos de una organización no pueden llegar a este repo público, y `plugin.json`/`hooks.json` se habían
desviado de sus fuentes (skills de proyecto exportadas como globales).

## Decisión

- `scripts/leak-guard.sh` falla con archivos versionados bajo `organizations/` (salvo README y `_template`),
  con términos de una blocklist **local** (`~/.config/agents-config/blocklist`, armada por `orgs.sh` con el
  nombre, los términos y los owners de GitHub de cada `org.json`; un secreto `LEAK_BLOCKLIST` en CI) y con
  secretos obvios.
- Revisa nombres de archivo, contenido (binarios incluidos), renombres y mensajes de commit, en los hooks
  `pre-commit` (staged), `commit-msg`, `pre-push` (el árbol más los commits que se pushean) y en CI (el árbol
  más el rango pusheado).
- Nunca imprime un término: una ruta que contiene uno se redacta, y en CI se redactan todas.
- `scripts/gen-plugin.sh` deriva las skills de `plugin.json` (todo lo que no es de proyecto) y
  `hooks/hooks.json` (desde `settings.base.json`, sin los hooks propios de la máquina); `--check` corre en
  pre-commit y en CI.
- El hook pre-commit necesita `git config core.hooksPath .githooks`.

## Consecuencias

- La blocklist protege solo lo listado: los nombres renombrados o abreviados pasan, y el historial ya pusheado
  queda fuera de alcance. `org-creator` pide los términos.
- Sin blocklist, la guarda avisa en local y falla en CI.
