# 0042 — stack-sync vuelve a pushear, también la resolución de conflictos

Estado: reemplazado por 0044 (2026-11-19). Reemplazaba la parte de 0041 que sacaba el push; lo demás de 0041 sigue.

## Contexto

Con 0041 el script dejaba los merges commiteados y avisaba para que Loren pusheara. Ese mismo día Loren pidió
lo contrario: que el script vea sus PR subidos, resuelva los conflictos para que se puedan mergear y pushee.
Si un PR no tiene conflictos, no lo toca. Los PR apilados se siguen actualizando y pusheando como en 0032.

El agente que resuelve un conflicto corre en una sesión de Orca, y ahí la guarda de la org
(`pre-bash-guard.sh`) pide confirmación en cada `git push`. Si el agente pusheara, la automatización quedaría
frenada esperando una respuesta.

## Decisión

- Los merges sin conflictos se pushean como en 0032, con el cambio de base del PR al trunk cuando el PR de
  abajo se mergeó.
- El agente resuelve el conflicto, corre los checks y, si pasan, commitea el merge y deja una marca
  `~/.local/state/stack-sync/resolved-<repo>-<pr>-<sha>` con su commit. No pushea.
- En la corrida siguiente, si el worktree está adelantado respecto del PR, su HEAD es el commit de la marca y
  la punta del PR es ancestro de ese HEAD, el script pushea (sin force) y borra la marca. En un PR apilado
  sigue con los pasos de 0032, así que también le cambia la base si hace falta.
- Un commit local sin marca no se pushea: el worktree se saltea como antes.
- Siguen vigentes de 0041: los archivos sin trackear no frenan, el timer corre cada 15 minutos y el brief del
  agente no hace las preguntas de carril.

## Consecuencias

- Entre la resolución del agente y el push pasan hasta 15 minutos.
- El push del script no pasa por la guarda: se apoya en el OK permanente de Loren para pushear sus ramas en la
  org, igual que 0032. La puerta son los checks que corre el agente, y su marca es la prueba de que pasaron.
