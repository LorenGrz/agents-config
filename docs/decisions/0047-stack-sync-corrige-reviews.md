# 0047 — stack-sync abre un Claude para corregir lo que pide una review

Estado: aceptado (2026-11-20). Ajustado por 0058.

## Contexto

El 2026-11-20 llegó una review con cambios pedidos en el #493 de CX (un badge armado a mano, un test que pasó de
CRLF a LF y una línea vieja en la descripción). Loren pidió que, con Orca abierto, una review en sus PR abra sola
una sesión que la corrija, como ya pasa con los conflictos. Una review nueva cambia el `updated_at` del PR, así
que el precheck con ETag de 0045 ya la detecta sin consultas de más.

## Decisión

- La lista de PR abiertos trae también `author` y `reviews`. Por cada PR propio, la review más nueva de otra
  persona en estado `CHANGES_REQUESTED` o `COMMENTED` abre un Claude en el worktree del PR con
  `orca agent launch --worktree path:<worktree>`, una vez por review (marca `review-<repo>-<pr>-<id>`).
- Va después de la sincronización con la base, para que el agente arranque sobre la rama al día. Si en esa
  corrida el PR tiene un agente de conflicto abierto, no se abre el de review: la próxima corrida lo abre.
- El brief: leer la review y los comentarios en líneas, cada punto como commits nuevos, conservar los fines de
  línea de cada archivo (`git diff --numstat` contra `--ignore-cr-at-eol`), solo lint de lo tocado y los tests
  relacionados, push sin force. No contesta ni resuelve la review, no vuelve a pedirla, no edita el PR (un cambio
  de título o descripción lo deja escrito) y no toca Jira ni Slack. Deja punto por punto qué cambió y qué no.
- Valen las mismas condiciones que para mergear: un worktree con cambios sin commitear o fuera de la punta del
  PR se saltea, y la review se toma cuando quede limpio. Un PR con review y sin worktree local se avisa una vez.

## Consecuencias

- Una review se empieza a corregir en hasta 2 minutos, dentro del horario de la automatización y con Orca abierto.
- Una review que solo comenta (por ejemplo, un «está bien») también abre un agente; si no hay nada que cambiar,
  lo dice y no commitea.
- Los comentarios sueltos del PR: ver 0058.
