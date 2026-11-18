# 0006 — La sesión principal delega las búsquedas abiertas y los cambios grandes

Estado: aceptado (2026-10-23). Reemplazado en parte por [0009](0009-opusplan-and-critical-reasoning-hook.md) y
luego [0018](0018-opus-medium-default-reasoner-high.md): la sesión principal corre en Opus con esfuerzo medio
y las decisiones profundas van a `reasoner` (esfuerzo alto).

## Contexto

ADR 0003 permitía saltear subagentes con ≤3 archivos conocidos y, sumado al default del harness de no lanzar
agentes sin pedido, Opus terminaba buscando y escribiendo inline (el 2026-10-23, 6 búsquedas para investigar
un plugin).

## Decisión

- La sesión principal (Opus) decide, escribe specs, revisa resultados e informa.
- Búsquedas abiertas (rutas que no se conocen, recorrer directorios o caches, búsqueda web, docs) → `scout`,
  con una pregunta concreta. Leer un archivo conocido para decidir sigue inline.
- Cambios grandes (más de 3 archivos, o escritura masiva o mecánica) → `worker`, con la spec decidida, los
  archivos exactos y un comando de aceptación. Los cambios chicos a ≤3 archivos conocidos siguen inline.
- Decisiones caras de errar → `reasoner` o la sesión principal, nunca `worker`/`scout`.
- Las subtareas independientes se despachan en paralelo, en un solo mensaje.
- Es una instrucción permanente del usuario y pisa el default del harness.
- Conserva la regla de 0003 de «≤3 archivos conocidos inline» para escribir, limitada a archivos conocidos.
- Descartado: delegar *toda* edición (primera versión del mismo día), porque el arranque en frío de un
  subagente cuesta más que una edición chica a un archivo conocido.

## Consecuencias

- Opus no gasta tokens en búsquedas abiertas ni en escritura masiva, y las ediciones chicas siguen sin
  arranque en frío.
- La sesión principal tiene que escribir specs claras para lo que delega.
