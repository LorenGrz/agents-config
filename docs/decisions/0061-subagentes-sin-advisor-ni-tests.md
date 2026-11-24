# 0061 — Los subagentes no consultan al advisor y los tests los corre solo el reviewer

Estado: aceptado (2026-11-24). Ajusta 0048 (qué corre cada agente) y 0052 (el `worker` escribe el test primero pero no lo corre).

## Contexto

`advisorModel` en `~/.claude/settings.json` le da el advisor a la sesión principal, y según la doc de Claude Code
los subagentes lo heredan. Los `worker` arrancaban con TDD (test en rojo, código, test en verde) y los líderes
podían correr un test puntual. Las dos cosas hacían lento cada subagente; Loren quiere que trabajen rápido.

## Decisión

- `worker`, `scout`, `reviewer` y `reasoner` no llaman al advisor: lo dice su definición. La doc no documenta cómo
  quitarle la herramienta a un subagente (es una server tool; `tools:` y `disallowedTools` no la nombran), así que
  queda como instrucción. Los líderes, que son sesiones aparte, siguen consultándolo.
- El `worker` y el líder escriben los tests (test primero) pero no corren nada: ni sus tests, ni lint, ni
  typecheck, ni build.
- Los tests y los checks los corre una vez el reviewer Standards, con los comandos del CI; trabajando sola en
  Plan S, la sesión principal al final.

## Consecuencias

- Ya no hay salida en rojo de cada test nuevo: un test que pasa sin el cambio no se detecta antes de la
  revisión. La revisión Spec marca como `major` un cambio de comportamiento sin test escrito.
- Un test que falla aparece recién en la revisión Standards, y el arreglo vuelve al líder o a un `worker`.
- Si un subagente igual llama al advisor, la vía siguiente es cambiar su modelo o pedir el campo a Claude Code.
