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

- `config/hooks/worker-commit.sh`, hook PreToolUse (Bash) global (`settings.base.json` y el plugin), reescribe un
  `git commit` suelto a `bash <ruta>/worker-commit.sh --token <t> commit …`. No devuelve `permissionDecision`: no
  concede nada, solo esquiva el patrón `git commit *`.
- No interpreta bash. Reescribe solo cuando el comando entero es un único `git commit` con estos argumentos, separados
  por un espacio, y nada más:
  - `-q`/`--quiet`, `-a`/`--all` y `--no-edit` (este, solo con un merge en curso);
  - `-m`/`--message` seguido de `'…'` (sin `'` adentro) o de `"…"` (sin `"`, `$`, backtick ni `\` adentro); un
    salto de línea dentro de esas comillas es texto del mensaje, y fuera de ellas no se acepta;
  - `-F`/`--file` seguido de una ruta simple.

  No acepta `&&`, `;`, `|`, `$`, backticks, `<(`, redirecciones, heredocs ni prefijos (`env`, `export`, `cd`,
  `git -C`). Todo lo demás, `--amend`, `--no-verify` y `-n` incluidos, sigue al diálogo de siempre.
- Además hace falta todo esto, y el chequeo de worker va antes de cualquier análisis:
  - la sesión es un worker supervisado (`$ORCA_TERMINAL_HANDLE` figura en `orca orchestration worker-list` con ese
    worktree, en cualquier estado, porque un despacho de seguimiento reusa la terminal) o un agente de stack-sync
    con su marca de ocupado viva ahí; nunca los subagentes `scout` ni `reviewer`. El hook lee el entorno del proceso
    de Claude, que el modelo no cambia desde su shell;
  - el directorio de la sesión es un worktree enlazado en una rama que no es base (`main`, `master`, `dev`,
    `develop`, `qa`, la de `origin/HEAD`), con un `core.hooksPath` que no es `/dev/null`;
  - ninguna regla `deny` (usuario, proyecto o managed) matchea `git commit`, porque la reescritura también la
    esquivaría.
- El hook deja un token de un solo uso atado al worktree. Llamado con ese token, el mismo archivo corre solo si el
  token tiene menos de 5 minutos y es de ese worktree. Lo borra, revalida los argumentos, la rama y el
  `core.hooksPath` sobre el argv real, limpia las variables de git y de husky que saltean o desvían los hooks del
  commit, commitea y deja una línea en `~/.local/state/agents-config/worker-commit.log`. Sin token se niega.
- Los workers commitean en un comando aparte. El brief de cada líder (`config/hooks/orquestar.sh`) y la nota de
  commit de los agentes de stack-sync (`scripts/stack-sync.sh`) lo dicen: «`git add` y `git commit` van en comandos
  separados, sin encadenar (tampoco `&& git log`)».

## Consecuencias

- Qué cubre: el `git commit` suelto de un worker en su worktree corre sin diálogo.
- Qué no cubre: un comando compuesto con un commit adentro vuelve entero al diálogo, y ahí deciden el orquestador o
  Loren. Las 15 formas reales del 25/11 eran compuestas (`git add … && git commit … && git log`, `cd …;`,
  `diff <(…)`, dos commits seguidos), y el test las fija en el diálogo. El caso de CX-829 (`diff <(…) && … && git
  add … && git commit … && git log`) queda cubierto porque ahora el worker hace el `git add` y el `git commit` en
  comandos aparte. Si un worker igual encadena, vuelve el diálogo; el hook no intenta entenderlo.
- Las sesiones que no son workers (Loren, el orquestador) siguen viendo el `ask` del repo. La excepción es un
  worktree con una marca de stack-sync viva, como ya pasaba con `stack-sync-git.sh`. La marca de `busy/` y el token se
  pueden forjar escribiendo un archivo: sería evadir el `ask` a propósito, algo que la regla tampoco frenaba antes (un
  script que corre `git commit` pasa igual). Las dos cosas evitan el uso accidental, no a quien lo busca.
- Cualquier worker supervisado de ese worktree queda autorizado. Eso incluye a un reviewer de Orca que commitee por
  error y a una orden directa de Loren en la terminal de un worker ya terminado (`retained`). El reviewer es de solo
  lectura por su brief; el hook no lo distingue.
- Cada `git commit` suelto de un worker hace una consulta a Orca de ~0,2 s. Sin Orca abierto o sin `jq`, el hook
  calla.
- Rige recién después del merge y de `install.sh`, que lo suma al `settings.json` global.
- `stack-sync-git.sh` sigue siendo el push de los agentes de stack-sync: este hook no toca `git push`.
- Para reproducir, `WORKER_COMMIT_E2E=1 bash scripts/test-worker-commit.sh` corre `claude -p` (red, centavos). Muestra
  que sin el hook un `ask` de proyecto frena el commit aun en bypass, que con el hook un commit suelto pasa, y que
  un commit con push sigue preguntando.
