# 0041 — stack-sync no pushea y no lo frenan los archivos sin trackear

Estado: aceptado (2026-11-19). Ajusta 0032.

## Contexto

El 2026-11-19 el PR #497 de CX quedó con conflictos después de que se mergearon otros PR a `dev`, y
`stack-sync` no lo resolvió. El log mostraba que desde hacía horas salteaba todos los worktrees con «tiene
cambios sin commitear». La causa era un `pnpm-lock.yaml` sin trackear: `pnpm` lo genera al correr los scripts
en repos cuyo lockfile oficial es `package-lock.json`. Los salteos van solo al log, así que nadie lo veía.
Además, Loren pidió que lo automático le avise y que pushee él, en lugar de que el script o el agente
pusheen solos.

## Decisión

- Un worktree se saltea solo si tiene cambios en archivos trackeados (`git status --untracked-files=no`).
  Los archivos sin trackear no lo frenan.
- `stack-sync` no pushea ni edita el PR. Un merge sin conflictos queda commiteado en el worktree, y la
  notificación trae el comando para publicarlo (`git -C <worktree> push origin HEAD:<rama>`, más el
  `gh pr edit --base <trunk>` cuando la base se mergeó). El agente que resuelve un conflicto commitea el
  merge y avisa con el mismo comando, sin pushear.
- El brief del agente dice que es un brief, así no hace las preguntas de carril (ADR 0040).
- El timer corre cada 15 minutos en lugar de 10.

## Consecuencias

- Un merge local sin pushear deja el HEAD por delante del PR. Las corridas siguientes saltean ese worktree
  («no está en la punta») hasta que Loren pushea, así que no se repiten ni el merge ni la notificación.
- El retarget después de mergear la base deja de ser automático: va en el comando de la notificación.
