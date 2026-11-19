# 0040 — Siempre se pregunta el carril y después Continuar · Orquestar

Estado: aceptado (2026-11-19). Ajusta 0022 (qué va directo) y 0039 (cuándo se pregunta Orquestar).

## Contexto

Con 0022 un cambio puntual (un archivo, intención clara) se hacía directo, sin preguntar. Con 0039 la
pregunta Continuar · Orquestar solo aparecía con más de una rama de tarea. Así, un ticket de un solo repo
lo resolvía siempre la sesión principal, y Loren no podía elegir mandarlo a un líder en su worktree, con las
skills de ese repo. Loren pidió que la decisión sea siempre suya: que se pregunte el carril en toda tarea y
que después venga siempre Continuar · Orquestar. Las dos preguntas valen para todos los proyectos, no solo
para las organizaciones.

## Decisión

- Solo un cambio trivial (una línea o un typo) se hace directo. Toda otra tarea, aunque sea de un archivo,
  arranca con la pregunta de carril: Continuar · Plan S · Plan L.
- Después de la pregunta de carril va siempre la de Continuar · Orquestar, sin importar cuántas ramas
  haya. Puede ir como segunda pregunta del mismo `AskUserQuestion`. Con más de una rama se recomienda
  Orquestar. Con una sola, la recomendación depende del tamaño del trabajo y lleva una línea de por qué.
- Elegir Orquestar no cambia: `orquestar.sh` inyecta el procedimiento fijo de 0039, con un líder por rama
  como sesión aparte.
- `session-start.sh` repite la regla corta. `lane-guard.sh` ya aceptaba la pregunta Continuar · Orquestar
  y no cambia.

## Consecuencias

- Hay una pregunta más en cada tarea no trivial, también en las chicas. A cambio, cualquier ticket puede ir a
  un líder en su worktree.
- La pregunta no la impone un hook: un agente que la saltea no queda bloqueado. Si pasa seguido, se puede
  agregar un hook que la exija antes del primer `Edit` o `Write`.
