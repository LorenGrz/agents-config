# Plan: delegar trabajo a Gemini (Antigravity CLI `agy`) desde Claude Code

## Contexto
Loren quiere aprovechar también la cuota de Google: que la sesión de Claude (Opus decide, Sonnet ejecuta) pueda mandarle una tarea a Gemini vía `agy` y, o bien esperar el resultado, o bien abrirle una sesión interactiva de Gemini con el prompt ya cargado. Ya está verificado en la máquina:
- `/usr/bin/agy`, con soporte de `-p/--print`, `-i/--prompt-interactive`, `--model`, `--dangerously-skip-permissions`, `--print-timeout`, `--output-format`, `--add-dir`.
- `agy models` muestra `gemini-3.8-flash-{high,medium,low}` (y modelos de Claude/GPT-OSS, que no vamos a usar).
- La terminal por defecto es Ghostty vía `xdg-terminal-exec`. También están instalados tmux y foot.
- Antigravity ya lee las mismas skills: `sync.sh` enlaza `~/.gemini/config/skills` y rulesync genera las reglas (ADR 0002).

Decisiones de Loren: headless con **`--dangerously-skip-permissions`**, y en v1 van **los dos modos** (run + open).

## Diseño
Una skill nueva con su script. No agrego un subagente: el cold start de un subagente cuesta tokens de Anthropic, y la main session puede llamar al script por Bash directamente.

### 1. `meta/gemini-delegate/scripts/gemini-delegate.sh` (nuevo, ejecutable)
```
gemini-delegate.sh run  [--model M] [--timeout 20m] [--allow-dirty] (-f spec.md | "prompt")
gemini-delegate.sh open [--model M] (-f spec.md | "prompt")
```
- El modelo por defecto es `gemini-3.8-flash-high` (se puede cambiar con `GEMINI_DELEGATE_MODEL`).
- `run`:
  - Exige un repo git y un worktree limpio (`git status --porcelain` vacío). Si no, sale con código 2, salvo que se pase `--allow-dirty`. Es la red de seguridad del skip-permissions: todo lo que haga Gemini queda aislado en el diff y se puede revisar o descartar.
  - Ejecuta `agy -p "$prompt" --model "$M" --dangerously-skip-permissions --print-timeout "$T" --output-format text` y guarda la salida en `${TMPDIR:-/tmp}/gemini-delegate/<timestamp>.log`.
  - Por stdout imprime solo un resumen corto: el exit code, la ruta del log, las últimas ~40 líneas de la respuesta y `git diff --stat`. Así Claude no se come la salida entera.
- `open`:
  - Escribe el prompt en un archivo temporal.
  - Si `$TMUX` está definido, hace `tmux split-window -h`. Si no, usa `xdg-terminal-exec` (con fallback a `ghostty -e`) y corre `agy -i "$(cat file)" --model "$M"` en el cwd actual. Queda en background y sale enseguida.
- El prompt se lee siempre desde un archivo o desde un argumento entre comillas, nunca interpolado en una string de shell (así se evita el bug de comillas del ejemplo pegado). `set -euo pipefail`, con un `usage` corto.

### 2. `meta/gemini-delegate/SKILL.md` (nuevo)
- Descripción con los disparadores: "usá Gemini / mandalo a Gemini / ahorrar tokens de Anthropic / escaneo masivo de contexto / boilerplate grande / abrir antigravity".
- Cuándo delegar: escritura mecánica grande de un plan ya decidido, generación de tests o boilerplate, lectura o resumen de mucho contexto. Cuándo NO: decisiones de arquitectura o seguridad (siguen en `reasoner`/Opus) y cambios chicos (≤3 archivos, inline).
- Flujo:
  1. Escribir el spec en `docs/superpowers/plans/…` o en el scratchpad, con los archivos exactos y el comando de aceptación.
  2. Para tareas grandes, opcionalmente aislar en un worktree.
  3. `gemini-delegate.sh run -f spec.md`.
  4. Claude revisa `git diff` y corre el comando de aceptación. Si falla, lo arregla inline o relanza con feedback.
  5. Reportar.
- Ejemplo de `open` para el hand-off interactivo.

### 3. Routing y permisos
- `config/CLAUDE.md` → en "Agent Routing", agregar una línea: "**Gemini** (`gemini-delegate` skill, `agy`) para escritura mecánica masiva o lectura de mucho contexto cuando conviene usar la cuota de Google; Claude siempre revisa el diff y corre la aceptación."
- `config/settings.base.json` → agregar `"Bash(*gemini-delegate.sh *)"` a `permissions.allow`. Hoy `agy` suelto requiere confirmación, y lo dejo así para que solo pase sin preguntar a través del wrapper con sus guardas.

### 4. Docs
- `docs/decisions/0010-gemini-delegation-via-agy.md` con la misma forma que 0009: el contexto, la decisión (script + skill, sin subagente, skip-permissions protegido por el chequeo de worktree limpio) y las consecuencias (Gemini no ve el contexto de la conversación, solo el spec; la calidad hay que revisarla; depende de la cuota y la disponibilidad de `agy`).
- `docs/decisions/README.md` → agregar 0010 al índice si lo lista.
- Copiar este plan a `docs/superpowers/plans/2026-10-31-gemini-delegate.md`.

## Ejecución
Son 6 o 7 archivos chicos en el repo `~/.agents/skills`. Lo hago inline (es un solo dominio y el diseño ya está decidido), en la branch `feat/gemini-delegate`, siguiendo el flujo de git de AGENTS.md: commit, push y merge `--no-ff` a la default. Después corro `./sync.sh` y `./install.sh` para regenerar `~/.claude/settings.json`.

## Verificación
1. `bash -n` y `shellcheck` (si está instalado) sobre el script.
2. `./sync.sh` → existe `~/.claude/skills/gemini-delegate/SKILL.md`.
3. Guarda: correr `run` en un repo con cambios → tiene que salir con código 2 sin llamar a `agy`.
4. Smoke real en `mktemp -d` + `git init` + un commit vacío: `gemini-delegate.sh run "Creá hello.txt con el texto hola"` → aparece el archivo y el resumen muestra el diff y la ruta del log.
5. `open "decí hola"` → se abre Ghostty con agy interactivo (esto lo confirma Loren visualmente).
6. `jq '.permissions.allow' ~/.claude/settings.json` incluye la regla nueva, después de `install.sh`.
