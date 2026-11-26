# 0065 — Antes de borrar un worktree se frena lo que corre adentro

Estado: aceptado (2026-11-26). Ajusta 0030 y 0056.

## Contexto

El 2026-11-25 un worktree de CX quedó a medias: git ya no lo tenía registrado, pero la carpeta seguía en disco
con `.next`. Un `next dev` que seguía corriendo adentro volvió a escribir archivos mientras se borraba. Se
puede borrar un worktree por tres caminos: el botón o la CLI de Orca, el hook `worktree-cleanup.sh` (0030) y
un `git worktree remove` a mano. Ninguno miraba si había procesos vivos adentro.

## Decisión

- `config/hooks/worktree-frenar.sh` frena los procesos cuyo directorio de trabajo está dentro del worktree:
  primero TERM y después KILL. Si alguno no se deja frenar, sale con 1. `--listar` solo lista. Nunca corre
  sobre el worktree principal ni fuera de git.
- **Orca**: el hook `archive` de cada repo, guardado en la configuración local de Orca y no en `orca.yaml`,
  corre ese script. `scripts/orca-settings.py apply` lo completa en los repos git donde está vacío, con Orca
  cerrado como el resto de las preferencias (0056). Si el hook falla, Orca no borra nada.
- **worktree-cleanup.sh** no mata procesos: corre solo al abrir cualquier sesión, y adentro puede haber una
  sesión abierta. Con `--listar` saltea el worktree ocupado, lo dice, y lo borra en la próxima corrida.
- Es parte del setup personal: no se commitea `orca.yaml` ni ningún script en los repos de trabajo.

## Consecuencias

- Un repo nuevo en Orca queda sin hook hasta volver a correr `orca-settings.py apply` (o `orca-setup.sh`).
- Desde la CLI de Orca el hook corre solo con `orca worktree rm --run-hooks`.
- Borrar con `git worktree remove` a mano no frena nada: antes conviene `worktree-frenar.sh <ruta>`.
