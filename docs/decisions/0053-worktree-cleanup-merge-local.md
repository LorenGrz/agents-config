# 0053 — El hook de limpieza también borra los worktrees mergeados sin PR

Estado: aceptado (2026-11-24). Ajusta 0030.

## Contexto

0030 borra un worktree solo si GitHub tiene un PR mergeado de su rama. Los repos personales se mergean en local
con `--no-ff` y sin PR (paso 7 de `github-usage`), así que sus worktrees no se borraban nunca: el 2026-11-24
quedaban dos en el hub (`flujo-matt-sin-superpowers` y `agents-config-stack-sync`), mergeados hacía días. Loren
pidió que en los proyectos personales el área de trabajo se vaya limpiando sola.

La ancestría sola no sirve como señal: una rama recién creada, sin commits propios, también es ancestro de la
base, y lo sigue siendo cuando la base avanza.

## Decisión

- Si no hay PR mergeado con el mismo head, `worktree-cleanup.sh` toma la rama como mergeada cuando su punta es
  ancestro de `origin/<default>` (de `origin/HEAD`, si no `origin/main` u `origin/master`) **y** no está en su
  cadena first-parent: entró por un merge `--no-ff` ya pusheado.
- Se compara contra la rama remota, sin `fetch`: lo mergeado en local y todavía sin pushear no se borra, y una
  ref vieja solo demora el borrado.
- Sin `gh` (o con `gh` fallando) corre solo este chequeo local; antes el hook no hacía nada.
- Siguen igual: solo worktrees limpios, nunca el del cwd ni la rama base, `git worktree remove` sin `--force`.
  El mensaje dice `mergeada en origin/<default>` en vez del número de PR.

## Consecuencias

- Un merge fast-forward no se detecta (la punta queda en la cadena first-parent): el worktree se queda, que es el
  lado seguro.
- Una rama sin commits propios creada sobre la punta de otra rama que después se mergea con `--no-ff` se borra:
  no pierde nada, pero se va el worktree.
- Un worktree creado por Orca se borra con git y puede quedar en la lista de Orca, igual que con un PR mergeado.
- Verificado sin red por `scripts/test-worktree-cleanup.sh`.
