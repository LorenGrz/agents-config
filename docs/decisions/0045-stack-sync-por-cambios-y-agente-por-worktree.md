# 0045 — stack-sync reacciona a los cambios de los PR, abre un Claude por worktree y limpia lo mergeado

Estado: aceptado (2026-11-19). Ajusta 0044: el precheck cambia, el agente ya no es el de la automatización y se
suma la limpieza de lo mergeado.

## Contexto

Con 0044, la automatización corría cada 10 minutos y, si había conflictos, lanzaba un solo Claude en la carpeta
de CX que entraba a cada worktree. Loren pidió tres cosas: reaccionar apenas cambia un PR (lo mergee quien lo
mergee), que cada conflicto se resuelva en una sesión abierta en el worktree de ese PR, y que al mergearse un PR
se borren su worktree, su sesión y su rama, local y remota. Un trigger real al mergear no es posible sin tocar
los repos de la org (webhook o GitHub Actions con un runner local), así que se consulta seguido y barato.

## Decisión

- La automatización corre cada 2 minutos en horario laboral con precheck `stack-sync.sh --precheck`. El
  precheck pregunta por repo, con ETag, si algún PR cambió (`GET /pulls?state=all&sort=updated`); un 304 no
  cuenta para el límite de la API. Solo si algo cambió, o pasaron 30 minutos de la última sincronización
  completa, sincroniza. Siempre sale con 1: la automatización nunca lanza un agente propio.
- El conflicto con el trunk se detecta también localmente (`git merge-tree --write-tree`), porque después de un
  merge GitHub tarda en recalcular `mergeable` (queda en `UNKNOWN`).
- Cada conflicto abre un Claude en el worktree de ese PR con `orca agent launch --worktree path:<worktree>`, una
  vez por (PR, commit base). Resuelve, commitea y pushea sin force, rápido: sin lint, typecheck ni la suite entera;
  solo un conflicto real de lógica corre los tests relacionados con los archivos que chocaron (un conflicto de
  doc, listas, imports o lockfiles no corre nada). La pestaña queda abierta.
- Por cada PR propio mergeado con un worktree enlazado, limpio, en la punta del PR y sin un PR apilado encima:
  `orca worktree rm` (o `git worktree remove`), `git branch -D` y `git push origin --delete` de la rama.
- Se van la cola y `--pending`/`--sync-pending`. La ruta del CLI de Orca va en `STACK_SYNC_ORCA` del config.

## Consecuencias

- Un merge se nota en hasta 2 minutos dentro del horario; fuera de él o con Orca cerrado no pasa nada.
- Una consulta sin cambios cuesta una llamada condicional por repo y no lanza nada.
- Un worktree con cambios sin commitear o commits que no están en el PR no se borra: queda en el log.
