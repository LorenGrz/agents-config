# config/: la configuración global

## Purpose

Es la capa global, la de toda la máquina. `install.sh` (en la raíz del repo) genera o enlaza estos archivos
en `~/.claude/` y `~/.codex/`, combinados con tu perfil (`<repo>` es donde clonaste el repo):

```
~/.claude/CLAUDE.md        generado: @-imports de config/AGENTS.md, config/baseline.md,
                           config/profiles/<name>.md, config/CLAUDE.md y organizations/INDEX.md si existe
~/.codex/AGENTS.md         generado: config/AGENTS.md, config/baseline.md, el perfil e INDEX.md concatenados
                           (sin config/CLAUDE.md; Codex no tiene @-import)
~/.claude/rules/<rule>.md  un symlink por regla global de <repo>/config/rules (ver scopes.json)
~/.claude/hooks            symlink a <repo>/config/hooks
~/.claude/agents           symlink a <repo>/config/agents
~/.claude/keybindings.json symlink a <repo>/config/keybindings.json
~/.claude/skills/<name>    espejo plano de <repo>/skills/<category>/<name>/ (lo arma sync.sh)
~/.agents/skills           symlink a <repo>/skills (raíz compartida con otros agentes; se omite si el
                           hub está clonado ahí mismo)
~/.gemini/config/skills    symlink a ~/.claude/skills (lo crea sync.sh, para Antigravity)
```

`install.sh` además mergea `settings.base.json` en `~/.claude/settings.json` (siempre con backup antes):

- `statusLine`, `model` y `effortLevel`: gana la base. `modelSettings`: merge profundo, la base gana en las
  claves que define.
- `hooks`: quedan las entradas de la base y, después de ellas en su evento, las que ya tenías y no corren un
  hook del hub (las de otra herramienta, como Orca). Una entrada es del hub si un comando suyo corre un script
  de `~/.claude/hooks/`; esas se reemplazan por las de la base, y si mezclaba comandos conserva los ajenos
  (ADR 0038).
- `theme`: el de la base solo si el archivo no tiene uno (ADR 0038).
- `permissions.defaultMode`: gana la base cuando la define.
- `enabledPlugins`, `extraKnownMarketplaces`, `env` y `pluginConfigs`: unión; la base gana solo en claves
  en conflicto y lo que agregaste vos se queda. Con PonyTail activo crea una vez `~/.claude/.ponytail-band`
  en `off` (ADR 0023).
- `permissions.allow` y `permissions.ask`: unión sin duplicados.
- Cualquier otra clave que ya tengas (por ejemplo, la config de auto-aprobación de tu máquina) queda igual.

Nunca borra un archivo real: lo que no generó él se mueve a `<path>.bak.<timestamp>` antes de escribir.

`AGENTS.md` y `CLAUDE.md` son genéricos: se comparten con cualquiera que clone el repo, sin nombres ni rutas
personales. Lo personal va en `profiles/<name>.md`. Se edita acá, se commitea y se pushea; si mantenés un
clon espejo personal, lo sincronizás vos (el repo no lo sigue).

## Layout

| Ruta | Qué es | Quién lo lee |
|---|---|---|
| `AGENTS.md` | Instrucciones para cualquier agente, genéricas | Claude Code (import en `~/.claude/CLAUDE.md`) y Codex (concatenado); `scripts/gen-intents.sh` mantiene al día su bloque Shortcuts |
| `CLAUDE.md` | Secciones solo de Claude Code (skills, lanes, ruteo de agentes) | Claude Code |
| `baseline.md` | Reglas no negociables para todo proyecto y organización | Claude Code y Codex; `install.sh --with-cli-baselines` también lo escribe para agy, Copilot y OpenCode |
| `profiles/` | Contenido personal, un archivo por persona (`_template.md` para empezar) | `install.sh`, que importa el perfil activo |
| `rules/` | Reglas por ruta (ver «rules/») | Claude Code, por archivo, cuando la ruta coincide |
| `hooks/` | Scripts de hooks (ver «hooks/») y la statusline | Claude Code, por `settings.json` |
| `agents/` | `scout.md`, `worker.md`, `reasoner.md`, `reviewer.md`: los subagentes con modelo fijo | Claude Code (`~/.claude/agents`) y el plugin |
| `settings.base.json` | Base sin secretos que se mergea en `~/.claude/settings.json`: permisos, modelo, hooks, `statusLine`, `enabledPlugins`, `extraKnownMarketplaces`, `env`, tema. Sin bloque `autoMode` de la máquina | `install.sh` |
| `keybindings.json` | Alt+P plan, Alt+M selector de modelo, Ctrl+Alt+G vista de agentes de Orca | Claude Code (symlink) |
| `scopes.json` | Qué skills, reglas, MCP y plugins son de cada stack; lo que no figura es global (ADR 0011) | `install.sh`, `sync.sh`, `scripts/project-agents.sh` |
| `mcp.user.json` | Servidores MCP de usuario (`notebooklm`, `obsidian`), sin secretos | `install.sh --with-integrations` |
| `intents.json`, `intents.plugins.md` | Tabla de intenciones generada desde la sección Shortcuts de cada skill; los atajos de plugins que no pueden vivir en el plugin | `hooks/intent-router.sh`; lo escribe `scripts/gen-intents.sh` |
| `patches/` | Parches locales e idempotentes a plugins de terceros (`paste-preview-no-autoedit.sh`) | `install.sh` |
| `rulesync/` | Generación para Codex CLI, Cursor y Antigravity (ver «rulesync/») | `rulesync`, por `build.sh` |
| `orca/` | Orca: `settings.json` (preferencias sin cuentas, cookies, rutas ni telemetría) y `omarchy/` (el tema de Omarchy en Orca: hooks de theme-set y font-set, `orca-omarchy-settings` y plantillas) | `scripts/orca-setup.sh` en una PC nueva; `scripts/orca-settings.py export` las vuelve a guardar (ADR 0056) |

Las skills no están acá: viven en `skills/<category>/<skill>/` y `sync.sh` las espeja en `~/.claude/skills`.

**No se versiona** (local de la máquina o secreto): `~/.claude/settings.json` (el real, ya mergeado),
`settings.local.json`, `.credentials.json`, `sessions/`, `projects/` (auto-memory y transcripts), logs y
caches.

> Las sesiones de Cowork en el escritorio ignoran un `~/.claude/rules/` enlazado fuera del directorio de
> trabajo. Este setup apunta a Claude Code CLI, donde las reglas enlazadas cargan bien.

### Qué carga y cuándo

| Qué | Cuándo | De dónde |
|---|---|---|
| `CLAUDE.md` / `AGENTS.md` | Cada sesión, completo, antes del primer mensaje | `config/CLAUDE.md` (Claude Code), `config/AGENTS.md` (Codex y otros) |
| Skills | Solo la `description`, hasta que la tarea coincide y el modelo la invoca | `~/.claude/skills/<name>/SKILL.md` |
| Reglas | Solo cuando un archivo tocado coincide con su `paths:` | `config/rules/*.md` |
| Hooks | Los ejecuta el harness en un evento; el modelo no los lee | `config/hooks/*.sh`, registrados en `~/.claude/settings.json` |
| Subagentes (`scout`, `worker`, `reasoner`, `reviewer`) | Cuando se los lanza, cada uno con su modelo | `config/agents/*.md` |
| Auto-memory | La carga el harness al iniciar, fuera de este repo | `~/.claude/projects/.../memory/` |

### rules/

Cada regla carga solo cuando Claude toca un archivo que coincide. Globales: `security.md`, `testing.md` y
`typescript.md`; las demás son de un stack en `scopes.json` y las instala `scripts/project-agents.sh`.

| Archivo | Carga en | Para qué |
|---|---|---|
| `typescript.md` | `**/*.ts(x)` | tipado estricto, validación en los bordes |
| `react.md` | `**/*.tsx`, `**/*.jsx` | cero `useEffect` para lógica, los hooks cargan datos, separación presentacional/contenedor, Vitest+RTL |
| `next.md` | archivos de `app/` de Next, `next.config.*`, `middleware.ts`/`proxy.ts` | carga de datos RSC primero, Server Actions, reglas de límite de cliente y secretos |
| `nestjs.md` | sufijos de Nest (`.module`, `.controller`, `.service`, `.resolver`) | capas de clean architecture |
| `java.md` | `**/*.java` | Java 21 y Spring Boot: lenguaje, Spring y tests; la estructura de paquetes la da el ADR de arquitectura |
| `kotlin.md` | `**/*.kt(s)` | Spring Boot en capas (domain / service / controller / mapper), Kotest |
| `python.md` | `**/*.py` | uv/ruff/mypy, pydantic, confiabilidad de scripts de agentes |
| `testing.md` | `*.test.*`, `*.spec.*`, `*.e2e-spec.ts` | comportamiento antes que implementación |
| `security.md` | archivos de servidor y de config | authz, tokens, CSRF/CORS, validación de entrada, secretos, manejo de errores |

### hooks/

Registrados en `settings.base.json` (la fuente de verdad del cableado). La columna Plugin dice si el método
del marketplace también lo trae: `scripts/gen-plugin.sh` arma `hooks/hooks.json` en la raíz con todos menos
`guard-omarchy.sh`, `rtk.sh` y `marcar-capturas.sh`. Los que «niegan» bloquean la herramienta; `format-file.sh` reescribe el archivo
editado, `worker-commit.sh` reescribe el `git commit` suelto de un worker, `marcar-capturas.sh` escribe imágenes marcadas junto a las capturas y `worktree-cleanup.sh` borra worktrees; el resto solo agrega contexto.

| Script | Evento | Qué hace | Plugin |
|---|---|---|---|
| `guard-omarchy.sh` | PreToolUse (Edit\|Write\|MultiEdit) | niega ediciones bajo `~/.local/share/omarchy/` | no |
| `scout-readonly.sh` | PreToolUse (Bash) | solo dentro del subagente `scout`: deja pasar comandos de lectura y niega escrituras y flags que modifican | sí |
| `rtk.sh` | PreToolUse (Bash) | pasa los comandos de lectura o verificación (git status/diff/log, ls, find/grep, lint/test/tsc) por [rtk](https://github.com/rtk-ai/rtk) para comprimir la salida; el resto sigue el flujo normal de permisos. Sin rtk no hace nada | no |
| `worker-commit.sh` | PreToolUse (Bash) | en un worker supervisado de Orca (o un agente de stack-sync con marca viva), en su worktree y en una rama que no es base, reescribe un `git commit` suelto en una línea (solo `-m`/`--message` entre comillas sin `$`, `-q`, `-a`, `-F <archivo>` y `--no-edit` en un merge) a `worker-commit.sh --token <t>`, que el `ask` de `git commit *` de un repo no frena. No interpreta bash: en un worker, un comando compuesto o multilínea con un `git commit` se niega con el motivo «mandá `git add` y `git commit` en comandos aparte»; `--amend`, `--no-verify` o un `deny` de `git commit` dejan el diálogo. No concede permisos (ADR 0062) | sí |
| `critical-reasoning.sh` | UserPromptSubmit, PreToolUse (Edit\|Write\|MultiEdit) | si el pedido o el archivo parecen caros de errar (arquitectura, bugs sin causa, seguridad, migraciones, prod, IAM), recuerda la pregunta Continuar / Plan S / Plan L y que en Plan L decide `reasoner`, una vez por sesión. Suma la skill de `.agents/critical.json` del proyecto que coincida (máx. 2). Callado en subagentes y en plan mode | sí |
| `intent-router.sh` | UserPromptSubmit, PreToolUse (Bash y MCP de integraciones) | frase natural («traete los cambios») -> «skill X; corré `git pull origin <base>`»; primera llamada a `gh`, `git push` o a un MCP de Slack, Jira, GitHub, Google, Obsidian o NotebookLM -> «cargá la skill X». Una vez por sesión y skill, callado en subagentes | sí |
| `lane-guard.sh` | PreToolUse (AskUserQuestion\|ExitPlanMode) | niega una pregunta de lanes que no esté en el orden Continuar, Plan S, Plan L (o Continuar, Orquestar, ADR 0039), y un `ExitPlanMode` de Plan L sin la entrevista de `mattpocock-skills:grilling` desde que se entró a plan mode (ADR 0025, 0031). No revisa subagentes | sí |
| `orquestar.sh` | PostToolUse (AskUserQuestion) | si el usuario eligió «Orquestar», inyecta el procedimiento fijo: un líder por worktree como sesión aparte (Orca, T3 Code), en paralelo, con su brief, y antes los imports del `CLAUDE.md` aprobados con `scripts/approve-claude-imports.sh` (ADR 0039). No revisa subagentes | sí |
| `marcar-capturas.sh` | PostToolUse (Bash) | después de un `node pr-screenshots.mjs`, marca cada par antes/después de su `--out` con el `marcar-cambios.sh` de la primera skill instalada que lo traiga (o `$MARCAR_CAPTURAS`): recorte con recuadro y pantalla entera; los pares iguales quedan «sin cambios». Le dice a la sesión qué archivos subir. Sin marcador, callado; también con `--login` y en subagentes | no |
| `format-file.sh` | PostToolUse (Edit\|Write\|MultiEdit) | formatea el archivo con las herramientas del proyecto: prettier o eslint `--fix` (TS/JS), `ktlint -F` (Kotlin), `ruff` (Python). Saltea las rutas listadas en `~/.claude/format-skip` | sí |
| `session-start.sh` | SessionStart | reinyecta la regla de ruteo (lanes, `worker`, `scout`, reviewer, «con brief no se pregunta la lane»); en repos de 200 archivos o más pide crear `.agents/CONTEXT.md` o refrescarlo si está 30 commits atrás; repo sin `AGENTS.md` -> proponer `project-init`; repo sin skills de su stack -> proponer `project-agents.sh --stack <detectado> --dry-run`; carpeta workspace -> leer su `AGENTS.md`; carpeta que no es ni repo ni workspace -> un aviso (si tiene 2 o más repos los nombra y ofrece el modo workspace) | sí |
| `worktree-cleanup.sh` | SessionStart | borra los worktrees limpios cuyo PR está mergeado en GitHub con el mismo head, o (sin PR) cuya rama entró a `origin/<default>` por un merge `--no-ff`, y su rama local; presupuesto de ~10 s; a mano: `--cwd <dir> [--dry-run]` (ADR 0030, 0053) | sí |
| `stop-git-status.sh` | Stop | muestra los cambios sin commitear si estás en un repo git | sí |
| `log-instructions.sh` | InstructionsLoaded | anota sesión, cwd y `file_path`/`memory_type`/`load_reason`/`trigger_file_path` en `~/.claude/logs/instructions-loaded.log` | sí |

`statusline.sh` no es un hook: es la `statusLine` de `settings.base.json`. Muestra modelo, esfuerzo, contexto
y uso de 5h/7d con el tiempo al reset, en ASCII, con colores por umbral y adaptada al ancho de la terminal
(`NO_COLOR` apaga los colores). Tampoco viene en el plugin.

### Alcance global o por proyecto

`scopes.json` decide qué es global y qué es de un stack (ADR 0011); lo que no figura es global.
`install.sh` y `sync.sh` instalan solo lo global. Lo de un stack se copia al `.claude/` del proyecto (se
commitea) y los MCP se mergean en `.mcp.json`:

```bash
scripts/project-agents.sh --stack nestjs,aws,supabase --dir ~/projects/my-app
# project-init hace lo mismo: init.sh --stack nestjs --with aws,supabase ...
```

Stacks: `react-vite`, `next`, `nestjs`, `node-ts`, `rn`, `aws`, `python`, `kotlin`, `java-spring`,
`kotlin-spring`, `apex`, `docker`, `llm`, `office`, `supabase`, `jira`.

Los plugins siguen la misma regla: `vercel` y `playwright` están apagados en `settings.base.json` y la lista
`plugins` de un stack los prende en el `.claude/settings.json` de ese proyecto (`next`: los dos;
`react-vite`: `playwright`); `--plugin vercel,playwright` los fuerza. Los plugins en `true` de
`settings.base.json` quedan globales, igual que los MCP de usuario de `mcp.user.json` (ADR 0016).

### rulesync/

`install.sh --with-rulesync` corre `rulesync/build.sh`, que rearma `.rulesync/` (ignorado) desde
`config/AGENTS.md`, `config/rules/*.md` y tres skills de prueba (`project-init`, `typescript-code-quality`,
`react-component-validator`), y después `pnpm dlx rulesync generate` en modo global, con las features
`rules` y `skills`, para `codexcli`, `antigravity-cli` y `cursor`. Cursor no recibe reglas globales (rulesync
solo las soporta por proyecto); Codex ya tiene su `~/.codex/AGENTS.md` generado por `install.sh`. Detalle y
destinos de cada herramienta: ADR 0002.

### Presupuesto de contexto

`config/CLAUDE.md` carga en cada sesión: el tope es 60 líneas y 4.2 KB (ADR 0004, revisado en 0020). El
detalle poco usado va a la skill que lo trata (por ejemplo, el roadmap vive en `references/` de
`roadmap-coach`). Para medir el gasto real: `npx ccusage@latest` (`install.sh` lo recuerda al terminar).
`rtk` es opcional (`install.sh --with-rtk` lo instala; su hook ya está registrado). Entre tareas sin relación,
`/clear` en vez de `/compact`.

### Setup por repo

Este árbol es global. La config de cada repo (`AGENTS.md`, `.claude/settings.json` con mattpocock-skills, hooks
de rama y lint, CI, GitHub Project) sale de la skill `skills/devops/project-init`, una vez por repo nuevo.
`scripts/project-agents.sh --manifest <file> [--org <name>]` instala los packs que pide el manifiesto de la
entrevista. Tests de project-init: `test-manifest.sh` y `test-docs-check.sh` (offline) y `e2e.sh --stack
<name|all>` (necesita red), en `skills/devops/project-init/scripts/`.

## How to add

- **Regla**: crear `rules/<stack>.md` con una lista `paths:` entre comillas en el frontmatter, después
  `# <Stack>` y secciones `## <Tema>` con bullets imperativos. `rulesync/build.sh` convierte cada entrada de
  `paths:` en una de `globs:`, así que cada entrada va como string entre comillas dobles en su propia línea
  `- `. Si es de un stack, sumarla en `scopes.json`, y agregar una fila a la tabla de reglas de arriba.
- **Agente**: crear `agents/<name>.md` con frontmatter `name`, `description`, `model`, `tools`, una frase de
  rol y después `## Before`, `## Do`, `## Never`, `## Return`.
- **Hook**: agregar el script a `hooks/`, registrarlo en `settings.base.json`, correr `scripts/gen-plugin.sh`
  (copia los hooks a `hooks/hooks.json` de la raíz, salvo los de `LOCAL_ONLY` de ese script) y agregar una
  fila a la tabla de hooks de arriba.
- **Perfil**: copiar `profiles/_template.md` a `profiles/<name>.md`, respetando el orden de secciones.
- **Skill**: no va acá; ver `skills/` y `skills/devops/project-init`. Después de agregar una, correr `sync.sh`.

## Checks

- `bash scripts/lint-docs.sh --strict --files config/rules/*.md` revisa el frontmatter `paths:` de cada regla.
- `bash scripts/test-cli-baselines.sh` y `bash scripts/test-packs.sh` revisan los baselines y los packs.
- `bash scripts/test-lane-guard.sh`, `bash scripts/test-orquestar.sh`, `bash scripts/test-worktree-cleanup.sh`, `bash scripts/test-marcar-capturas.sh` y `bash scripts/test-worker-commit.sh` revisan esos hooks.
- `./install.sh --dry-run` muestra qué enlazaría o escribiría, sin tocar `~/.claude`.
- `bash scripts/gen-intents.sh --check` compara `intents.json` y el bloque Shortcuts de `AGENTS.md` con las
  skills.
