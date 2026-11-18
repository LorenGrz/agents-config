# 0002 — rulesync para distribuir reglas y skills a varias IA

Estado: aceptado (2026-10-10).

## Contexto

`AGENTS.md` y `config/rules/*.md` tienen formato de Claude Code y Codex (`paths:` en el frontmatter). Cursor y
Antigravity piden sus propios formatos y ubicaciones (`.cursor/rules/*.mdc`, `~/.gemini/GEMINI.md` +
`~/.gemini/config/rules/*.md`); mantener una copia a mano por herramienta duplica y diverge.

## Decisión

- Se usa [`rulesync`](https://github.com/dyoshikawa/rulesync) (`pnpm dlx rulesync`, unas 50 herramientas, con
  modo `--global`/`-g`), alimentado por `config/rulesync/build.sh`, que rearma en cada corrida un árbol
  descartable `.rulesync/` desde las fuentes reales:
  - `config/AGENTS.md` → `.rulesync/rules/overview.md` (regla raíz; se le agrega frontmatter).
  - Cada `config/rules/*.md` → `.rulesync/rules/<name>.md` (su `paths:` pasa a `globs:`; el cuerpo se copia
    sin cambios).
  - Algunas skills (`project-init`, `typescript-code-quality`, `react-component-validator` como prueba) se
    enlazan con symlink, sin copiar, en `.rulesync/skills/`: rulesync sigue symlinks y su frontmatter ya
    sirve.
- `.rulesync/` está ignorado (`config/rulesync/.gitignore`): es un artefacto de build, no una segunda fuente.
- Targets generados, verificados con `HOME` apuntando a un directorio temporal:

| Target | Reglas globales | Skills globales |
|---|---|---|
| `codexcli` (Codex CLI) | ✅ → `~/.codex/AGENTS.md` | ✅ |
| `cursor` | ❌ (rulesync: solo a nivel proyecto) | ✅ → `~/.cursor/skills/` |
| `antigravity-cli` (CLI de la familia Gemini) | ✅ → `~/.gemini/GEMINI.md`, `~/.gemini/config/rules/*.md` | ✅ → `~/.gemini/antigravity-cli/skills/` |

- Para la familia Gemini se usa `antigravity-cli` (Google Antigravity: `antigravity-cli` / `antigravity-ide`),
  que coincide con el paso 3 de `sync.sh` (enlaza `~/.gemini/config/skills` al espejo) y es lo que corre
  `install.sh --with-rulesync`.
- En el `$HOME` real, `~/.codex/AGENTS.md` ya es un symlink al hub (lo crea `install.sh`) y rulesync no
  escribe a través de un link que sale de su raíz: `codexcli` es un no-op seguro; el valor está en `cursor` y
  `antigravity-cli`.
- Descartado: un target `geminicli`, que no existe (el schema lo rechaza:
  `Invalid option: expected one of "agentsmd"|...`).

## Consecuencias

- Un cambio en `config/AGENTS.md`, `config/rules/*.md` o una skill fuente llega a Cursor y Antigravity con
  `install.sh --with-rulesync`.
- `cursor` no recibe reglas globales (solo skills/subagents/mcp/hooks/permissions): las reglas de Cursor van
  por proyecto.
- Si rulesync suma un target "Gemini CLI", se agrega al array `targets` de `config/rulesync/rulesync.jsonc`;
  `features` y el build ya parametrizan la salida por target.
