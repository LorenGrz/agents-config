# 0017 — Router de intenciones, plugins por proyecto y workspaces

Estado: aceptado (2026-11-08).

## Contexto

Las skills de integración dependían de que el modelo siguiera la prosa de `config/CLAUDE.md` y recordara el
comando exacto («traete los cambios» → `git pull origin <base>`). Once plugins se prendían en toda sesión, y
nada cubría un repo sin `AGENTS.md` o sin skills de stack.

## Decisión

- **Los atajos viven en la skill dueña.** Cada skill de integración termina con `## Shortcuts`: patrones
  `tools:` y `bash:` (qué identifica sus llamadas) y líneas `intent:` (etiqueta, regex de frase en español e
  inglés, comando). Las skills de plugins no se pueden editar: las suyas van en `config/intents.plugins.md`.
  `scripts/gen-intents.sh` deriva `config/intents.json` (lo lee el hook) y una tabla corta en
  `config/AGENTS.md` entre marcadores `intents:`, así Codex y Cursor también tienen el mapa frase -> skill.
  `sync.sh` lo regenera y CI corre `--check`.
- **`config/hooks/intent-router.sh`** corre en `UserPromptSubmit` y en `PreToolUse` para `Bash` y las
  herramientas MCP de integración. Una frase inyecta "skill X; run <command>"; una herramienta o un comando
  `gh`/`git` inyecta "load skill X first". Una vez por sesión y por skill (marcador en
  `$XDG_RUNTIME_DIR/agents-intents/<session>/`), calla dentro de subagentes, texto en inglés, solo guía: nunca
  bloquea y siempre sale con 0. Un hook no puede invocar una skill: inyectar su nombre y el comando aprobado
  es lo más cercano, y las reglas `permissions.ask` de ADR 0016 siguen frenando lo que sale.
- **`<base>`** en un comando se resuelve por repo: `scripts/gh-flow.sh` presente -> `dev`; una regla "Base
  branch is `x`" en AGENTS.md; `defaults.base_branch` de la organización que coincide; `origin/HEAD`; `main`.
- **Plugins por alcance.** `vercel` y `playwright` quedan apagados en `settings.base.json`. Los stacks de
  `scopes.json` llevan una lista `plugins` (`next`: los dos, `react-vite`: playwright) y `project-agents.sh`
  la fusiona en `enabledPlugins` del `.claude/settings.json` del proyecto; `--plugin` lo fuerza. Los demás
  plugins siguen globales. Donde las skills de plugins se pisan con las del hub, `config/CLAUDE.md` nombra un
  default por tarea (planificación, TDD y debugging de causa desconocida de superpowers; review de TypeScript
  con `code-review-safety`; git siempre por `git-workflow`).
- **SessionStart revisa el estado del proyecto** y solo propone, nunca escribe: repo sin `AGENTS.md` ->
  `project-init`; repo con `AGENTS.md` y sin `.agents/project.json` o `.claude/skills` -> el comando
  `project-agents.sh --stack <detected> --dry-run` (`scripts/detect-stack.sh`); carpeta workspace -> leer su
  `AGENTS.md`; cualquier otra carpeta -> un aviso de una línea que nombra los repos y, si hay 2 o más, ofrece
  el modo workspace ("if they are one product"), salvo en `$HOME`.
- **Workspace** = una carpeta que no es repo git y tiene su propio `AGENTS.md` cuya primera línea es
  `<!-- workspace-init -->`. El modo workspace de `project-init` (`devops/project-init/scripts/workspace.sh`)
  entrevista y escribe el mapa de repos, cómo se hablan, el flujo entre repos y, con una org, sus políticas y
  skills (`project-agents.sh --no-packs`; los packs `always` suponen un repo y `gh-flow.sh`). Las skills de
  stack quedan en cada repo.
- **Dónde se versiona la config de un workspace.** Con org: `organizations/<org>/workspaces/<name>/` en el
  repo privado de la org, con symlinks a la carpeta, así nada de la empresa llega a este repo público. Sin
  org: la carpeta pasa a ser un repo git local que ignora los repos hijos, sin commit ni remoto.
- Descartado: deducir el workspace de «una carpeta con 2+ repos», porque también atraparía `~/projects`, que
  junta proyectos sin relación.

## Consecuencias

- El router es orientativo, como todo hook acá: saca el «me olvidé de cargar la skill», no el «elegí no
  hacerlo».
- La tabla de atajos puede desviarse de una skill si se edita sin correr `gen-intents.sh`; CI lo detecta. Las
  regex de frases son heurísticas: un falso positivo cuesta una línea, una vez por sesión.
- Todo repo sin `AGENTS.md` (también los clones de terceros) recibe la propuesta de `project-init` al iniciar
  la sesión.
- Un repo web no configurado con `project-agents.sh` no tiene `vercel`/`playwright` hasta `--plugin` o su
  stack.
- No verificado en una sesión real: que Claude Code siga un symlink `.claude` en una carpeta workspace y que
  `enabledPlugins` por proyecto tenga efecto.
