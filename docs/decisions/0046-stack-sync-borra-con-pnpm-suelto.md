# 0046 — stack-sync borra el worktree mergeado aunque tenga los archivos de pnpm

Estado: aceptado (2026-11-19). Ajusta 0045.

## Contexto

El 2026-11-19 se mergearon el #487 (front) y el #506 (back) de CX, y sus worktrees quedaron. El log de
`stack-sync` repetía «no pude borrar» cada 2 minutos desde el merge. La causa era la misma que en 0041: un
`pnpm-lock.yaml` y un `pnpm-workspace.yaml` sin trackear, que `pnpm` deja en repos cuyo lockfile es
`package-lock.json`. El chequeo de limpieza los ignora (`--untracked-files=no`), pero `git worktree remove`
sin `--force` se niega a borrar un worktree con archivos sin trackear. El error iba solo al log, así que
nadie lo veía.

## Decisión

- Si el borrado normal falla y los únicos archivos sin trackear (no ignorados) son `pnpm-lock.yaml` o
  `pnpm-workspace.yaml`, se borra con `git worktree remove --force`. Se regeneran solos y nunca se commitean.
- Con cualquier otro archivo sin trackear el worktree se queda, porque puede ser trabajo sin commitear. Se
  avisa una sola vez (notificación y log) nombrando el archivo, y otra vez solo si cambia lo que lo frena.
  La marca vive en `~/.local/state/stack-sync/blocked/`.
- Siguen igual las condiciones de 0045: archivos trackeados sin cambios, HEAD en la punta del PR y ningún
  PR apilado encima.

## Consecuencias

- En las máquinas de trabajo conviene además poner esos dos archivos en `.git/info/exclude` de cada repo:
  así quedan ignorados y tampoco los cuenta el hook de SessionStart (`worktree-cleanup.sh`), que usa
  `git status --porcelain` completo.
- Un archivo propio sin commitear en un worktree mergeado sigue frenando el borrado, ahora con aviso.
