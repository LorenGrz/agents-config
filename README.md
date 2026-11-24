# agents-config

Un solo repo que configura igual a todos los agentes de código (Claude Code, Codex CLI, Cursor y Google Antigravity),
más una biblioteca de skills compartida que cada agente carga solo cuando la tarea la pide. Lo personal (nombre, idioma,
rutas, etapa de aprendizaje, owner de GitHub) va únicamente en `config/profiles/<name>.md`; el resto se comparte tal cual.

## Instalación

Elegí **un** método por máquina: se pisan entre sí y no se combinan.

```bash
# 1. install.sh: instrucciones, reglas, hooks, subagentes, skills y settings.json
git clone https://github.com/LorenGrz/agents-config ~/projects/agents-config
~/projects/agents-config/install.sh --dry-run          # muestra el plan, no cambia nada
~/projects/agents-config/install.sh --profile <tu-nombre>
```

`install.sh` genera `~/.claude/CLAUDE.md` y `~/.codex/AGENTS.md`, enlaza reglas, hooks, subagentes y `~/.agents/skills`, corre
`sync.sh` y mergea `config/settings.base.json` en `~/.claude/settings.json`. Nunca borra un archivo real: lo mueve a
`.bak.<timestamp>`. Opcionales: `--with-integrations`, `--with-cli-baselines`, `--with-rulesync`, `--with-rtk`,
`--org <name> <git-url>`; detalle en [config/README.md](config/README.md). También podés pedir «instalá este repo»
en una sesión abierta en el clon (skill `agents-config-setup`).

Requisitos: bash 4+, `jq` y GNU sed/awk/xargs/tar (macOS: `brew install bash gnu-sed gawk findutils gnu-tar`).

```bash
# 2. Marketplace de Claude Code: skills globales, subagentes y hooks genéricos; sin reglas, archivos generados ni merge
claude plugin marketplace add LorenGrz/agents-config
claude plugin install agents-config@agents-config
```

## Cómo se trabaja

Un cambio trivial (una línea o un typo) se hace directo. Cualquier otra tarea, aunque sea de un archivo, arranca con
una pregunta con tres opciones, siempre en este orden (`lane-guard.sh` lo impone):

| Lane | Qué es |
|---|---|
| Continuar | directo, sin plan |
| Plan S | plan corto (archivos, cambio, check); sin entrevista, solo las preguntas críticas en un lote; subagentes solo si el trabajo los pide |
| Plan L | entrevista de `mattpocock-skills:grilling`, spec y tickets con `to-spec` y `to-tickets` en `.scratch/` (local, sin versionar), un `worker` por ticket desbloqueado, un líder por repo o workspace cuando el trabajo cruza repos |

- **Orquestador**: la sesión principal. Planifica, escribe los briefs e integra; en Plan L no escribe código.
- **Líder**: una sesión en cada repo que toca el trabajo, con las skills y restricciones de ese repo, o en la carpeta del workspace cuando las skills viven ahí (ese líder puede mandar un líder a cada repo hijo). Implementa, puede lanzar `worker`, `scout` y su reviewer, commitea en la rama de la tarea y hace revisar su diff. En un solo repo es el orquestador.
- **`worker`** (Opus): implementa algo ya decidido, en segundo plano: test primero (`mattpocock-skills:tdd`), después código y docs; corre solo sus tests y no commitea. Default para todo cambio no trivial. **`scout`**: solo lectura.
- **`reasoner`**: decisiones caras de errar (arquitectura, bugs sin causa conocida, cambios difíciles de revertir).
- **Reviewer**: dos agentes aparte (el subagente `reviewer`), en paralelo y sin editar, antes de cada PR y del merge que
  cierra un Plan L: **Standards** (reglas del repo, smells y los checks del CI) y **Spec** (contra el ticket o la spec),
  con los informes separados. Una re-revisión por eje; otro proveedor, solo a pedido (`review-handoff`).

```mermaid
flowchart LR
  Q{"¿Trivial?"} -- sí --> D[Directo]
  Q -- no --> P{"Continuar / Plan S / Plan L"} --> OQ{"Continuar / Orquestar"}
  OQ -- Orquestar --> LO[un líder por rama, en su sesión y worktree] --> O
  P -- Continuar --> W[worker en su worktree]
  P -- Plan S --> S[Plan corto]
  P -- Plan L --> G[grilling, spec y tickets] --> WL[un líder por repo o workspace, con sus workers]
  W --> O[El orquestador revisa y commitea]
  D & S & O & WL --> R["Revisión: Standards y Spec en paralelo"] --> M["PR o merge: lo que queda de la spec va a un ADR"]
```

| Harness | Líder | `worker` | Reviewer |
|---|---|---|---|
| Claude Code | subagente con la ruta en el brief | subagente `worker` con `run_in_background` | subagente `reviewer` |
| T3 Code | `t3_thread_launch` en el proyecto de ese repo o workspace | `delegate_task` con `isolation: "worktree"` | subagente `reviewer` (hilo en Claude) |
| Orca | worker de Orca en ese repo o workspace | workers de Orca (skill `orchestration`) | worker de Orca |

El modelo de cada rol lo define tu perfil («Model routing»). Un agente lanzado con un brief lo ejecuta, sin preguntar la
lane. Reglas: `config/AGENTS.md` («Workflow lanes»), `config/CLAUDE.md` («Agent Routing»), ADR 0022, 0029, 0033, 0034, 0036 y 0037.

## Capas

- **Global** (este repo): `config/` y `skills/`, instalados en la máquina. Ver [config/README.md](config/README.md).
- **Organización**: el repo privado de cada empleador o cliente, clonado en `organizations/<name>/` y nunca versionado
  acá. Suma políticas, skills y comandos; nunca relaja `config/baseline.md`. Ver [organizations/README.md](organizations/README.md).
- **Proyecto**: `project-init` arma un repo (`AGENTS.md`, hooks, CI) o documenta uno existente; `project-agents.sh` le
  instala skills, reglas, MCP y packs de su stack y su org. Va en todo repo con un segundo commit o un PR: las
  instrucciones solo guían, el lint, los hooks y la CI se cumplen igual.

## Estructura del repo

```
AGENTS.md, CLAUDE.md   mapa para agentes (CLAUDE.md lo importa); install.sh, sync.sh: instalación y espejo de skills
config/                instrucciones, baseline, perfiles, reglas, hooks, subagentes, settings base
skills/<category>/     la biblioteca de skills
packs/, organizations/ packs por arquitectura (ADR 0014); contrato y plantilla de org (sus repos, fuera de git)
scripts/               project-agents.sh, orgs.sh, detect-stack.sh, gen-*.sh, lint-docs.sh, leak-guard.sh, eval-skills.sh, export-obsidian.sh, stack-sync.sh, test-*.sh
hooks/, .claude-plugin/  el plugin; gen-plugin.sh genera hooks/hooks.json y las skills de plugin.json
docs/decisions/        ADRs de este repo; evals/: evals de activación de skills
.agents/CONTEXT.md     estado actual, para agentes; .githooks/: leak guard en commit y push
```

## Comandos frecuentes

```bash
./sync.sh                              # tras agregar o mover una skill
scripts/gen-plugin.sh && scripts/gen-intents.sh   # plugin.json, hooks.json, intents.json, Shortcuts (--check en CI)
bash scripts/lint-docs.sh --strict     # plantillas de skills, reglas y comandos de packs
scripts/leak-guard.sh --all            # nada de una organización privada en el repo público
git config core.hooksPath .githooks    # activa la guarda en cada commit y push
for t in leak-guard packs orgs intents cli-baselines install-blocks install-settings lane-guard orquestar worktree-cleanup stack-sync; do bash scripts/test-$t.sh; done
```

## Problemas comunes

| Síntoma | Qué mirar |
|---|---|
| Una skill no se activa | `/context` para ver qué cargó; que su `description` coincida con la tarea; `./sync.sh` si es nueva |
| Reglas o hooks viejos | `./install.sh` los vuelve a enlazar; `ls -l ~/.claude/rules` y `readlink ~/.claude/hooks` |
| Un hook no corre | `/hooks` para ver los registrados; `~/.claude/logs/instructions-loaded.log` muestra qué cargó y cuándo |
| `settings.json` quedó mal | el `.bak.<timestamp>` al lado: `install.sh` siempre hace backup antes de escribir |

## Dónde seguir

[config/README.md](config/README.md) · [skills/README.md](skills/README.md) · [organizations/README.md](organizations/README.md) · [docs/decisions/README.md](docs/decisions/README.md)

## Créditos

[obra/superpowers](https://github.com/obra/superpowers) (flujo por specs y formato de skill) · [trailofbits/claude-code-config](https://github.com/trailofbits/claude-code-config)
(hooks y barandas) · [affaan-m/ECC](https://github.com/affaan-m) (convenciones de config) · [rtk-ai/rtk](https://github.com/rtk-ai/rtk)
(reducción de tokens) · [dyoshikawa/rulesync](https://github.com/dyoshikawa/rulesync) (reglas y skills para varias IA).
