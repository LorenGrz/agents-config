# 0026 — Carpeta de skills, una skill por herramienta y una plantilla fija por tipo de markdown

Estado: aceptado (2026-11-13). Se apoya en ADR 0001 (repo único), 0011 (alcance global o por proyecto), 0012
(organizaciones) y 0017 (router de intenciones).

## Contexto

El hub había crecido plano (categorías, skills de integración, symlinks externos y `packs/` en la raíz), git y
GitHub estaban partidos en `git-workflow` y `github-usage`, y cada markdown tenía otra forma. Los repos de org
dependían del hub: sin `agents-config` no había skills de la org para GitHub, Jira, Slack o Google.

## Decisión

- **Carpeta `skills/`.** Toda skill vive en `skills/<category>/<skill>/`. Categorías: `aws`, `development`,
  `devops`, `meta`, `productivity`, `quality`, `security`, más `integrations/` para las skills dueñas de una
  herramienta externa (`github-usage`, `jira-usage`, `slack-usage`, `google-workspace-usage`,
  `obsidian-vault`, `notebooklm-obsidian-sync`, `codex-review`). `skills/external/` guarda los symlinks
  propios de la máquina (omarchy, omarchy-app, diagnose-crash, superwhisper) y sigue ignorada. `packs/` queda
  en la raíz.
- **`~/.agents/skills` apunta a `<hub>/skills`** (antes, a la raíz del hub). `sync.sh` busca en `skills/` y
  espeja `skills/external/*` explícitamente, porque `find` no entra en symlinks.
- **Una skill por herramienta.** `git-workflow` se fusiona en `github-usage` y deja de existir: git y GitHub
  son una sola skill, en `integrations/`. Es el único renombre de skill de la reorganización. Los ADRs y
  planes que nombran `git-workflow` son historia y no se reescriben.
- **Una plantilla fija por tipo de markdown**, para que cualquier modelo lea cada tipo igual. No se borra
  contenido para encajar en una plantilla ni se parten las skills largas.

| Tipo | Forma |
|---|---|
| SKILL.md | Frontmatter `name` (igual a la carpeta) y `description` ("Use when ..."). Secciones, en este orden y solo estas: `Objective`, `When to use`, `Prerequisites`, `Workflow`, `Rules`, `Reference`, `Output`, `Verification`, `Claude Code`, `Shortcuts`. `Workflow` o `Rules` es obligatoria; `Shortcuts` va última y mantiene el formato de `gen-intents`. `Claude Code` es el único lugar para ToolSearch, subagentes y hooks |
| Reference | `# Title`, una línea "Read when: ...", sin repetir el SKILL.md |
| Command | Frontmatter `description` y `argument-hint`; secciones `Source`, `Rules`, `Steps`, `Output`, `Stop when` |
| Rule (`config/rules`) | Frontmatter `paths:` y `## Topic` con viñetas en imperativo |
| Agent | `Before`, `Do`, `Never`, `Return` |
| Profile | `Identity`, `GitHub`, `Stack`, `Model routing`, `Local tool paths`, `Skill routing`, `OS` |
| POLICIES (org) | Un resumen corto, una sección núcleo, una sección de proyecto y una por producto; sin identidad personal; fechas como "in force since" |
| README de carpeta / AGENTS.md | `Purpose`, `Layout`, `How to add`, `Checks`; AGENTS.md suma `Rules` y `Pointers` |

- Las formas existentes se mapean: `Operating Rules` pasa a `Rules`; `Role`, `Responsibilities` y `Guardrails`
  pasan a `Objective` más `Rules` con temas `###`; las skills de forma libre suman un `Objective` y sus `##`
  bajan a `###`. `orca-cli`, `orchestration` y `frontend-design` quedan exentas (solo frontmatter).
- **`scripts/lint-docs.sh`** revisa la plantilla de SKILL.md (frontmatter, `name` igual a la carpeta,
  encabezados permitidos y su orden, `Workflow` o `Rules`, `Shortcuts` última), `config/rules/*.md` (`paths:`)
  y `packs/*/commands/*.md` (`description`). Arranca en CI como aviso (exit 0) y pasa a error (`--strict`)
  cuando las skills existentes estén migradas.
- **Los repos de org son autosuficientes.** Un repo de org trae su propio `.claude-plugin/`, `hooks/` (un hook
  SessionStart que muestra el resumen de su POLICIES), `install.sh`, `AGENTS.md` y `README.md`, así se instala
  como plugin de Claude Code o con su script, sin el hub. Sus skills cubren las mismas herramientas que las
  skills de integración del hub, con las reglas de la org. `replaces` de `org.json` mapea cada skill de
  integración del hub a la de la org (por ejemplo `github-usage` a la skill de GitHub de la org), así en sus
  repos aplica una sola. El contrato está en `organizations/README.md`, y `org.json` suma los defaults
  separados `pr_title_language` y `pr_body_language`.

## Consecuencias

- Todo lo que leía `<hub>/<category>/<skill>` ahora lee `<hub>/skills/<category>/<skill>` (`sync.sh`,
  `gen-plugin.sh`, `gen-intents.sh`, `export-obsidian.sh`, `project-agents.sh`, rulesync, los scripts de
  project-init, el CI y los tests). Un script con un `../` relativo al hub baja un nivel más.
- Lo que nombraba `git-workflow` (hooks, `intents.json`, `config/AGENTS.md`, packs, project-init, READMEs)
  ahora nombra `github-usage`.
- Los repos de org que no dependen del hub pierden la garantía de que estén sus hooks y rules, así que su
  `install.sh` se niega a instalar en un proyecto ya manejado por `agents-config`.
- Una instalación anterior a este ADR corre `install.sh` una vez, para que `~/.agents/skills` apunte a
  `<hub>/skills`.
- El `replaces` de una org para las skills de integración del hub solo quita las copias instaladas en un
  proyecto. Para las skills globales, `config/hooks/intent-router.sh` traduce la skill sugerida con ese
  `replaces`.
