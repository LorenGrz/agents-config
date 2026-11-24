# 0060 — Los agentes de stack-sync commitean y pushean con `stack-sync-git.sh`

Estado: aceptado (2026-11-24). Reemplaza 0059. Ajusta 0044, 0047 y 0048 (cómo commitean y pushean sus agentes).

## Contexto

Los repos de una org de trabajo versionan en `.claude/settings.json` reglas `ask` para `git commit *` y
`git push *`. Según la doc de Claude Code, una regla `ask` pide confirmación aunque la sesión corra en
`bypassPermissions`, y no la pisan un `allow` del usuario ni un hook. Los tres agentes de stack-sync (conflictos,
review y CI en rojo) quedaban frenados esperando a Loren. 0059 lo resolvía solo para los conflictos: el agente
dejaba el merge con `git add` y una marca, y el script commiteaba y pusheaba. No sirve para review ni CI, que
hacen varios commits y contestan cada comentario con el hash del suyo. Loren no quiere cambiar la regla del equipo
en los repos: el cambio va solo de su lado.

## Decisión

- `scripts/stack-sync-git.sh` es el único commit y push de los agentes: `commit -m <mensaje>` (uno o más),
  `commit --no-edit` (solo con un merge en curso) y `push` (siempre `HEAD` a la rama del PR en `origin`, sin
  force). Rechaza cualquier otro flag, `--amend`, `--no-verify`, otra rama y el force.
- Funciona solo en un worktree con una marca de ocupado viva de stack-sync. `launch_agent` escribe la marca antes
  de lanzar el agente, con el worktree y la rama del PR; el comando la lee de ahí, y la borra si Orca no lanza.
- Cada uso queda en `~/.local/state/stack-sync/stack-sync.log`.
- Los tres briefs nombran el comando por su ruta absoluta y dicen que `git commit` y `git push` directos frenan
  la pestaña.
- Se sacan la marca `resolved-*`, el commit y push del script, la cláusula del `--precheck` y la limpieza de 0059.

## Consecuencias

- El agente commitea y pushea en su corrida, como antes de 0059: el push no espera a la corrida siguiente y la
  review contesta con hashes reales.
- La regla `ask` del repo sigue valiendo en cualquier otra sesión: sin una marca de stack-sync viva en ese
  worktree, el comando se niega.
- Probado antes de adoptarlo: en `bypassPermissions` y con `ask` de `git commit`, Claude corrió el comando sin
  preguntar y frenó el `git commit` directo.
