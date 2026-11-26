# 0064 — Orquestar: los líderes se cierran solos y Orca ordena lo que depende

Estado: aceptado (2026-11-26). Ajusta 0039 (transporte y orden de los líderes).

## Contexto

Desde el 2026-11-17, Orca registró 67 workers lanzados con `orchestration worker-start`, ninguno se cerró
solo y ninguna tarea usó dependencias. El procedimiento de `orquestar.sh` lanzaba cada líder con
`--keep-open`, que apaga el cierre automático de Orca: el 2026-11-26 quedaban tres sesiones de líderes sin
uso desde hacía 16 a 17 horas en los worktrees de dos PR. El orden back → front lo llevaba la sesión
principal a mano. Además, `orquestar.sh` decía que el front espera el commit del contrato y `cx-orquestar`
que arranca a la par con el contrato del brief.

Según la guía de Orca (`orca skills get orchestration`), un worker que reporta se cierra solo, y
`orchestration send --to dispatch:<id>` lo reabre con su contexto, así que dejarlo abierto no hace falta
para mandarle los arreglos de la revisión.

## Decisión

- El líder se lanza sin `--keep-open` y se cierra solo al reportar. La sesión principal guarda su
  `dispatch_id` y le manda los arreglos con `orchestration send --to dispatch:<id>`. `--keep-open` queda
  para cuando el usuario quiere seguir charlando con ese líder.
- El front arranca a la par del back, contra el contrato escrito en su brief (Loren, 2026-11-26).
- Cuando el contrato no se puede escribir de antemano, el orden lo lleva Orca: un Run, una tarea por líder
  y la dependiente con `--deps`; al despertar, la sesión principal lanza las tareas que pasaron a listas.
- Los worktrees los siguen creando los scripts de cada repo (en CX, `cx-worktree`): copian el `.env`,
  instalan con el comando del CI y generan Prisma, cosa que `worker-start --worktree new-*` no hace.

## Consecuencias

- Menos sesiones abiertas y menos memoria; nada que cerrar a mano después de orquestar.
- Si `send` no puede reabrir un líder (por ejemplo, se borró el worktree), el recibo lo dice y se lanza
  uno nuevo con el brief y el arreglo.
- `scripts/test-orquestar.sh` verifica que el procedimiento no pida `--keep-open` por defecto, que use
  `send` y que nombre `--deps`.
