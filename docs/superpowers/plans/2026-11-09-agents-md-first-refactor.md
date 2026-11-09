# Refactor AGENTS.md-first + hooks que entienden CAO + artefacto de estructura

## Contexto

Tarea nueva, a partir del análisis anterior (artefacto 1: https://claude.ai/artifact/Lqxjp8EWEHJDnU6Nj5jxAh). Loren pidió ejecutar el refactor y, al terminar, un **segundo artefacto**: no los cambios, sino la estructura armada de lo que se orquesta por petición, las carpetas que crea agents-config y cómo las usan los subagentes. Quiere que **AGENTS.md reemplace a CLAUDE.md en los proyectos**, para que las reglas críticas estén ahí y sean un estándar que también lean los subagentes.

Decisiones ya tomadas por Loren:
- Git: rama `refactor/context-sync` en cada repo, commits por fase, **sin push**. Primero un commit aparte con sus cambios pendientes del ADR 0018.
- PonyTail: solo la regla de caminos S/L y un ADR; PonyTail queda documentado como opcional, no se instala.
- Plugins: **no se desactiva ninguno** por ahora.
- Repos con un `CLAUDE.md` que solo dice `@AGENTS.md`: se dejan; adopt no los borra.

## Hallazgo clave (verificado con la documentación oficial; Claude Code local = 2.1.319)

- Desde v2.1.277 **Claude Code lee `AGENTS.md` solo**, sin `CLAUDE.md` ni import. Condición: se lee solo si no hay `CLAUDE.md`, `.claude/CLAUDE.md` ni `CLAUDE.local.md` en el cwd ni en ningún directorio superior. `~/.claude/CLAUDE.md` no cuenta, así que el global sigue cargando aparte. Un `CLAUDE.md` con `@AGENTS.md` es seguro: no se lee dos veces. Esto **corrige** el artefacto 1, que dice que Claude nunca lee AGENTS.md solo.
- Los **subagentes** (no fork) cargan la misma jerarquía: `~/.claude/CLAUDE.md`, el `CLAUDE.md` del proyecto y `AGENTS.md`. Los built-in Explore y Plan no. Cada subagente paga esa memoria en su arranque. `omitClaudeMd` en la definición del agente lo apaga.
- Los hooks de `PreToolUse` y similares **sí corren dentro de subagentes**; `agent_type`/`agent_id` los identifican. Que `SessionStart` y `UserPromptSubmit` lleguen a subagentes no está documentado.
- `UserPromptSubmit` trae `permission_mode` (valor `plan` en modo plan). No existe un campo que distinga una notificación de tarea de un prompt real.
- `InstructionsLoaded` **no** se dispara para un `AGENTS.md` leído por esta vía: `log-instructions.sh` queda ciego para eso.
- Si la ayuda nativa no está disponible (plugin built-in apagado, Bedrock o telemetría apagada antes de 2.1.281), solo se leen `CLAUDE.md`: razón para dejar los punteros existentes.
- Otros CLIs: Copilot, OpenCode y (muy probablemente) agy leen `AGENTS.md` del repo. Bajo CAO, OpenCode lee su AGENTS.md global en `~/.aws/opencode/AGENTS.md`. agy menciona `~/.gemini/GEMINI.md` y `~/.gemini/AGENTS.md`. Copilot: `~/.copilot/copilot-instructions.md` sin verificar (se verifica con `copilot instruction list`).
- CAO: `CAO_TERMINAL_ID` está en toda terminal (también en los hooks, que heredan el entorno). Nada distingue líder de worker en el entorno.
- `~/.agents/skills` es un symlink al hub entero y el perfil de Loren llama `~/.agents/skills/meta/roadmap-coach/scripts/update-stage.sh`: **no se toca** el espejo de Codex en este refactor (quedaría roto). Queda como pendiente a investigar.
- `install.sh` suma `enabledPlugins` (no resta): irrelevante ahora, porque no se saca ningún plugin.

## Ejecución (camino L: más de 3 archivos en dos repos)

Antes de la primera acción de git: cargar la skill `git-workflow`. Nada se pushea. `install.sh` **no se aplica** al `~/.claude` real: solo `--dry-run`; Loren lo corre cuando quiera.

### Fase 0 — Rama y premisa
1. En agents-config: `git switch -c refactor/context-sync`; commit aparte de los cambios pendientes de Loren (ADR 0018: `reasoner.md`, `session-start.sh`, `loren.md`, `settings.base.json`, ADRs 0003/0006/0009/README, `install.sh`, 0018) como `feat: ADR 0018 ...`. Commit del plan `docs/superpowers/plans/2026-11-09-context-map-caolg-sync.md` + este plan como `docs:`. En caolg: misma rama.
2. Verificar la premisa en vivo (2 llamadas cortas de `claude -p` en una carpeta temporal del scratchpad): con solo `AGENTS.md` con una palabra clave, (a) la sesión principal la conoce sin usar herramientas, (b) un subagente `worker` también. Si falla, parar y replantear la fase 4.

### Fase 1 — Hooks que entienden CAO (agents-config, 3 archivos, inline)
- `config/hooks/session-start.sh`, `critical-reasoning.sh`, `intent-router.sh`: si `CAO_TERMINAL_ID` está definido:
  - `session-start`: sin routing de subagentes ni nudges de `project-init` (el líder y los workers tienen su perfil).
  - `critical-reasoning`: silencio total.
  - `intent-router`: solo `PreToolUse` de herramientas `mcp__*`; sin frases de prompt ni `Bash` (git/gh), porque los prompts de workers son el texto de la asignación.
- `critical-reasoning.sh`, además: tope una vez por sesión del mensaje de razonamiento (mismo patrón de marcador que `intent-router.sh`, en `$XDG_RUNTIME_DIR/agents-intents/`); silencio si `permission_mode == "plan"`; silencio si el prompt contiene `<task-notification>` o empieza con `[SYSTEM NOTIFICATION` (heurística, no está documentado un campo); corregir el texto viejo "No resuelvas la decisión de fondo en Sonnet" (con el ADR 0018 la sesión principal es Opus medium) por "`reasoner` (Opus, effort high)". El hint de skills de `.agents/critical.json` queda igual.
- Aplicar la misma heurística de notificación en `intent-router.sh`.
- Tests: casos nuevos en `scripts/test-intents.sh` (CAO_TERMINAL_ID: start silencioso, bash silencioso, mcp activo) y `scripts/test-packs.sh` (dedupe, plan mode, notificación, hint intacto).

### Fase 2 — Presupuesto de contexto (agents-config)
- `config/CLAUDE.md` a ≤60 líneas / ≤3,2 KB (ADR 0004): sacar la lista de skills que repite la lista de skills y las que no son globales; dejar solo las reglas de elección entre skills que se pisan, el routing de agentes en un solo lugar y la nueva sección **Workflow lanes**.
- **Workflow lanes** (camino S inline, sin brainstorming ni plan; camino L brainstorming, writing-plans, worker/reasoner o caolg; causa desconocida primero `systematic-debugging`; el plan termina con "Camino S/L porque…"). PonyTail: mencionado como opcional para S, con los comandos de instalación para que Loren lo pruebe; no se instala.
- `config/hooks/session-start.sh`: texto de routing más corto (la regla vive en `config/CLAUDE.md`).
- Dedupe sin perder reglas: `config/profiles/loren.md` pierde lo que ya dice `config/AGENTS.md` (desktop config, coaching de inglés) y deja solo lo personal; `AGENTS.md` conserva las reglas genéricas. Tests de `gen-intents.sh --check` intactos (no se toca el bloque `intents:`).
- `config/agents/scout.md`: `omitClaudeMd: true` (los scouts son solo lectura y no necesitan las reglas; ahorra ~4–7k tokens por invocación). Verificar que el frontmatter lo acepta con una llamada real a `scout`.

### Fase 3 — Baseline para todos los CLIs (agents-config)
- Nuevo `scripts/gen-cli-baselines.sh [--dry-run] [--target gemini|copilot|opencode|opencode-cao|all]`: genera, con marcador de archivo generado y backup si hay un archivo ajeno (misma lógica que `write_generated` de `install.sh:214-246`), el contenido de `config/baseline.md` en `~/.gemini/GEMINI.md`, `~/.copilot/copilot-instructions.md` (solo si `copilot instruction list` lo muestra), `~/.config/opencode/AGENTS.md` y, con `opencode-cao`, `~/.aws/opencode/AGENTS.md`.
- `install.sh`: flag opt-in `--with-cli-baselines` (patrón de `--with-integrations`); con `--dry-run` no escribe. Header de ayuda actualizado.
- Verificación: `--dry-run` + escribir en un `HOME` temporal; no se escribe en el `HOME` real.

### Fase 4 — AGENTS.md primero en los proyectos (project-init, worker en paralelo con la fase 5)
- `devops/project-init/templates/common/AGENTS.md`: nueva sección **Critical rules** entre `<!-- baseline:start -->` y `<!-- baseline:end -->` (las 7 reglas de `baseline.md` en inglés compacto, ~150 tokens) y línea "Read `.agents/CONTEXT.md` before exploring". Es lo que leen Claude (principal y subagentes), Codex, Copilot, OpenCode y agy en ese repo.
- `templates/common/CLAUDE.md`: se deja de generar. `init.sh` solo la crea con `--claude-shim`. La tabla de fases de superpowers sale de la plantilla (la cubre Workflow lanes).
- `scripts/adopt.sh`: caso 3 (AGENTS.md existente) también agrega la sección Critical rules si falta; los casos 1 y 2 y los `CLAUDE.md` existentes no cambian (nunca se borra ni se pisa nada).
- Tests de `devops/project-init/scripts/test-manifest.sh` y `test-docs-check.sh`: actualizar lo que asuma `CLAUDE.md`. `workspace.sh` no se toca (fuera de alcance; anotado).
- ADR **0019** `agents-md-first`: AGENTS.md estándar y fuente; CLAUDE.md opcional; regla de bloqueo por `CLAUDE.md` en directorios superiores; `InstructionsLoaded` ciego; subagentes; trade-off de la duplicación del baseline (~0,2k tokens en Claude, que ya lo carga globalmente).

### Fase 5 — caolg (rama `refactor/context-sync`, worker en paralelo)
- Perfiles `profiles/*.md`: "tu worktree actual" a "tu carpeta de trabajo (la de tu rol, ADR 0005)"; unificar la regla de commits con la de los roles ("commits solo si la tarea lo pide, Conventional Commits; nunca push"). Las líneas de secretos, no-push e instrucciones inyectadas **se quedan** en cada perfil: los workers de agy/Copilot/OpenCode van con permisos automáticos y el baseline global es opcional.
- `docs/prompts.md` nuevo (convención de agents-config): copia textual de los prompts que caolg manda (perfiles, saludo de `bin/caolg-session`, mensajes de `bin/caolg-clear`, descripción de `caolg-mcp`), dónde viven y historia breve.
- Textos viejos: `AGENTS.md:13` y `.agents/CONTEXT.md:4-5` ("/clear automático"), `README.md:74,103-110` (worktree, relee), `codex/cao-safe.config.toml:2` ("Se enlaza"). Sin `CLAUDE.md` nuevo: con AGENTS.md y sin CLAUDE.md arriba, Claude 2.1.319 lo lee solo.
- Regla de push: **no se cambia** (es un pedido explícito de Loren). ADR `0008-push-sin-confirmar` registra la excepción al baseline #6 (baseline #7).
- `install.sh`: tras `caolg-mcp --ensure` (línea 33), llamada protegida a `~/projects/agents-config/scripts/gen-cli-baselines.sh --target opencode-cao` si existe (mismo estilo no fatal de las líneas 12 y 33).
- Verificación: `python3 -m unittest discover tests` y `bash -n` de los scripts de `bin/`.

### Fase 6 — Contrato del statusline (agents-config)
- ADR **0021** `statusline-cache-contract` y comentario de cabecera en `config/hooks/statusline.sh` con los archivos y campos que caolg lee: `~/.cache/claude/rate-limits.json` y `~/.cache/claude/ctx/$CAO_TERMINAL_ID.json`.
- Ya cubierto: ADR **0020** `cao-aware-hooks-and-context-budget` (fases 1 y 2, lanes y PonyTail opcional).

### Fase 7 — Verificación y artefactos
1. `scripts/test-intents.sh`, `test-packs.sh`, `test-orgs.sh`, `test-leak-guard.sh`, `gen-plugin.sh --check`, `gen-intents.sh --check`, `devops/project-init/scripts/test-manifest.sh`, `test-docs-check.sh`, `scripts/leak-guard.sh --staged`, `./install.sh --dry-run --with-cli-baselines`. En caolg: unittest y `bash -n`.
2. Re-medir con `wc -c` la cadena de carga (memoria global, `config/CLAUDE.md`, plantilla de AGENTS.md) y comparar con el antes del artefacto 1.
3. **Artefacto 2** (nuevo, `Artifact` con el archivo `agents-structure-map.html` en el scratchpad; `artifact-diagramming` ya cargado): (a) ciclo de una petición: prompt, hooks, camino S/L, modo plan, subagentes `scout`/`worker`/`reasoner`, hooks dentro del subagente, caolg para L cross-repo; (b) árbol de carpetas anotado: hub, `~/.claude`, `~/.codex`, `~/.gemini`, `~/.config/agents-config`, el repo del proyecto (`AGENTS.md`, `.agents/*`, `.claude/*`, `docs/*`) y los datos de caolg (`~/.local/share/caolg`, `.caolg-tasks/`), con quién lee cada nodo; (c) matriz "quién lee qué": sesión principal, subagentes, Explore/Plan, Codex, agy/Copilot/OpenCode, workers CAO; (d) respuesta a "¿reemplazar CLAUDE.md por AGENTS.md?" con condiciones; (e) tamaños medidos después del refactor.
4. Republicar el artefacto 1 (misma URL, mismo archivo) corrigiendo "Claude no lee AGENTS.md" y el pendiente del espejo de Codex.
5. Resumen final: qué se corrió, qué no, qué queda sin verificar (`omitClaudeMd`, archivo personal de Copilot, GEMINI.md en agy, heurística de notificaciones). Sin push; merge solo con el OK de Loren.

## Delegación
- Inline (≤3 archivos conocidos): fases 1, 2 (config), 3, 6.
- `worker` (Sonnet) con spec + comando de aceptación, en paralelo y en repos distintos: fase 4 (project-init, aceptación `test-manifest.sh` + `test-docs-check.sh`) y fase 5 (caolg, aceptación `python3 -m unittest discover tests` + `bash -n`).
- Decisiones ya tomadas; no hace falta `reasoner`.

## Archivos críticos
agents-config: `config/hooks/{session-start,critical-reasoning,intent-router,statusline}.sh`, `config/CLAUDE.md`, `config/profiles/loren.md`, `config/agents/scout.md`, `install.sh`, `scripts/gen-cli-baselines.sh` (nuevo), `devops/project-init/templates/common/AGENTS.md`, `devops/project-init/scripts/{init,adopt}.sh`, `scripts/test-intents.sh`, `scripts/test-packs.sh`, `docs/decisions/00{19,20,21}-*.md`. caolg: `profiles/*.md`, `AGENTS.md`, `.agents/CONTEXT.md`, `README.md`, `install.sh`, `docs/prompts.md` (nuevo), `docs/decisions/0008-*.md`.
Reutilizar: `write_generated` y `link` de `install.sh`, el patrón de marcador por sesión de `intent-router.sh`, `has_real_content`/`write_file`/`skip` de `adopt.sh`.

## No verificado de antemano
- `omitClaudeMd` en `scout.md` (documentado, sin probar en 2.1.319).
- `~/.copilot/copilot-instructions.md` como archivo personal (se comprueba con `copilot instruction list`).
- Que agy lea `~/.gemini/GEMINI.md` bajo CAO.
- La heurística de `<task-notification>` (no hay campo documentado).
- Si SessionStart y UserPromptSubmit llegan a subagentes (no documentado).
