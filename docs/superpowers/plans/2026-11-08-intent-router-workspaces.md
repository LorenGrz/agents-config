# Plan: intent router + workspaces + plugins por proyecto (agents-config)

## Context
Loren quiere que agents-config resuelva tres capas sin depender de que yo "me acuerde":
1. **Global**: una frase natural ("traete los cambios") o el uso de una integración (GitHub, Slack, Jira,
   Google, Obsidian, NotebookLM) me lleva a la skill correcta y al comando exacto que esa skill dicta
   (`git pull origin <base>`). Hoy las skills existen (`productivity/*-usage`, `devops/git-workflow`) pero
   solo se activan por la prosa de `config/CLAUDE.md`; ningún hook las dispara.
2. **Proyecto / workspace**: al abrir Claude en un repo sin config → proponer `project-init`; en un repo
   con AGENTS.md sin skills de stack → proponer `project-agents.sh`; en un **workspace** (carpeta no-git
   con varios repos, ej. `~/work/<org>/<producto>` con front + back) → config propia de workspace; en carpetas
   sueltas (`~`, `~/projects`) → aviso de una línea.
3. **Plugins**: los 11 están activos en todas las sesiones. Vercel y Playwright pasan a ser por proyecto;
   las skills de plugins entran al routing, se resuelven duplicados, tienen atajos y quedan en Obsidian.

Ya existe (no rehacer): ADR 0016 (plugins, MCP de usuario, `permissions.ask` para acciones hacia afuera),
`critical-reasoning.sh` (patrón keyword→skill vía `.agents/critical.json`), `session-start.sh` (routing +
mapa de repos grandes), packs con `index`, `scripts/export-obsidian.sh` (ya exporta skills de plugins
habilitados en `settings.base.json`), `scripts/gen-plugin.sh` (regenera `hooks/hooks.json`).

Fuera de alcance: los repos de ejemplo de la empresa (frontend y backend del workspace de ejemplo; no se tocan).

## Decisiones tomadas con Loren
- Atajos definidos **dentro de cada SKILL.md** (sección `## Shortcuts`); el hook inyecta **skill + comando**.
- Disparadores: tools MCP, comandos Bash (`gh`, `git …`) y frases del prompt. **1 vez por sesión por skill.**
  Nunca bloquea (guidance, exit 0, silencioso en subagentes). Las acciones hacia afuera siguen pidiendo OK.
- Rama base **por repo**: `scripts/gh-flow.sh` o AGENTS.md → org (`org.json defaults.base_branch`) →
  `origin/HEAD` → `main`.
- Frases ES + EN; yo propongo la lista (abajo), Loren la aprueba.
- Atajos también para otros agentes: tabla corta generada en `config/AGENTS.md`.
- Plugins globales: superpowers, skill-creator, claude-obsidian, codex, mattpocock, karpathy, claudex,
  paste-preview. Por proyecto: vercel + playwright (`next` → ambos, `react-vite` → playwright, `--plugin` fuerza).
- Workspace = carpeta no-git con `AGENTS.md` en la raíz (marcador explícito). Contenido: mapa de repos,
  políticas de la org, skills de la org compartidas, flujos cruzados. Lo crea **project-init en modo workspace**.
  Fuente: org → `organizations/<org>/workspaces/<name>/` (repo privado) linkeado al workspace;
  personal → `git init` en el workspace (ignora subrepos), remoto solo con OK.
- Fuera de repo/workspace: aviso de una línea. Textos de hooks en inglés.
- Ejecución: rama `feat/intent-router` en agents-config, PR con OK antes del push; `worker` para las
  secciones Shortcuts; `scout` para el inventario de duplicados.

## Pasos

### 1. Formato de atajos en skills (fuente única)
Sección al final de cada SKILL.md:
```md
## Shortcuts
<!-- parsed by scripts/gen-intents.sh -->
- tools: `mcp__claude_ai_Slack__.*`
- intent: `traete los cambios|tra[eé] los cambios|baj[aá] los cambios|pull (the )?changes` → `git pull origin <base>`
```
Skills: `devops/git-workflow`, `productivity/{github-usage,slack-usage,jira-usage,google-workspace-usage,
obsidian-vault,notebooklm-obsidian-sync,codex-review}`. Las skills de plugins no se pueden editar (el
update las pisa): sus atajos van en `config/intents.plugins.md` con el mismo formato (excepción forzada).

### 2. `scripts/gen-intents.sh` (nuevo)
Parsea las secciones → `config/intents.json` (derivado, no se edita a mano: `{skill, tools, intents:[{re, cmd}]}`)
y escribe la tabla compacta en `config/AGENTS.md` entre `<!-- intents:start/end -->` (≤15 líneas).
`--check` para CI/pre-commit. Lo llaman `sync.sh` y `gen-plugin.sh --check`.

### 3. Hook `config/hooks/intent-router.sh` (nuevo)
- `UserPromptSubmit`: regex de `intents` contra el prompt (lowercase) → máx. 2 matches.
- `PreToolUse`: matcher `Bash|mcp__claude_ai_GitHub__.*|mcp__claude_ai_Slack__.*|mcp__claude_ai_Atlassian_Rovo__.*|mcp__claude_ai_Gmail__.*|mcp__claude_ai_Google_.*|mcp__obsidian__.*|mcp__notebooklm__.*`;
  Bash solo si el comando empieza con `gh ` o `git (pull|push|merge|commit|checkout|switch|rebase)`.
- Salida: `Shortcut (agents-config): "<intent>" -> skill <x>; run <cmd con <base> resuelto>. Outbound actions still need the user's OK.`
- Marcador por sesión: `${XDG_RUNTIME_DIR:-/tmp}/agents-intents/<session_id>/<skill>`.
- Silencioso si `agent_type` está presente; siempre exit 0; patrón tomado de `critical-reasoning.sh`.
- Registrar en `config/settings.base.json` → `scripts/gen-plugin.sh` regenera `hooks/hooks.json`.

### 4. Lista inicial de frases (para aprobar)
| Skill | Frases (ES/EN) | Acción |
|---|---|---|
| git-workflow | traete/traé/bajá los cambios, actualizá la rama, pull | `git pull origin <base>` |
| git-workflow | nueva rama para…, new branch | `git fetch && git checkout -b <type>/<slug> origin/<base>` |
| git-workflow | commiteá, hacé commit, commit | flujo commit (Conventional Commits) |
| git-workflow | subí/pusheá los cambios, push | flujo push (pide OK) |
| git-workflow | abrí un PR, open a PR | `gh pr create --base <base>` (pide OK) |
| github-usage | issue(s), PR #n, revisá el PR, review PR | `gh` con checkout; conector claude.ai sin checkout |
| slack-usage | slack, canal #…, qué dijeron en, mandale a | buscar/leer; enviar = draft + texto aprobado |
| jira-usage | jira, ticket, `[A-Z]+-\d+`, sprint, confluence | `getJiraIssue` / JQL; escrituras con OK |
| google-workspace-usage | mail, correo, gmail, calendario, reunión, drive, sheet | leer libre; enviar/agendar con OK |
| obsidian-vault | obsidian, nota(s), vault | MCP obsidian, convención `projects/<slug>/` |
| notebooklm-obsidian-sync | notebooklm, cuaderno | sync según la skill |
| codex-review | revisalo con codex, segunda opinión, codex review | `/codex:review` |
(Sin términos de la org: `leak-guard.sh` y `org.json blocklist_terms`.)

### 5. Plugins por proyecto
- `config/settings.base.json`: vercel y playwright → `false`. Ojo: `install.sh:346` hace unión
  `cur + base` (base gana) → el próximo install los apaga en live, que es lo buscado.
- `config/scopes.json`: clave nueva `plugins` por stack (`next`: vercel + playwright; `react-vite`: playwright).
- `scripts/project-agents.sh`: escribe `enabledPlugins` en `<repo>/.claude/settings.json` (merge, nunca
  pisar) + flag `--plugin a,b`.
- `scripts/export-obsidian.sh`: incluir también plugins de `scopes.json` (hoy solo lee los `true` de base).

### 6. Skills de plugins: duplicados, routing, docs
- `scout`: inventario skills de plugins vs hub (code-review, tdd, debugging, prototype, wiki…) → tabla de solapes.
- **Checkpoint con Loren**: elige una skill por tarea. No se decide sin él.
- Resultado → filas en el Routing de `config/CLAUDE.md` (corto) + atajos en `config/intents.plugins.md`.
- Verificar si Claude Code permite desactivar skills sueltas de un plugin (p. ej. regla de permisos
  `Skill(...)`); si no, el routing es la única vía.

### 7. SessionStart (`config/hooks/session-start.sh`, extender)
Casos por cwd (se mantiene routing + mapa de repos grandes):
- repo git sin AGENTS.md → "ask the user whether to run project-init (adopt.sh if the repo has code)".
- repo con AGENTS.md sin `.agents/project.json` ni `.claude/skills` → detectar stack con
  `scripts/detect-stack.sh` (nuevo: package.json next/@nestjs/core/vite/react-native, pyproject,
  gradle+spring, template.yaml, supabase/) → proponer `project-agents.sh --stack X --dry-run`.
- carpeta no-git con AGENTS.md → workspace: "read AGENTS.md; stack skills live in each repo (listed as `<repo>:<skill>`)".
- carpeta no-git sin AGENTS.md → una línea: solo config global, abrí Claude en el repo o workspace.

### 8. project-init modo workspace
- `devops/project-init/SKILL.md`: sección "Workspace mode" (carpeta no-git con ≥2 repos hijos).
- `devops/project-init/scripts/workspace.sh` (nuevo): entrevista mínima (repos y rol, cómo se comunican,
  flujos cruzados, org), genera `AGENTS.md` (mapa, ref a `POLICIES.md`, flujos cruzados), `CLAUDE.md` = `@AGENTS.md`,
  `.claude/skills` con skills de la org sin filtro de stack.
- Org: fuente en `organizations/<org>/workspaces/<name>/`, symlinks al workspace (commit en el repo privado de la org, con OK).
- Personal: `git init` en el workspace + `.gitignore` de los subrepos; remoto solo con OK.
- Verificar que Claude Code descubre `.claude/skills` de los repos hijos al abrir en el workspace
  (skills con prefijo de directorio); si no, el AGENTS.md del workspace lo indica.

### 9. Docs
ADR `docs/decisions/0017-intent-router-and-workspaces.md`; README (Shortcuts, Workspaces, plugins por
proyecto); `config/CLAUDE.md` Routing; `.agents/CONTEXT.md`; copiar este plan a
`docs/superpowers/plans/2026-11-08-intent-router-workspaces.md`; re-correr `export-obsidian.sh`.

## Delegación
- Inline (main): hook, gen-intents, session-start, detect-stack, project-agents, workspace.sh, ADR.
- `worker`: secciones `## Shortcuts` en las 8 skills según la tabla del paso 4. Aceptación: `scripts/gen-intents.sh --check`.
- `scout`: inventario de duplicados (paso 6).

## Verificación
- `bash -n` de scripts nuevos; `shellcheck` si está; `jq . config/*.json`; `scripts/gen-plugin.sh --check`;
  `scripts/gen-intents.sh --check`; `scripts/leak-guard.sh`; tests existentes (`scripts/test-*.sh`).
- Hook a mano: `echo '{"hook_event_name":"UserPromptSubmit","prompt":"traete los cambios","session_id":"t","cwd":"<repo>"}' | bash config/hooks/intent-router.sh`
  → comando con base correcta (repo con gh-flow → dev; repo personal → main); segunda vez → silencio.
  Igual con `PreToolUse` + `tool_name: mcp__claude_ai_Slack__slack_read_channel` y con `agent_type` (silencio).
- SessionStart en 4 sandboxes en el scratchpad: repo sin AGENTS.md, repo next sin skills, workspace con
  2 repos, carpeta suelta → mensaje esperado en cada uno.
- `project-agents.sh --stack next --dry-run` en sandbox → muestra `enabledPlugins` vercel + playwright.
- `workspace.sh` en sandbox (org falsa y personal). Aplicar a `~/work/<org>/<producto>` solo con OK explícito.
- `./install.sh --profile loren --dry-run` → vercel/playwright pasan a false; nada más cambia.
- Sesión nueva real: "traete los cambios" en agents-config → inyecta `git pull origin main`.

## Rollback
Revertir el PR; `install.sh` restaura settings desde base; borrar `${XDG_RUNTIME_DIR}/agents-intents`.
