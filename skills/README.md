# skills

## Purpose

La biblioteca de skills: una carpeta por skill, cada una con un `SKILL.md` que el agente carga cuando su
`description` coincide con la tarea. Acá se agrupan por categoría y `sync.sh` las espeja planas en
`~/.claude/skills` (Claude Code solo lee hijos directos). `install.sh` también enlaza `~/.agents/skills` a
esta carpeta, así otros agentes comparten la misma raíz.

Todas siguen una plantilla, así cualquier modelo las lee igual. La decisión está en
`docs/decisions/0026-skills-folder-and-templates.md`.

## Layout

Un `*` marca una skill de proyecto: figura en un stack de `config/scopes.json`, `sync.sh` no la pone en el
espejo global y `scripts/project-agents.sh` la instala por proyecto (ADR 0011). Las demás son globales.

| Categoría | Qué va ahí | Skills |
|---|---|---|
| `aws/` | Trabajo serverless en AWS (stack `aws`), ver `aws/README.md` | `sam-deploy`*, `lambda-patterns`*, `iam-least-privilege`*, `cost-optimizer`*, `serverless-scanner`* |
| `development/` | Construir funcionalidades y calidad de código | `api-contract-design`*, `code-documenter`, `database-persistence-patterns`*, `debug-assistant`, `frontend-design`, `nest-module-generator`*, `nextjs-ssr-frontend`*, `react-native-mobile`*, `regex-builder-explainer`, `typescript-code-quality`, `typescript-project-starter` |
| `devops/` | Ciclo de vida del repo y releases, contenedores | `conventional-commit-generator`, `project-init`, `repository-context-maintainer`, `run-docker-environment`* |
| `integrations/` | Una skill por herramienta externa, con su `## Shortcuts` | `github-usage` (git y GitHub), `jira-usage`, `jira-ticket-review`, `slack-usage`, `google-workspace-usage`, `obsidian-vault`, `notebooklm-obsidian-sync`, `codex-review` |
| `meta/` | Cómo trabajan los agentes: setup, flujo, delegación, revisión, organizaciones | `agents-config-setup`, `codex-workflows`, `english-prompt-coach`, `gemini-delegate`, `orca-cli`, `orca-computer-use`, `orchestration`, `org-creator`, `review-handoff`, `roadmap-coach`, `team-roles` |
| `productivity/` | Entregables que no son código (stack `office` salvo `image-annotations`) | `ats-resume-formatting`*, `cv-linkedin-optimizer`*, `image-annotations`, `meeting-notes-organizer`*, `presentation-prep`*, `professional-email-drafter`* |
| `quality/` | Revisión y tests | `code-review-safety`, `execute-test-suite`, `react-component-validator`*, `unit-test-generator` |
| `security/` | Auth y defensa contra prompt injection | `auth-security-basics`*, `prompt-injection-defense`* |
| `external/` | Symlinks a skills de otras herramientas. Ignorado por git, se recrea en cada máquina | `omarchy`, `omarchy-app`, `diagnose-crash` (vienen con Omarchy), `superwhisper` (viene con SuperWhisper) |

El propósito de cada una está en la `description` de su frontmatter: `rg '^description' skills/*/*/SKILL.md`.
Las skills que vienen con una arquitectura viven en `packs/<name>/skills/`, no acá.

### Shortcuts: frases e integraciones a skills

Las skills de `integrations/` terminan con una sección `## Shortcuts`: patrones `tools:` y `bash:` que
identifican sus llamadas, y líneas `intent:` (etiqueta, regex de la frase en español e inglés, comando). Las
skills de plugins no se pueden editar, así que sus atajos van en `config/intents.plugins.md`.
`scripts/gen-intents.sh` convierte todo en `config/intents.json` (lo lee el hook `intent-router.sh`) y en
una tabla corta en `config/AGENTS.md` (la leen Codex, Cursor y el resto); `sync.sh` y CI lo mantienen al día
(`--check`). `<base>` en un comando es la rama base del repo: con `scripts/gh-flow.sh`, `dev`; si no, una
regla «Base branch is `x`» del `AGENTS.md`, el `base_branch` de la organización, `origin/HEAD` y por último
`main` (ADR 0017).

### Evals de activación

`evals/` tiene evals para `claude plugin eval`: cada caso manda un pedido realista (sin nombrar la skill) y
revisa que se active la skill correcta, o ninguna en los casos `no-trigger-*`.

```bash
./scripts/eval-skills.sh                        # todos los casos
./scripts/eval-skills.sh --case 'trigger-*'     # solo los positivos
EVAL_RUNS=3 ./scripts/eval-skills.sh            # antes de confiar en un cambio de description
```

Cada caso es una sesión paga (`EVAL_MAX_COST`, 2 USD por defecto, pone el tope), por eso no corre en CI.
Pide Claude Code >= 2.1.269 (>= 2.1.299 para que un error de la API puntúe 0). Los resultados van a
`evals/results/` (ignorado).

## How to add a skill

1. Crear `skills/<category>/<skill>/SKILL.md`. El nombre de la carpeta es el nombre de la skill. La categoría
   sale de la tabla de arriba; una herramienta con API o CLI propia va en `integrations/`, una skill por
   herramienta.
2. Escribirla con esta plantilla (una skill no repite lo que es de otra: la nombra):
   - Frontmatter: `name` (igual a la carpeta) y `description` ("Use when ..."); las claves opcionales quedan
     como están.
   - Secciones `##`, solo de esta lista y en este orden: `Objective`, `When to use`, `Prerequisites`,
     `Workflow`, `Rules` (temas como `###`), `Reference`, `Output`, `Verification`, `Claude Code`
     (el único lugar para ToolSearch, subagentes y hooks), `Shortcuts` (siempre la última).
   - Al menos una de `Workflow` o `Rules`.
   - El detalle largo va en `references/<topic>.md` al lado del SKILL.md, empieza con `# Title` y una línea
     `Read when: ...`, y no repite el SKILL.md.
3. Correr lo que el cambio toca:
   - `./sync.sh` para refrescar el espejo `~/.claude/skills`.
   - `scripts/gen-plugin.sh` si la skill es global (lista las skills del plugin; `--check` verifica).
   - `scripts/gen-intents.sh` si la skill tiene `## Shortcuts` (regenera `config/intents.json` y la tabla de
     `config/AGENTS.md`; `--check` verifica).
   - Si es de un stack, sumarla a ese stack en `config/scopes.json`.
4. Revisarla con `bash scripts/lint-docs.sh --files skills/<category>/<skill>/SKILL.md`.

`orca-cli`, `orca-computer-use`, `orchestration` y `frontend-design` son de forma libre y quedan fuera de la
plantilla de secciones: solo se revisa su frontmatter.

## Checks

```bash
bash scripts/lint-docs.sh             # modo aviso: imprime las violaciones, sale 0
bash scripts/lint-docs.sh --strict    # sale 1 ante cualquier violación
bash scripts/lint-docs.sh --files skills/meta/roadmap-coach/SKILL.md
scripts/gen-plugin.sh --check         # la lista de skills del plugin coincide con las globales
scripts/gen-intents.sh --check        # la tabla de Shortcuts está al día
bash scripts/test-intents.sh
```
