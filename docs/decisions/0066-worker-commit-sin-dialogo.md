# 0066 — Los workers de Orca commitean en su rama sin diálogo, con `worker-commit.sh`

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
- No interpreta bash. Reescribe solo cuando el comando entero es un único `git commit` en una línea, con estos
  argumentos separados por un espacio, y nada más:
  - `-q`/`--quiet`, `-a`/`--all` y `--no-edit` (este, solo con un merge en curso);
  - `-m`/`--message` seguido de `'…'` (sin `'` adentro) o de `"…"` (sin `"`, `$`, backtick ni `\` adentro); un
    mensaje de varias líneas va como varios `-m`;
  - `-F`/`--file` seguido de una ruta simple.

  No acepta saltos de línea (tampoco dentro de las comillas), `&&`, `;`, `|`, `$`, backticks, `<(`, redirecciones,
  heredocs ni prefijos (`env`, `export`, `cd`, `git -C`). Un comando simple fuera de la lista (`--amend`,
  `--no-verify`, `-n`, `-m` sin comillas, `HUSKY=0 git commit`, `git -C`) sigue al diálogo de siempre.
- Un comando compuesto o de varias líneas que trae un `git commit` en posición de comando (al principio, o después
  de `;`, `&`, `|`, `(` o un salto de línea) se niega con `deny`, solo para un worker autorizado (los mismos
  chequeos de abajo), con el motivo «Mandá git add y git commit en comandos aparte, cada uno en una línea; el
  mensaje con -m en una línea (varios -m si hace falta). Sin redirecciones ni nada encadenado; si el mensaje trae
  $, ` o \, va entre comillas simples». El worker lee el motivo y reintenta en comandos sueltos,
  que se reescriben, sin diálogo y sin depender de que su brief lo diga. Un `deny` no amplía permisos: el comando
  no corre. Fuera de un worker autorizado no cambia nada: sigue al diálogo.
- Para reescribir o negar hace falta todo esto, y el chequeo de worker va antes de cualquier análisis:
  - una regla `ask` (usuario, proyecto, local o managed) cubre `git commit`: para reescribir, la que matchea ese
    mismo comando; para negar, la que matchea `git commit -m x`. Sin ese `ask`, el hook no hace nada y el worker
    commitea como siempre, también encadenado;
  - la sesión es un worker supervisado (`$ORCA_TERMINAL_HANDLE` figura en `orca orchestration worker-list` con ese
    worktree, en cualquier estado, porque un despacho de seguimiento reusa la terminal) o un agente de stack-sync
    con su marca de ocupado viva ahí; nunca los subagentes `scout` ni `reviewer`. El hook lee el entorno del proceso
    de Claude, que el modelo no cambia desde su shell;
  - el directorio de la sesión es un worktree enlazado en una rama que no es base (`main`, `master`, `dev`,
    `develop`, `qa`, la de `origin/HEAD`), con un `core.hooksPath` que no es `/dev/null`;
  - para reescribir, además, el commit trae `-m`, `-F` o `--no-edit` fuera de las comillas, y ninguna regla `deny`
    matchea el comando real ni `git commit -m x`, porque la reescritura también la esquivaría. Las reglas se prueban
    como glob, con la forma vieja `prefijo:*` incluida.
- El hook deja un token de un solo uso atado al worktree. Llamado con ese token, el mismo archivo corre solo si el
  token tiene menos de 5 minutos y es de ese worktree. Lo borra, revalida los argumentos, la rama y el
  `core.hooksPath` sobre el argv real, limpia las variables de git y de husky que saltean o desvían los hooks del
  commit, commitea y deja una línea en `~/.local/state/agents-config/worker-commit.log`. Sin token se niega.
- Los briefs también piden commitear en un comando aparte, para no gastar el reintento. El cierre del brief de cada líder (`config/hooks/orquestar.sh`) lo
  dice: «`git add` en un comando y el commit solo en el suyo, `git commit -q -m "título" -m "cuerpo"`, sin `cd`, sin
  `&& git log` y sin heredoc». La nota de commit de los agentes de stack-sync (`scripts/stack-sync.sh`) dice lo
  mismo para su `stack-sync-git.sh`.

## Consecuencias

- Qué cubre: el `git commit` suelto de un worker en su worktree corre sin diálogo.
- Las 17 formas reales del 25/11 (los comandos Bash con `git commit` de los workers de CX, dos de ellas después de
  un `python3 <<'EOF'`) eran compuestas: `git add … && git commit … && git log`, `cd …;`, `diff <(…)`, dos commits
  seguidos. Tres traían además un mensaje de varias líneas. En un worker, el test fija las 17 en el `deny` con el
  motivo; fuera de uno, en el diálogo.
- El caso de CX-829 (`diff <(…) && … && git add … && git commit … && git log`) queda cubierto por el `deny`: el
  worker recibe el motivo y manda el `git add` y el `git commit` por separado. No depende de la skill de
  orquestación de la org, que el 25/11 escribió los briefs de los líderes sin el cierre de `orquestar.sh`.
- Costo: un reintento del worker por cada comando compuesto, solo en repos con el `ask`. Si en un worker un script o un heredoc trae una línea
  que empieza con `git commit` (un texto, no un commit), también se niega; el worker puede escribirlo con su
  herramienta de archivos.
- Las sesiones que no son workers (Loren, el orquestador) siguen viendo el `ask` del repo. La excepción es un
  worktree con una marca de stack-sync viva, como ya pasaba con `stack-sync-git.sh`. La marca de `busy/` y el token se
  pueden forjar escribiendo un archivo: sería evadir el `ask` a propósito, algo que la regla tampoco frenaba antes (un
  script que corre `git commit` pasa igual). Las dos cosas evitan el uso accidental, no a quien lo busca.
- Cualquier worker supervisado de ese worktree queda autorizado. Eso incluye a un reviewer de Orca que commitee por
  error y a una orden directa de Loren en la terminal de un worker ya terminado (`retained`). El reviewer es de solo
  lectura por su brief; el hook no lo distingue.
- Límites conocidos. El hook no lee reglas de un `--settings` pasado al arrancar ni de
  `/etc/claude-code/managed-settings.d/`. Sobre `core.hooksPath` solo rechaza el literal `/dev/null`: apuntarlo a
  una carpeta vacía con un `git config` previo saltea los hooks, la misma evasión deliberada que forjar el token.
  Un `git commit` con prefijo dentro de un compuesto (`&& HUSKY=0 git commit`, `&& git -c … commit`) no se
  reconoce y va al diálogo.
- Cada `git commit` suelto de un worker hace una consulta a Orca de ~0,2 s. Sin Orca abierto o sin `jq`, el hook
  calla.
- Rige recién después del merge y de `install.sh`, que lo suma al `settings.json` global.
- `stack-sync-git.sh` sigue siendo el push de los agentes de stack-sync: este hook no toca `git push`.
- Para reproducir, `WORKER_COMMIT_E2E=1 bash scripts/test-worker-commit.sh` corre `claude -p` (red, centavos). Muestra
  que sin el hook un `ask` de proyecto frena el commit aun en bypass y que con el hook un commit suelto pasa. Un
  commit con push en un worker se niega con el motivo (sin el hook el motivo no aparece) y no corre ni el commit ni
  el push. Pedido el compuesto, el modelo recibe el deny, reintenta aparte y el commit queda hecho.
