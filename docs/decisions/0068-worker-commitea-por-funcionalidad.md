# 0068 — El worker commitea en su rama, un commit por funcionalidad

Estado: aceptado (2026-11-27). Reemplaza la regla «el worker no commitea; commitea quien lo lanzó» (0052, 0061 y
el brief de `cx-orquestar`). Se apoya en 0066 para el `ask` de `git commit` de los repos de la org.

## Contexto

Loren quiere que los subagentes (`worker` y líderes) commiteen a medida que agregan cada funcionalidad, en vez de
dejar todo el diff sin commitear para que lo commitee la sesión que los lanzó. Un diff grande commiteado de una vez
mezcla funcionalidades y la historia del PR no se puede leer por partes.

## Decisión

- El `worker` commitea en su rama un commit por funcionalidad agregada, apenas esa funcionalidad está hecha (test,
  código y doc juntos), con título Conventional Commits en el idioma del repo. Nunca pushea, ni hace amend, ni usa
  `--no-verify`, ni commitea en `main`, `master` o `dev`.
- `git add` va en un comando y `git commit -q -m … -m …` solo en el suyo, en una línea: es la forma que 0066 deja
  pasar el `ask` de un repo sin diálogo.
- Quien lanzó el worker revisa el diff de esos commits; en Plan L, el líder mergea la rama del worker a la de la
  tarea. El push y el PR siguen siendo de la sesión principal.
- En la org, el brief de su skill de orquestación dice lo mismo para el worker y para el líder de repo.

## Consecuencias

- La historia de cada PR queda partida por funcionalidad.
- Un subagente in-process (herramienta Agent) en un repo con `ask` de `git commit` sigue viendo el diálogo: 0066
  cubre solo a los workers de Orca. En los repos de la org se pidió al equipo sacar `git commit *` del `ask`
  de su `.claude/settings.json` (2026-11-27); hasta entonces, la sesión principal aprueba cada commit.
- Un arreglo de la revisión va como commit nuevo, nunca como amend.
