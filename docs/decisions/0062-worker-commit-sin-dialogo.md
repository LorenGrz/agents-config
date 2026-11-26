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

- `config/hooks/worker-commit.sh`, hook PreToolUse (Bash) global (`settings.base.json` y el plugin), reescribe el
  `git` del único `git commit` del comando a `bash <ruta>/worker-commit.sh --token <t>`; el resto del comando queda
  igual. No devuelve `permissionDecision`: no concede nada, solo esquiva el patrón `git commit *`.
- Reescribe solo si se cumple todo esto; si no, calla y decide el diálogo de siempre:
  - la sesión es un worker supervisado (`$ORCA_TERMINAL_HANDLE` figura en `orca orchestration worker-list` con ese
    worktree, en cualquier estado: un despacho de seguimiento reusa la terminal), o un agente de stack-sync con su
    marca de ocupado viva ahí; nunca los subagentes `scout` ni `reviewer`. El hook lee el entorno del proceso de
    Claude, que el modelo no cambia desde su shell;
  - el comando entero entra en una gramática chica (lista de lo permitido, no de lo prohibido): segmentos unidos por
    `&&`, `||`, `;`, saltos de línea o un pipe a `tail`/`head`; cada segmento es `cd <dir>`, `echo`, `true`, `pwd` o
    `git [-C <dir>] add|status|log|diff|show|merge-base|rev-parse|branch|commit`, con un solo `git commit` y a lo
    sumo un `cd`. Fuera de comillas simples no hay `$`, backtick, `\`, paréntesis, llaves, `&` suelto ni otra
    redirección que `2>&1` y `[2]>/dev/null`. Así quedan afuera `export`, asignaciones, `env`, `git -c`, la
    sustitución de comandos y de procesos, la continuación de línea y cualquier `git push` o `gh`. La única
    excepción es el mensaje en un heredoc literal (`-m "$(cat <<'EOF' … EOF)"` o `-F - <<'EOF' … EOF`, delimitador
    entre comillas, sin expansión);
  - solo `-m`, `-F`, `-q`, `-a`, `-s`, `-v`, `--allow-empty` y `--no-edit` durante un merge;
  - el destino es un worktree enlazado en una rama que no es base (`main`, `master`, `dev`, `develop`, `qa`, la de
    `origin/HEAD`), y su `core.hooksPath` no es `/dev/null`;
  - ninguna regla `deny` (usuario, proyecto o managed) cubre `git commit`: la reescritura también la esquivaría.
- El hook deja un token de un solo uso con el worktree. El mismo archivo, llamado con ese token, corre solo si el
  token tiene menos de 5 minutos y es de ese worktree. Lo borra, revalida flags, rama y `core.hooksPath` sobre los
  argumentos reales, limpia las variables de git y de husky que saltean o desvían los hooks del commit, commitea y
  deja una línea en `~/.local/state/agents-config/worker-commit.log`. Sin token se niega.
- `git add` no se toca: ningún repo le pone `ask`, y en modo bypass pasa.

## Consecuencias

- Las formas medidas el 25/11 corren sin diálogo: `cd …; git merge-base … && echo …; git status --short; git add … &&
  git commit -q -m …` y `git add … && git commit -q -m … -m … && git log --oneline -2`.
- Un comando que no entra en la gramática vuelve entero al diálogo, y ahí decide el orquestador o Loren. Pasa lo
  mismo con `git commit … && git push`, con `--amend`, `--no-verify` o un flag fuera de la lista, y con un
  `diff <(…)` antes del commit. Es preferible un diálogo de más a reescribir algo que el hook no entiende.
- El hook rechaza por su cuenta la rama base y los flags peligrosos, sin depender de las guardas de la org.
- Las sesiones que no son workers (Loren, el orquestador) siguen viendo el `ask` del repo. La excepción es un
  worktree con una marca de stack-sync viva, como ya pasaba con `stack-sync-git.sh`.
- Cualquier worker supervisado de ese worktree queda autorizado. Eso incluye un reviewer de Orca que commitee por
  error, y una orden directa de Loren en la terminal de un worker ya terminado (`retained`). Un reviewer es de
  solo lectura por su brief; el hook no lo distingue.
- Forjar un token a mano es evadir el `ask` a propósito, algo que la regla tampoco frenaba antes (un script que
  corre `git commit` pasa igual). El token evita el uso accidental, no a quien lo busca.
- Cada `git commit` de un worker hace una consulta a Orca de ~0,2 s. El análisis es lineal (perl): un mensaje de
  60 KB tarda décimas. Sin Orca abierto, sin `jq` o sin `perl`, el hook calla.
- Rige recién después del merge y de `install.sh`, que lo suma al `settings.json` global.
- `stack-sync-git.sh` sigue siendo el push de los agentes de stack-sync: este hook no toca `git push`.
- Reproducir: `WORKER_COMMIT_E2E=1 bash scripts/test-worker-commit.sh` corre `claude -p` (red, centavos). Muestra
  que sin el hook un `ask` de proyecto frena el commit aun en bypass, que con el hook pasa, y que con un push sigue
  preguntando.
