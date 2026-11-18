# 0030 — Los worktrees de PRs mergeados se borran al iniciar una sesión

Estado: aceptado (2026-11-17). Sigue a 0029 (todo cambio no trivial en un repo corre en su propio worktree).

## Contexto

Desde 0029 cada tarea vive en un worktree hermano (`repo-frontend-abc-123` junto a `repo-frontend`) y nadie lo
borra después del merge. Git no ve que la tarea terminó (squash merge, rama remota conservada); la única señal
confiable es el PR en GitHub. El 2026-11-17 Loren pidió que se borre solo al abrir una sesión.

## Decisión

- Un segundo hook `SessionStart`, `config/hooks/worktree-cleanup.sh`, registrado en `settings.base.json` junto
  a `session-start.sh`. Lee `cwd` del JSON del hook (`$PWD` como respaldo).
- Alcance: si el cwd está dentro de un repo git, los worktrees enlazados de ese repo; si es una carpeta que
  agrupa repos (no es repo y sus hijos tienen su propio `.git`), los worktrees enlazados de cada uno. Nunca el
  worktree principal ni el que contiene el cwd.
- Un worktree enlazado con rama se borra solo si se cumple todo:
  1. `git status --porcelain` está vacío;
  2. `gh pr list --repo <owner/repo of origin> --head <branch> --state merged` devuelve un PR;
  3. el `headRefOid` de ese PR es igual al `HEAD` del worktree, así nunca se pierde un commit local posterior.
- Entonces corre `git worktree remove <path>` (sin `--force`: si git se niega, no se toca nada) y
  `git branch -D <branch>` en el repo principal (`-d` falla después de un squash merge; `-D` es seguro por el
  punto 3).
- Nunca se tocan: la rama remota, el worktree principal, un worktree sucio, uno con commits que el PR no
  tiene, los bloqueados o detached, ni las ramas `main`, `master`, `dev`, `develop`.
- Presupuesto de unos 10 segundos para toda la corrida, con un `timeout` por llamada a `gh`. Sin `gh`, sin red
  o ante cualquier otra falla: exit 0 en silencio. El hook nunca rompe una sesión.
- Salida: si borró algo, una línea por worktree como `additionalContext` ("worktree-cleanup: borré <path>
  (rama <branch>, PR #<n> mergeado)"); si no, nada.
- A pedido: `bash ~/.claude/hooks/worktree-cleanup.sh --cwd <dir>` imprime un resumen en texto plano, y
  `--dry-run` solo lista lo que borraría. Es el atajo "limpiar worktrees" de `github-usage`.
- Verificado sin red por `scripts/test-worktree-cleanup.sh` (repos temporales y un `gh` falso).

## Consecuencias

- Los worktrees de tareas terminadas desaparecen sin paso manual, a costa de hasta 10 segundos en el peor caso
  al iniciar la sesión (un `gh` lento), y solo cuando la sesión abre en el repo o en su carpeta.
- Borra sin preguntar, como pidió Loren; la guarda es el chequeo del head exacto, así el trabajo sin mergear o
  extendido queda.
- Un worktree cuyo PR se mergeó pero cuyo head se movió después queda hasta que se borre a mano.
