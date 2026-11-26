# 0062 — Los workers de Orca commitean en su rama sin diálogo, con `worker-commit.sh`

Estado: aceptado (2026-11-26). Ajusta 0060 (los agentes de stack-sync también pasan por acá si usan `git commit` directo).

## Contexto

El 25/11 los workers de `orca orchestration worker-start` se trabaron en el diálogo de permisos al commitear en la
rama de su worktree: un líder de back escaló tres veces «Worker is waiting for permission», y otro worker
quedó esperando hasta que Loren lo destrabó a mano (el clasificador no dejó al orquestador elegir «Yes»).
La causa: el `.claude/settings.json` versionado del repo de la org tiene `ask` para `Bash(git commit *)`. Los workers
arrancan con `--dangerously-skip-permissions`, pero una regla `ask` pide confirmación igual. Medido con `claude -p`
en un repo de prueba: ni un `allow` del usuario ni un hook con `permissionDecision: "allow"` la pisan. Las reglas sí se
comparan contra el comando que un hook devuelve en `updatedInput`, aun sin `permissionDecision`. 0060 lo había
resuelto solo para stack-sync, con un comando que el agente tiene que acordarse de usar. La regla del equipo no se
cambia en los repos.

## Decisión

- `config/hooks/worker-commit.sh`, hook PreToolUse (Bash) global (`settings.base.json` y el plugin), reescribe solo
  el `git commit` del comando a `bash <ruta>/worker-commit.sh commit …`; el resto del comando queda igual. No
  devuelve `permissionDecision`: no concede nada, solo esquiva el patrón `git commit *`.
- Reescribe solo si se cumple todo esto; si no, calla y sigue el flujo normal:
  - un único `git commit` (o `git -C <dir> commit`) en posición de comando, con a lo sumo un `cd` antes;
  - solo `-m`, `-F`, `-q`, `-a`, `-s`, `-v`, `--allow-empty` y `--no-edit` durante un merge;
  - el destino es un worktree enlazado en una rama que no es base (`main`, `master`, `dev`, `develop`, `qa`, la de `origin/HEAD`);
  - la sesión es un worker supervisado (`$ORCA_TERMINAL_HANDLE` figura en `orca orchestration worker-list` con ese worktree, en cualquier estado: un despacho de seguimiento reusa la terminal), o un agente de stack-sync con su marca de ocupado viva ahí;
  - el `git commit` no está dentro del cuerpo de un heredoc anterior (un script que se escribe es dato, no comando).
- El mismo archivo, llamado con `commit`, revalida todo sobre los argumentos reales y deja una línea en
  `~/.local/state/agents-config/worker-commit.log`.
- `git add` no se toca: ningún repo le pone `ask`, y en modo bypass pasa.

## Consecuencias

- Un `git add -A && git commit -m …` de un worker corre sin diálogo. Si el comando también trae `git push`,
  `gh pr create` o `gh pr merge`, sigue preguntando por esa parte. `--force` y las reglas `deny` siguen igual. El hook
  rechaza por su cuenta la rama base y los flags peligrosos, sin depender de las guardas de la org.
- `--amend`, `--no-verify` o un flag fuera de la lista vuelven al diálogo, y ahí decide el orquestador o Loren.
- Las sesiones que no son workers (Loren, el orquestador) siguen viendo el `ask` del repo, salvo en un worktree con
  una marca de stack-sync viva, como ya pasaba con `stack-sync-git.sh`.
- Cada `git commit` de un worker hace una consulta a Orca de ~0,2 s. Sin Orca abierto o sin `jq`, el hook calla.
- Rige recién después del merge y de `install.sh`, que lo suma al `settings.json` global.
- `stack-sync-git.sh` sigue siendo el push de los agentes de stack-sync: este hook no toca `git push`.
