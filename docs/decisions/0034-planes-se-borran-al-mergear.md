# 0034 — Spec y plan se borran al mergear

Estado: aceptado (2026-11-18). Cambia el punto (c) de los documentos del repo en `config/AGENTS.md`.
Reemplazado en parte por [0052](0052-flujo-de-matt-sin-superpowers.md): la spec y los tickets viven en `.scratch/` local y nunca se commitean, en vez de `docs/superpowers/`.

## Contexto

`docs/superpowers/` guardaba cada spec y plan aprobado para siempre. En este repo se acumularon 11 planes
ya ejecutados (unas 12.300 palabras) que nadie vuelve a leer y que quedan desactualizados frente al código y
a los ADRs.

## Decisión

- La spec y el plan viven en `docs/superpowers/` solo mientras corre el trabajo: el plan aprobado se copia
  ahí antes de implementar y los dos se borran en el merge que termina el trabajo.
- Lo que tenga que sobrevivir al trabajo va a un ADR.
- Se borran los 11 planes ejecutados de este repo; el historial de git los conserva.
- Las plantillas de `project-init` siguen la misma regla en el mismo conjunto de cambios.

## Consecuencias

- `docs/superpowers/` muestra solo el trabajo en curso.
- Un plan viejo se recupera con `git log` / `git show`, no navegando el repo.
- Una decisión que solo quedó en un plan se pierde de la vista si no se pasa a un ADR antes del merge.
