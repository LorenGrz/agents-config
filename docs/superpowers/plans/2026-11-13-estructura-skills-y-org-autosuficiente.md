> Versión pública: los nombres de la organización se reemplazaron por `<org>`; la copia completa vive en el repo privado de la org.

# Plan L — Reestructura de agents-config y del repo de org autosuficiente

## Contexto

Loren quiere que los dos repos de configuración de agentes estén ordenados para que cualquier modelo los lea igual: carpetas claras y `.md` con una plantilla fija por tipo. Además, la org tiene que ser **autosuficiente**: alguien del equipo puede no usar `agents-config`, así que `<org>-agents-config` trae sus propias skills de uso (gh, Jira, Slack, Google, MCPs) y se instala solo. La regla de uso es **una skill por herramienta**: git/GitHub → `github-usage` (en la org, `<org>-github`), Jira → `jira-usage` (`<org>-jira`), Slack, Google, etc.

Hay que mover carpetas sin romper lo que depende de rutas fijas: `sync.sh`, `gen-intents`, `gen-plugin`, `export-obsidian`, `project-agents`, `rulesync`, `project-init`, `roadmap-coach`, el CI, los tests y el espejo de `~/.claude/skills`.

El diseño lo hizo Fable 5.2 (Plan) y lo revisó Opus. La entrevista de grilling ya se hizo y fijó las decisiones.

## Decisiones fijadas

**Hub (`agents-config`, en inglés)**
- Todas las skills van bajo `skills/<categoría>/<skill>/`. Las categorías son las 7 actuales más `integrations/`: `github-usage`, `jira-usage`, `slack-usage`, `google-workspace-usage`, `obsidian-vault`, `notebooklm-obsidian-sync`, `codex-review`.
- Los symlinks externos van a `skills/external/`, que sigue ignorado por git. `packs/` queda en la raíz.
- `~/.agents/skills` pasa a apuntar a `<hub>/skills`.
- **`git-workflow` se fusiona dentro de `github-usage`** y deja de existir: una sola skill para git y GitHub. Es la única excepción a «los nombres no cambian».
- Hay una plantilla fija por tipo de `.md`. El historial no se toca (ADRs y planes), salvo índices y links. Las skills largas no se parten.

**la org (`<org>-agents-config`, en español)**
- Se instala como plugin de Claude Code y también con un `install.sh` propio. El `install.sh` instala por defecto en `~/.claude` y, con `--project <ruta>`, en el `.claude/` de un repo. Tiene `AGENTS.md` y `README.md` propios.
- Skills de uso completas y sin depender del hub:
  - `<org>-github`: el espejo de `github-usage` con las reglas de la org, incluido el flujo git. Trae sus propios scripts de capturas.
  - `<org>-jira`: la actual, ampliada.
  - `<org>-slack`, `<org>-google`, `<org>-mcps`: nuevas.
- Los comandos de la org quedan completos. Los del hub no cambian.
- **Tu identidad se borra** de `POLICIES.md`: Jira usa `currentUser()` y GitHub `gh api user`.
- **Se abre a otros modelos**: sale «solo agentes Claude» de `POLICIES.md` y `agent_providers` de `org.json`. Ojo: con eso, caolg deja de limitar a `claude-dev` en la org.
- Hay un **hook SessionStart en el plugin** que muestra el Resumen de `POLICIES.md` en repos de `<org-owner>`.
- El repo sigue en `LorenGrz`, privado, pero queda listo para moverlo a la org sin cambios.

**Ejecución**
- Ramas `refactor/estructura` en cada repo, cortadas de `chore/pendientes-pre-reorg`. Sin push.
- Workers Sonnet (subagentes `worker`) con rutas disjuntas. Ellos no commitean: el líder revisa el diff, corre la verificación y hace el commit de cada tanda.

## Árbol destino

```
agents-config/
  AGENTS.md CLAUDE.md README.md install.sh sync.sh .claude-plugin/ hooks/
  config/ docs/ evals/ scripts/ packs/ organizations/     (sin cambios de lugar)
  skills/
    README.md  aws/ development/ devops/ meta/ quality/ security/
    productivity/   (oficina: ats, cv, image-annotations, meeting-notes, presentation, email)
    integrations/   (github-usage [+ git-workflow fusionado], jira, slack, google, obsidian, notebooklm, codex-review)
    external/       (symlinks ignorados: omarchy, omarchy-app, diagnose-crash, superwhisper)

<org>-agents-config/
  .claude-plugin/{plugin.json,marketplace.json}  hooks/ (SessionStart)
  AGENTS.md README.md POLICIES.md org.json interview.md install.sh
  commands/*.md
  skills/<nombre>/SKILL.md   (14 actuales + <org>-github [con scripts/], <org>-slack, <org>-google, <org>-mcps)
```

## Plantillas

| Tipo | Forma |
|---|---|
| **SKILL.md** | Frontmatter `name` (igual a la carpeta) y `description` («Use when…»); los opcionales se mantienen. Secciones: `Objective`, `When to use`?, `Prerequisites`?, `Workflow`, `Rules` (temas como `###`), `Reference`?, `Output`, `Verification`?, `Claude Code`? (único lugar para ToolSearch, subagentes y hooks), `Shortcuts`? (siempre al final, formato de `gen-intents` intacto). Hace falta `Workflow` o `Rules`. En la org, los títulos van en español. |
| **Reference** | `# Título`, la línea «Read when: …», y no repite el SKILL.md. |
| **Comando** | Frontmatter `description` y `argument-hint`. Secciones `Source`, `Rules`, `Steps`, `Output`, `Stop when` (Fuente, Reglas, Pasos, Salida, Cuándo parar). |
| **Regla** (`config/rules`) | `paths:` y `## Tema` con bullets en imperativo. |
| **Agente** | Secciones `Before`, `Do`, `Never`, `Return`. |
| **Perfil** | `Identity`, `GitHub`, `Stack`, `Model routing`, `Local tool paths`, `Skill routing`, `OS`. |
| **POLICIES** | `Resumen` (10 líneas o menos), `Núcleo`, `Proyecto`, y una sección por producto. Sin identidad personal; las fechas como «vigente desde». |
| **README / AGENTS.md de carpeta** | `Purpose`, `Layout`, `How to add`, `Checks`. AGENTS.md suma `Rules` y `Pointers`. |

Cómo se mapean los esquemas actuales:
- `Operating Rules` pasa a llamarse `Rules`.
- `Role`/`Responsibilities`/`Guardrails` pasan a `Objective` + `Rules ###`.
- Las skills de forma libre ganan un `Objective` y sus títulos `##` bajan a `###`.
- Sin borrar contenido.
- Exentas (solo se revisa el frontmatter): `orca-cli`, `orchestration`, `frontend-design`.

`scripts/lint-docs.sh` controla frontmatter, `name` igual a la carpeta, títulos permitidos, orden y `Shortcuts` al final. Entra a CI primero como aviso y después como error.

## Tandas

### Tanda 1 — Hub: mover y arreglar todas las referencias (1 worker, 1 commit)

**Movimientos**
- `git mv` de las 7 categorías a `skills/`.
- Las 7 skills de integración a `skills/integrations/`.
- Los symlinks externos a `skills/external/`.
- `.gitignore`: `/skills/external/`, y sacar `apexlang`, que está muerto.

**Scripts**
- `sync.sh`: busca en `skills/` y espeja explícitamente `skills/external/*`.
- `gen-plugin.sh`, `gen-intents.sh`, `export-obsidian.sh`, `config/rulesync/build.sh`: la raíz pasa a ser `$HUB/skills`.
- `project-agents.sh` (`find_skill`): busca en `skills/`.
- `eval-skills.sh`: revisarlo.
- Las rutas con `../` suben un nivel: `project-init/init.sh` (líneas 111, 135, 583), `workspace.sh:24` y `roadmap-coach/update-stage.sh:14`.

**Rutas literales**
- `guard.yml` y los tests `test-intents.sh:102` y `test-orgs.sh`.
- `AGENTS.md`, `CLAUDE.md`, `config/AGENTS.md`, `config/README.md`, `.agents/CONTEXT.md`.
- Las skills `gemini-delegate`, `agents-config-setup`, `codex-workflows`, `roadmap-coach` y `project-init`.
- `config/profiles/loren.md`, `.claude-plugin/marketplace.json`.
- Sacar la mención de la org en `github-usage/SKILL.md`, que hoy filtra el nombre en un repo público.

**Otros**
- `install.sh`: `link "$HUB/skills" ~/.agents/skills`.
- `scopes.json`: el stack `apex` queda con `skills: []`.
- Regenerar el plugin y la tabla de intents.

**Verificación**
- `gen-plugin.sh --check` y `gen-intents.sh --check`.
- `scripts/test-{leak-guard,packs,orgs,intents,cli-baselines,lane-guard}.sh`.
- Los tests de `project-init`.
- `./install.sh --dry-run`.
- `sync.sh` contra un espejo de prueba: 32 skills del hub más 4 externas.
- Un `git grep` que confirme que no quedan rutas viejas.

Después el líder corre el `./install.sh` real. Eso también registra `lane-guard` en `settings.json`. Y chequea:
- que no haya symlinks colgados en `~/.claude/skills`;
- que `c4-architecture/` y `synced/` sigan intactos;
- que `readlink ~/.agents/skills` dé `<hub>/skills`;
- que `~/.codex/AGENTS.md` se haya regenerado.

### Tanda 2 — Hub: fusionar git-workflow en github-usage (1 worker)

- `github-usage` absorbe el flujo de `git-workflow`: gate de `.gitignore`, rama, verificación, commit, push, merge, actualizar AGENTS.md y reglas de org. Las secciones de Shortcuts se unen en una sola.
- `git rm` de `skills/devops/git-workflow`.
- Cambiar «git-workflow» por «github-usage» en `config/AGENTS.md` («Load the `git-workflow` skill…»), `config/CLAUDE.md`, `intents.json` (lo regenera `gen-intents`), hooks, `packs/`, `project-init` y READMEs. Los ADRs no se tocan.
- Verificación: tanda 1 completa, más un `rg -n "git-workflow"` que solo encuentre historial (ADRs y planes).

### Tanda 3 — Hub: índices, lint y ADR (1 worker, sin tocar SKILL.md)

- `README.md` (layout y la tabla completa de categorías), `skills/README.md` nuevo y `skills/aws/README.md` (las de aws son por proyecto).
- `organizations/README.md` y `_template/org.json`: el contrato real (`scripts/`, `agent_providers`, `workspaces/`, plugin, `install.sh`, `pr_title_language` y `pr_body_language`).
- ADR `0026-skills-folder-and-templates.md` con su línea en el índice.
- `scripts/lint-docs.sh` en modo aviso, conectado al CI.

### Tanda 4 — Hub: plantillas (4 workers en paralelo, rutas disjuntas)

| Worker | Rutas |
|---|---|
| 4a | `skills/{development,quality,security}` |
| 4b | `skills/{devops,meta}` |
| 4c | `skills/{integrations,productivity,aws}` |
| 4d | `config/{rules,agents,profiles}`, `config/README.md`, frontmatter de los comandos de los packs |

- Solo títulos y orden, imperativo donde sea trivial, sin borrar contenido. Los bloques `Shortcuts` quedan idénticos byte a byte.
- 4c agrega en cada skill de integración: «En un repo de una org, usá la skill de reemplazo de la org si está instalada».
- Verificación: `lint-docs.sh --strict` en verde (y en CI pasa a error), `gen-intents --check`, `test-intents`, `gen-plugin --check`, `test-packs`.

### Tanda 5 — la org: portabilidad, plugin e instalador (1 worker)

**Scripts de capturas**
- `git mv` de `scripts/cx-pr-shots.sh` y `scripts/cx-login-steps.mjs` a `skills/<org>-github/scripts/`.
- Copiar del hub `pr-screenshots.mjs`, `gh-upload-images.mjs` y `package.json`, sin `node_modules`.
- `setup.sh` instala las dependencias en `~/.cache/<org>-agents/pr-shots/`. Así no queda `node_modules` en el repo, porque `project-agents.sh` rechaza symlinks.
- `cx-pr-shots.sh` pasa a rutas relativas y usa `CX_ROOT` en lugar de `/home/loren/...`.

**POLICIES.md**
- Sale `## Identidad`.
- Entra `## Resumen`.
- «Pedido de Loren» pasa a «vigente desde».
- Sale «solo agentes Claude».
- Las capturas apuntan a `<org>-github`.

**Otros cambios**
- `run-<product>-client/<product>-open.mjs:31`: el nombre y el mail reales de una compañera se cambian por datos ficticios.
- Las rutas `.claude/skills/<x>/…` de los comandos `<product>-ui-*` y de `run-<product>-client` pasan a nombrar la skill (y `${CLAUDE_SKILL_DIR}` dentro de `## Claude Code`).

**Archivos nuevos**
- `.claude-plugin/plugin.json` y `marketplace.json` (`name: <org>`, `source: "./"`).
- El hook SessionStart que muestra el Resumen de POLICIES cuando el remoto es de `<org-owner>`.
- `README.md`, con las dos formas de instalar.
- `AGENTS.md`, con las tablas de skills y comandos y cómo carga una skill un agente que no es Claude.

**`install.sh`** (bash, sin depender del hub)
- Instala en `~/.claude` por defecto, o en `--project <ruta>`.
- Copia skills, comandos y POLICIES. Agrega un bloque `<!-- <org>:start/end -->` en `CLAUDE.md` (modo usuario) o en `AGENTS.md` (modo proyecto).
- Guarda un manifiesto con sha256:
  - lo que el usuario editó se respalda en `.bak-<fecha>` antes de pisarlo;
  - un archivo ajeno con el mismo nombre se saltea, salvo con `--force`;
  - lo que se borró del repo se desinstala.
- Tiene `--dry-run` y `--uninstall`.
- Se niega a instalar en un proyecto que ya maneja `agents-config` (`.agents/skills.lock` con org).

**Verificación**
- `bash -n install.sh` y `--dry-run`.
- `--project <scratch>` dos veces: la segunda tiene que dar 0 cambios.
- `grep` de `/home/`, del email, de `LorenGrz` y del accountId: solo puede aparecer en la nota de owner del README.
- Que no haya symlinks.
- `claude plugin validate .`, si está disponible.
- Desde el hub: `orgs.sh validate <org>` y `project-agents.sh --org <org>` contra una carpeta de prueba, comparado con una corrida previa.

### Tanda 6 — la org: skills y comandos (3 workers en paralelo), después el pegamento del hub

| Worker | Rutas |
|---|---|
| 6a | `<org>-github`, `<org>-slack`, `<org>-google`, `<org>-mcps`, `<org>-jira` ampliada, `org.json` |
| 6b | Plantilla (solo títulos) en `<product>-*`, `testing`, `jira-test`, `run-<product>-client` y `<org>-<product>-design-system` |
| 6c | `commands/*.md`: plantilla; nombran a `<org>-github` y `<org>-jira`; sin rutas del hub |

**Las skills de 6a**
- `<org>-github` = la nueva `github-usage` (git y GitHub) más las reglas de la org:
  - rama desde `origin/dev` con chequeo de `merge-base`;
  - push y PR solo con OK;
  - título Conventional Commits en español y secciones del cuerpo en el orden de POLICIES;
  - el link `Jira: [KEY](…)`;
  - sin emojis ni atribución;
  - capturas solo cuando cambia algo visible (`setup.sh` y `cx-pr-shots.sh`);
  - nota: «PR mergeada → Done» lo hace una regla de Jira Automation, no el agente.
- `<org>-jira` suma de `jira-usage` el cloudId, las recetas JQL, las reglas de escritura y Confluence. Usa `atlassianUserInfo` y `currentUser()`.
- `<org>-slack`: leer libre, mostrar el borrador antes de mandar y leer el topic del canal antes de postear.
- `<org>-google`: Gmail en borrador por defecto, Calendar y Drive en lectura; todo lo que escribe va con OK.
- `<org>-mcps`: tabla de conectores (Atlassian, GitHub, Slack, Google, Mi la org, SAP la org, WMS la org) con para qué sirve cada uno, qué se lee libre y qué necesita OK, cómo conectarlo y cómo verificarlo. SAP y WMS son de solo lectura salvo pedido; las variantes «Confidencial» solo con pedido explícito.

**`org.json`**
- `replaces` suma `github-usage → <org>-github`, `jira-usage → <org>-jira`, `slack-usage → <org>-slack` y `google-workspace-usage → <org>-google`.
- Sale `agent_providers`.
- `<org>-jira` deja de filtrarse por stack.
- `pr_title_language: "es"`.
- Se sube `version`.

**Pegamento del hub (6d, después de 6a)**
- `config/hooks/intent-router.sh`: cuando el repo es de una org, traduce la skill sugerida con el `replaces` de esa org. Así en la org «saltan» `<org>-github` y `<org>-jira`, y en tus repos `github-usage` y `jira-usage`.
- Dos casos nuevos en `test-intents.sh` con la org falsa.
- Verificación: `orgs.sh validate <org>`, `test-intents`, `test-orgs`, y `project-agents.sh --org <org>` corrido de nuevo en el workspace de CX (el diff solo debe mostrar las skills nuevas).

## Riesgos y cómo se controlan

| Riesgo | Control |
|---|---|
| Symlinks colgados en `~/.claude/skills` | Espejo de prueba en la tanda 1 y `find -xtype l` después del install real. |
| Skills de packs tomadas como skills del hub | `gen-plugin --check`: exactamente 32 entradas `./skills/…`. |
| Tabla de intents desfasada | `gen-intents --check` y `test-intents` en cada tanda que toca skills. |
| Codex o rulesync desactualizados | `install.sh --dry-run`, diff de `~/.codex/AGENTS.md` y `rulesync/build.sh`. |
| Nombre de la org filtrado en el hub público | `test-leak-guard` y `leak-guard.sh --all` en cada tanda del hub. |
| Referencias rotas por el namespacing del plugin | Las skills y comandos se nombran entre sí en prosa, nunca por ruta. |
| Pierden la restricción a Claude en caolg | Queda anotado: con `agent_providers` fuera, el líder puede abrir otros workers en la org. |

## Al cerrar

- Copiar este plan a `agents-config/docs/superpowers/plans/2026-11-13-estructura-skills-y-<org>.md`.
- Actualizar `.agents/CONTEXT.md` de los dos repos.
- Guardar en memoria: el grilling va por el cuestionario (`AskUserQuestion`).
- Commits por tanda en `refactor/estructura`. Sin push ni merge hasta que lo pidas.
