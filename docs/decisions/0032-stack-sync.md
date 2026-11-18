# 0032 — Ramas de PRs apilados actualizadas por un timer

Estado: aceptado (2026-11-18). Se apoya en 0029 (un worktree por tarea) y 0030 (limpieza de worktrees).

## Contexto

Loren apila PRs: una rama sale de otra cuyo PR sigue abierto. Cuando el de abajo recibe cambios o se mergea a
`dev` con squash, la rama de arriba queda atrás o choca con `dev` y hay que mergear a mano. El 2026-11-18
pidió que pase solo, en el worktree de cada rama, con los conflictos resueltos por un agente.

## Decisión

- `scripts/stack-sync.sh`, corrido cada 10 minutos por un timer de systemd de usuario que instala
  `scripts/stack-sync-install.sh` (opt-in, por máquina; `--remove` lo deshace).
- Alcance: los PRs abiertos de Loren (`gh pr list --author @me`) en los repos de un owner de GitHub
  encontrados bajo ciertas carpetas raíz, ambos definidos en `~/.config/stack-sync/config` (no versionado);
  cada PR se procesa solo en el worktree local de su rama, los de abajo primero.
- Por PR: PR base mergeado → merge de `origin/<trunk>`, push y retarget al trunk; rama base con commits nuevos
  → merge de `origin/<base>` y push; PR sobre el trunk con conflictos → merge de `origin/<trunk>` y push.
- Un merge con conflictos se aborta y se abre un agente Claude visible en ese worktree con `orca agent launch`
  (no necesita coordinador, así que anda desde un timer) con una spec fija: resolver, correr los checks del
  repo, commitear el merge, pushear y avisar el resultado con `notify-send`. Un lanzamiento por (PR, commit
  base).
- Nunca rebase, force ni amend. Un worktree sucio, o uno cuyo HEAD no es el head del PR (commits sin pushear o
  atrasado), se saltea y se registra. Pushear sin preguntar sigue el OK permanente de Loren para pushear en su
  org de trabajo; abrir o mergear PRs sigue necesitando su OK.
- Las acciones van a `notify-send` y a `~/.local/state/stack-sync/stack-sync.log`; los salteos, solo al log.
  `--dry-run` lista lo que haría. Verificado sin red por `scripts/test-stack-sync.sh`.
- Descartado: `orchestration worker-start`, porque fuera de una terminal de Orca necesita `--from` con el
  handle de un coordinador, que un timer no tiene.

## Consecuencias

- Las pilas siguen a su base en menos de 10 minutos; el retarget después de un merge ya no es manual.
- Un agente puede pushear solo la resolución de un conflicto; su puerta son los checks del repo.
