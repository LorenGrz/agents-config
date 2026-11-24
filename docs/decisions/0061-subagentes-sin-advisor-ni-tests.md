# 0061 — Los subagentes no consultan al advisor y nadie más que el orquestador testea

Estado: aceptado (2026-11-24). Ajusta 0048 (qué corre cada agente) y 0052 (el `worker` ya no arranca con TDD).

## Contexto

`advisorModel` en `~/.claude/settings.json` le da el advisor a la sesión principal, y según la doc de Claude Code
los subagentes lo heredan. Los `worker` arrancaban con TDD (test en rojo, código, test en verde) y los líderes
podían correr un test puntual. Las dos cosas hacían lento cada subagente; Loren quiere que trabajen rápido.

## Decisión

- `worker`, `scout`, `reviewer` y `reasoner` no llaman al advisor: lo dice su definición. La doc no documenta cómo
  quitarle la herramienta a un subagente (es una server tool; `tools:` y `disallowedTools` no la nombran), así que
  queda como instrucción. Los líderes, que son sesiones aparte, siguen consultándolo.
- El `worker` no escribe ni corre tests: implementa el código y las docs y devuelve los archivos.
- El líder tampoco escribe ni corre tests (antes, uno puntual).
- Los checks del CI los corre una vez el reviewer Standards; en Plan S sin reviewer, la sesión principal.

## Consecuencias

- Los cambios de comportamiento llegan sin un test nuevo que los cubra; la revisión Spec ya no pide la salida en
  rojo de cada test nuevo. Si hace falta un test, lo pide la sesión principal explícitamente.
- Si un subagente igual llama al advisor, la vía siguiente es cambiar su modelo o pedir el campo a Claude Code.
