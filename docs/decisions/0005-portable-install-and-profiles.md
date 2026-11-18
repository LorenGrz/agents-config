# 0005 — Instalación portable, perfiles personales y marketplace de plugins

Estado: aceptado (2026-10-10).

## Contexto

El hub mezclaba config compartible con la identidad, la etapa, el owner de GitHub y las rutas
`/home/loren/...` de Lorenzo Graizzaro. `install.sh`/`sync.sh` fijaban `~/.agents/skills` como ubicación del
hub y `devops/project-init` usaba `LorenGrz` como owner por defecto.

## Decisión

- **Lo personal, separado de lo genérico.** `config/AGENTS.md` y `config/CLAUDE.md` llevan solo instrucciones
  compartibles: sin nombres, detalle de roadmap ni rutas personales. Lo personal (identidad, idioma, English
  coaching, owner de GitHub, etapa, rutas de proyectos y herramientas, repo de settings del SO) va a
  `config/profiles/loren.md`; `config/profiles/_template.md` es el punto de partida comentado.
- **`install.sh --profile <name>`** resuelve el perfil en este orden: el flag; la elección guardada
  (`~/.config/agents-config/profile`); `gh api user --jq .login` si coincide con un perfil existente; ese
  login con `config/profiles/_template.md` copiado para completar; el template directo si no hay `gh`. El
  directorio de estado se cambia con `AGENTS_CONFIG_STATE_DIR`; los nombres viejos (`AGENT_CONFIG_STATE_DIR`,
  `~/.config/agent-config`) se siguen leyendo (ADR 0007).
- **`~/.claude/CLAUDE.md` y `~/.codex/AGENTS.md` son archivos generados**, no symlinks: el primero importa con
  `@` `config/AGENTS.md` + el perfil + `config/CLAUDE.md`; el segundo concatena `config/AGENTS.md` + el perfil
  (Codex no tiene `@`-import). Llevan un comentario de cabecera que los marca como generados; solo esos se
  regeneran en silencio, y un archivo real previo se respalda una vez (`.bak.<timestamp>`), igual que la
  reparación de symlinks de `rules/hooks/agents`.
- **`install.sh`/`sync.sh` derivan la ubicación del hub de su propia ruta**
  (`$(dirname "${BASH_SOURCE[0]}")`), no de `~/.agents/skills`: el repo funciona clonado en cualquier lado.
- **`--owner` de `devops/project-init`** toma `gh api user --jq .login`, después `git config github.user`, y
  es obligatorio si ninguno resuelve: no más `LorenGrz` silencioso en `init.sh` ni en `bootstrap-github.sh`.
- **`AGENTS.md`/`CLAUDE.md` en la raíz** (distintos de los de `config/`) le dicen al agente que abre el repo
  cómo guiar la instalación (dry-run, resolver o crear el perfil, confirmar, instalar, verificar),
  implementado como la skill `meta/agents-config-setup`.
- **Marketplace de plugins de Claude Code** (`.claude-plugin/marketplace.json` + `.claude-plugin/plugin.json`)
  como segunda vía, más liviana: skills (entradas `skills` por directorio de categoría, `aws/`,
  `development/`, etc., que ya son directorios de `<name>/SKILL.md`, sin aplanar), los tres subagentes y un
  subconjunto genérico de hooks (`hooks/hooks.json`, con `${CLAUDE_PLUGIN_ROOT}`) sin `guard-omarchy.sh`
  (propio del escritorio, queda para `install.sh`) ni la status line de costos no versionada. Las rules no son
  componente de plugin (verificado en la referencia de componentes): llegan solo por `install.sh`.
- El plugin e `install.sh` son alternativas y no se combinan en una máquina; en esta el plugin no está
  instalado.

## Consecuencias

- Cualquiera clona, corre `./install.sh --dry-run`, crea su perfil desde `_template.md` y tiene un setup sin
  contenido personal de Loren; `./install.sh --profile loren` reproduce el de Loren.
- `devops/project-init` sirve a cualquier usuario de GitHub sin `--owner` si `gh` está autenticado o
  `git config github.user` está definido.
- Las preferencias personales nuevas van a un perfil: se rechaza un PR que agregue un nombre o una ruta
  personal a `config/AGENTS.md` o `config/CLAUDE.md`.
