# Orquestador con reviewer Argon, reglas por harness y recorte de agents-config

Plan L porque toca config global, skills, ADRs, plantillas y README, con decisiones de flujo.

**Objetivo:** el mismo flujo (lanes, workers por capa, reviewer al final) en Claude Code, T3 Code y Orca, y un repo corto, con README y ADRs en español.

**Ejecución:** workers Opus high (solo en esta sesión) en worktrees propios, reviewer Argon por rama, el orquestador integra y commitea. Al aprobar, este archivo se copia a `docs/superpowers/plans/2026-11-18-orquestador-reviewer-recorte.md` y se borra en el último merge (regla nueva).

## Contexto

1. **No hay reviewer.** Nadie revisa el código generado contra el pedido original con un modelo distinto del que lo escribió.
2. **La delegación solo está escrita para Claude Code CLI.** ADR 0029 pide `worker` con `run_in_background`; T3 Code exige `delegate_task` para trabajo en segundo plano y Orca usa sus propios workers.
3. **Un hijo delegado puede frenarse.** `session-start.sh` le inyecta la pregunta de lane a toda sesión nueva, y un hijo de `delegate_task` es una sesión nueva (`lane-guard.sh` solo exime a subagentes nativos).
4. **Unas 72.000 palabras de markdown**, parte vieja: el README habla de «≤3 archivos» y «≤60 líneas», `.agents/CONTEXT.md` dice que todo plan arranca con grilling.

## Decisiones de la entrevista

| Tema | Decisión |
|---|---|
| Reviewer | `gemini-4-argon`, `thought_level: high`, por Antigravity |
| Skill que sigue | `code-review-safety`; en un repo de org, la de la org |
| Cuándo corre | Antes de abrir cada PR, y antes del merge que cierra un Plan L cuando no hay PR |
| Permisos | Lee y corre checks. No edita, no commitea, no pushea |
| Hallazgos | El orquestador arregla lo chico, lo grande va a un worker, una sola re-revisión; si queda algo, lo muestra y frena |
| Sin Argon | Revisa `reasoner` y se informa en una línea |
| Reparto | Un worker por repo o capa, en paralelo, cada uno en su worktree; el orquestador no escribe código en Plan L |
| Workers de esta sesión | Opus high, solo por esta vez; la regla general sigue siendo Sonnet, con Fable de advisor |
| Cambio sin commitear | El de `github-usage/SKILL.md` entra en la rama 1 como commit propio y el archivo se recorta en la rama 2 |
| Recorte | Todo el markdown: config, skills (con `references/` y plantillas), ADRs y READMEs |
| ADRs | Se recortan en su lugar |
| Planes ejecutados | Se borran; regla nueva: el plan se borra al mergear |
| Idioma | READMEs y ADRs en español; config y skills siguen en inglés |
| Skills de Orca | El contenido del 17/11 pasa a `skills/meta/`; se borran las carpetas sueltas |
| Orca | Se escribe sin verificar; Loren lo prueba con una lista |
| Git | Tres ramas con commit, merge local a `master`, sin push |

## Diseño

### Roles

| Rol | Quién | Hace |
|---|---|---|
| Orquestador | sesión principal | Entrevista, plan, briefs, integra diffs, commitea, lanza al reviewer |
| Worker | Sonnet | Implementa un brief en su worktree. No commitea |
| Reviewer | modelo de otro proveedor, nombrado en el perfil | Revisa el diff contra el pedido y corre los checks. No edita |

### Transporte por harness

| Harness | Worker | Reviewer | Aviso al terminar |
|---|---|---|---|
| Claude Code CLI | subagente `worker`, background, worktree | `gemini-delegate.sh run --model <reviewer>` en Bash background | el harness reinvoca al orquestador |
| T3 Code | `delegate_task` (Sonnet, `isolation: worktree`, async) | `delegate_task` (`role: review`, proveedor y modelo del perfil, async); revisa en el worktree de la rama, cuya ruta va en el brief | automático, sin polling |
| Orca | worker de Orca (skill `orchestration`) | worker de Orca con el agente del reviewer | `worker_done` |

### Dónde vive cada cosa

- **Regla genérica** en `config/AGENTS.md` «Workflow lanes» (3 líneas): reparto por repo o capa, reviewer al cierre del Plan L, ciclo de hallazgos, y «un agente lanzado con un brief lo ejecuta: sin pregunta de lane ni subagentes».
- **Transporte de workers** en `config/CLAUDE.md` «Agent Routing» (2 líneas).
- **Nombre del modelo** en `config/profiles/loren.md` (el reviewer y su reemplazo); línea vacía equivalente en `_template.md`.
- **Brief del reviewer, transportes y ciclo** en una skill nueva, `skills/meta/review-handoff/`, que se carga solo al lanzar una revisión. Así no crece lo que se carga en cada sesión.
- **Hijos delegados:** `config/hooks/session-start.sh` agrega una frase a su mensaje para que quien fue lanzado con un brief saltee la pregunta de lane.

### Brief del reviewer (contenido fijo)

Pedido original textual, ruta del plan, ruta absoluta del worktree de la rama, `master..<rama>`, ruta de la skill de review (`~/.agents/skills/quality/code-review-safety/SKILL.md` o la de la org), comandos de checks, permisos, y formato de retorno: hallazgos con severidad y `path:línea`, más la salida real de cada check. En un diff solo de documentación, la consigna es listar toda regla, comando, ruta o dato que estaba antes y ya no está.

«No edita» no lo puede imponer el harness: el orquestador compara `git status --porcelain` y `HEAD` del worktree antes y después de cada revisión.

### Texto exacto de las reglas

`config/AGENTS.md`, «Workflow lanes», después de la viñeta de Plan L:

```markdown
- **Plan L splits the work:** one worker per repo or layer (backend, frontend), in parallel, each in its
  own worktree; the main session writes the briefs, integrates and commits, and writes no code.
- **A reviewer checks the work before every PR is opened**, and before the merge that closes a Plan L when
  there is no PR: a model from another provider (named in the profile) reviews the diff against the
  original request with the repo's review skill and runs the checks, without editing. The main session
  fixes small findings, sends large ones to a worker and asks for one re-review; what is still open after
  it goes to the user. No reviewer available: the profile's fallback reviews, and the user is told in one
  line.
- **An agent started from a brief** (worker, delegated child, reviewer) executes it: no lane question, no
  subagents of its own.
```

`config/AGENTS.md`, «Working Style», punto (c) de los documentos del repo:

```markdown
(c) `docs/superpowers/specs/` and `docs/superpowers/plans/` for the spec and plan being executed: copy an
approved plan-mode plan into `docs/superpowers/plans/YYYY-MM-DD-<slug>.md` before implementing, and delete
both in the merge that finishes the work; what must outlive them goes to an ADR;
```

`config/CLAUDE.md`, «Agent Routing»:

```markdown
- **Review** (the profile's reviewer): before every PR, and before the merge that closes a Plan L. Load
  `review-handoff` for the brief and the findings loop.
- Transport by harness: Claude Code runs `worker` in the background and the reviewer through
  `gemini-delegate`; T3 Code uses `delegate_task` for both (`isolation: "worktree"` for workers); Orca
  uses Orca workers (`orchestration`). A brief always carries what the `worker` definition says.
```

`config/profiles/loren.md`, «Model routing»:

```markdown
- `reviewer` = Gemini 4 Argon (`gemini-4-argon`, thought level high) through Antigravity: reviews the diff
  before every PR and before a Plan L merge. Fallback when it is unavailable: `reasoner`.
```

`config/hooks/session-start.sh`, al final del mensaje de routing:

```text
Before every PR, and before a Plan L merge, the reviewer checks the diff (`review-handoff`). Started from a brief (worker, delegated child, reviewer): skip the lane question and execute the brief.
```

### Enfoques descartados

- **Subagente `config/agents/reviewer.md`:** solo existe en Claude Code; en T3 Code y Orca el reviewer no es un subagente de Claude.
- **Todo en `config/CLAUDE.md`:** ya mide 70 líneas contra el tope de 60 del ADR 0004.

## Plan

```
Paso 0  prueba de Argon ──► Rama 1  orquestador + reviewer ──► merge
                                                                 │
        ┌──────────────┬──────────────┬──────────────┬───────────┤
        ▼              ▼              ▼              ▼           ▼
     W2a config    W2b ADRs      W2c skills A   W2d skills B  W2e project-init
        └──────────────┴──────┬───────┴──────────────┴───────────┘
                              ▼
                 Rama 2  recorte ──► 5 revisiones Argon ──► merge
                              ▼
                 Rama 3  READMEs en español ──► Argon ──► merge ──► cierre
```

| # | Quién | Qué | Paralelo | Archivos | Verificación |
|---|---|---|---|---|---|
| 0 | Orquestador | Prueba: delegar a Argon una tarea de solo lectura | no | ninguno | Argon lee la skill por su ruta, corre `git status` y avisa solo |
| 1 | 1 worker | Reglas, skill `review-handoff`, perfil, hook, ADR 0033 y 0034, mover skills de Orca | no | ver Rama 1 | checks de cierre + revisión de Argon |
| 2a | worker | Recorte de config (1.100 + 700 + 2.300 palabras) | sí | `config/AGENTS.md`, `config/CLAUDE.md`, `config/baseline.md`, `config/intents.plugins.md`, `config/profiles/`, `config/rules/`, `config/agents/`, `AGENTS.md`, `CLAUDE.md` | `gen-intents.sh --check`, `test-cli-baselines.sh`, `test-install-blocks.sh` |
| 2b | worker | ADRs a español y recortados (12.500 palabras); borrar los 11 planes ejecutados (12.300) | sí | `docs/decisions/` salvo su `README.md`, `docs/superpowers/plans/` | `rg 'superpowers/plans/2026'` sin resultados |
| 2c | worker | Recorte de skills A (15.500 palabras) | sí | `skills/{aws,productivity,security,quality}/` salvo `skills/aws/README.md` | `lint-docs.sh --strict` |
| 2d | worker | Recorte de skills B (13.700 palabras) | sí | `skills/{development,integrations,meta}/` | `lint-docs.sh --strict`, `gen-intents.sh --check`, `test-intents.sh` |
| 2e | worker | Recorte de `project-init`, packs y plantilla de org (17.000 palabras), con la regla nueva de planes | sí | `skills/devops/`, `packs/`, `organizations/_template/` | `test-manifest.sh`, `test-docs-check.sh`, `test-packs.sh`, `test-orgs.sh` |
| 3 | 1 worker | READMEs en español, cortos y verificados contra el código | no | `README.md`, `config/README.md`, `skills/README.md`, `skills/aws/README.md`, `organizations/README.md`, `docs/decisions/README.md`, `.agents/CONTEXT.md` | cada afirmación con su fuente; `rg 'README\.md#'` sin enlaces rotos |
| 4 | Orquestador | Cierre | no | borra este plan del repo | checks de cierre; `./install.sh --dry-run` a la vista |

No se toca `evals/`: son los casos de prueba de activación de skills.

### Rama 1: `feat/orquestador-reviewer`

- `config/AGENTS.md`: las tres líneas de «Dónde vive cada cosa» y la regla de documentos: el plan aprobado se copia a `docs/superpowers/plans/` antes de implementar y se borra en el merge que lo termina; lo que deba sobrevivir va a un ADR.
- `config/CLAUDE.md`: rol **Review** y transporte de workers por harness.
- `config/profiles/loren.md` y `_template.md`: reviewer y reemplazo.
- `config/hooks/session-start.sh`: la frase para agentes lanzados con un brief.
- `skills/meta/review-handoff/SKILL.md`: nueva, con el formato que exige `lint-docs.sh` (`Objective`, `When to use`, `Workflow`, `Rules`, `Output`).
- Skills de Orca: el contenido de `skills/{orchestration,orca-cli,orca-computer-use}` pasa a `skills/meta/` y se borran las sueltas. `orca-computer-use` entra en la lista `EXEMPT` de `scripts/lint-docs.sh`. Riesgo aceptado: Orca puede recrearlas al actualizarse.
- `docs/decisions/0033-orquestador-workers-y-reviewer.md` (ajusta 0029) y `0034-planes-se-borran-al-mergear.md`, más el índice.
- `.agents/CONTEXT.md`: corregir la línea de grilling y sumar el reviewer.
- Regenerar con `scripts/gen-plugin.sh`.
- Apenas mergea a `master`, el orquestador corre `./sync.sh`: los enlaces del mirror a las carpetas sueltas de Orca quedan colgados hasta entonces.
- El brief de este worker lleva la excepción de lane escrita, porque todavía carga la config vieja. La prueba real de que un hijo no pregunta la lane son los workers de la rama 2.

### Rama 2: `refactor/recorte-markdown`

Reglas para los cinco workers:

- **No se toca:** frontmatter (`name`, `description`, `paths`), secciones `## Shortcuts`, bloques y archivos generados (`config/intents.json`, `.claude-plugin/`, `hooks/hooks.json`, tabla Shortcuts de `config/AGENTS.md`), comandos, rutas, flags, valores y regex, scripts.
- **Se corta:** historia y fechas, justificación de más de una frase, reglas repetidas (queda una, en el lugar más específico), ejemplos de más, relleno.
- **Plantillas:** antes de cortar una línea, `rg` en los scripts y tests por si la buscan.
- **Excluido:** los READMEs, que van en la rama 3. `github-usage/SKILL.md` entra en el recorte de W2d, que además le suma el paso «revisión antes de abrir el PR».
- **Informe de cada worker:** palabras antes y después por archivo, y toda regla que haya dudado en cortar.
- Objetivo orientativo: 40 % menos palabras, nunca a costa de una regla. `config/CLAUDE.md` vuelve a 60 líneas o menos.

La revisión de Argon va por worker (cinco en paralelo): un solo diff de este tamaño no se puede revisar bien.

### Rama 3: `docs/readme-es`

- `README.md` en español, 120 líneas o menos: qué es, instalación, cómo se trabaja (lanes, orquestador, reviewer, con un diagrama), estructura, comandos y enlaces al detalle. Lo que ya está en otro archivo se enlaza, no se repite.
- El worker verifica cada afirmación contra su fuente (`install.sh`, `sync.sh`, `config/scopes.json`, `config/hooks/`, `config/agents/`).
- Se actualizan las referencias a la sección de instalación en `AGENTS.md` y en la skill `agents-config-setup`.

### Git

- **El checkout principal es la instalación viva** (`~/.claude` y `~/.agents/skills` apuntan ahí, y hay otras sesiones abiertas): nunca cambia de rama. Cada rama se integra en un worktree hermano (`../agents-config-<rama>`) y llega a `master` con un `git merge --no-ff`, recién después de los checks y de la revisión.
- Cada worker trabaja en su worktree y no commitea. El orquestador revisa el diff, corre los checks, commitea ahí y lo mergea al worktree de la rama.
- La limpieza automática de worktrees (ADR 0030) no los borra: exige un PR mergeado. Los quito a mano al cerrar cada rama.
- Commits en Conventional Commits en español, sin líneas de atribución. Sin push.
- Tu cambio sin commitear en `github-usage/SKILL.md` pasa a la rama 1 con `git stash` y queda como commit propio.

## Verificación

Checks de cierre, en cada rama antes del merge:

```bash
bash scripts/lint-docs.sh --strict
scripts/gen-plugin.sh --check && scripts/gen-intents.sh --check
scripts/leak-guard.sh --all
for t in lane-guard intents packs orgs cli-baselines install-blocks leak-guard worktree-cleanup stack-sync; do bash scripts/test-$t.sh; done
bash skills/devops/project-init/scripts/test-manifest.sh
bash skills/devops/project-init/scripts/test-docs-check.sh
```

- **En vivo, T3 Code:** el paso 0 y la revisión de la rama 1 prueban que Argon lee la skill, corre checks y avisa solo. Los workers de la rama 2 prueban que un hijo delegado no pregunta la lane.
- **`install.sh`:** `~/.codex/AGENTS.md` se genera por copia y queda viejo hasta reinstalar. Al cierre muestro `./install.sh --dry-run`; correrlo de verdad queda a tu decisión, porque también mergea `~/.claude/settings.json`.
- **Claude Code CLI:** `agy models` para el id de Argon y una corrida de `gemini-delegate.sh run` con un brief de solo lectura.
- **Medición:** palabras por área antes y después.

No se verifica en este plan:

- **Orca.** Lista para correr en una sesión de Orca: (1) un Plan L chico lanza un worker de Orca por repo; (2) el reviewer corre como worker de Orca y llega su `worker_done`; (3) tras `./sync.sh` las tres skills cargan desde `skills/meta/`, y si Orca recrea las carpetas sueltas al actualizarse.
- **Evals de activación de skills** (`scripts/eval-skills.sh`): son sesiones pagas. Las `description` no cambian.
- **`e2e.sh` de `project-init`:** necesita red y crea repos.

## Notas

- Este hilo corre en Fable; tu perfil pide Opus para la sesión principal. Si lo querés así, cambiá el modelo antes de aprobar.
- Los dos exploradores de solo lectura se cortaron con el reinicio de T3. No los relanzo: las restricciones las relevé a mano y la auditoría del README la hace el worker de la rama 3.
