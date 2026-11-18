# 0019 — AGENTS.md primero: la única fuente para todo agente y baseline para toda CLI

Estado: aceptado (2026-11-09).

## Contexto

Cada repo de `project-init` traía un `CLAUDE.md` con solo `@AGENTS.md` y `@.agents/CONTEXT.md` porque Claude
Code no leía `AGENTS.md`; ahora lo lee. Las siete reglas de `config/baseline.md` solo llegaban a Claude Code:
agy, Copilot y OpenCode no recibían nada global, y Codex solo por `~/.codex/AGENTS.md`.

## Decisión

- Claude Code 2.1.277+ (local: 2.1.319) lee `AGENTS.md` como instrucciones del proyecto cuando no hay
  `CLAUDE.md`, `.claude/CLAUDE.md` ni `CLAUDE.local.md` en el directorio de trabajo o uno superior
  (`~/.claude/CLAUDE.md` no cuenta). Verificado en vivo con la sesión principal y un `worker`: los subagentes
  cargan la misma jerarquía de memoria, salvo Explore y Plan.
- **`AGENTS.md` es la fuente en todo proyecto.** `project-init` y `adopt.sh` ya no crean `CLAUDE.md`
  (`--claude-shim` escribe el `@AGENTS.md` de una línea para versiones viejas de Claude Code). Un `CLAUDE.md`
  existente nunca se toca ni se borra: un puntero `@AGENTS.md` fino no hace daño (Claude no lee el archivo dos
  veces) y cubre las sesiones sin lectura nativa (plugin integrado desactivado; Bedrock o telemetría apagada
  antes de 2.1.281).
- **El `AGENTS.md` del template lleva las reglas críticas**: el baseline entre `<!-- baseline:start -->` y
  `<!-- baseline:end -->`, en inglés, más "read `.agents/CONTEXT.md` before exploring". Toda CLI que lee el
  `AGENTS.md` del repo (Claude, sesión principal y subagentes, Codex, Copilot, OpenCode, agy) las recibe.
  `adopt.sh` agrega el bloque una vez a un `AGENTS.md` existente que no lo tiene.
- **Baseline para las CLI sin archivo global**: `scripts/gen-cli-baselines.sh`, opt-in con
  `install.sh --with-cli-baselines`, escribe `config/baseline.md` en `~/.gemini/GEMINI.md`,
  `~/.copilot/copilot-instructions.md` (verificado con `copilot instruction list`),
  `~/.config/opencode/AGENTS.md` y, para OpenCode lanzado por CAO, `~/.aws/opencode/AGENTS.md`. Solo para las
  herramientas instaladas y con las mismas reglas de backup que `install.sh`.
- **`~/.claude/CLAUDE.md` sigue** como archivo generado con los `@imports`: es el único canal global y también
  llega a los subagentes.
- **`scout` usa `omitClaudeMd: true`** (verificado: ya no recibe la cadena de memoria). Las búsquedas no
  necesitan las reglas, y cada invocación pagaría esa cadena.

## Consecuencias

- Duplicación: el baseline aparece en el `AGENTS.md` del proyecto y en la memoria global, ~0.2k tokens en
  Claude Code. Aceptado: la copia del proyecto es lo que reciben las otras CLI y un repo clonado en otro lado.
- Un `CLAUDE.md` en cualquier directorio superior (por ejemplo `~/CLAUDE.md` o el de un workspace) apaga en
  silencio la lectura nativa de `AGENTS.md` para todo lo de abajo. `workspace.sh` todavía escribe un
  `CLAUDE.md` con `@AGENTS.md`; se revisa aparte.
- `InstructionsLoaded` no se dispara para un `AGENTS.md` leído así: `log-instructions.sh` ya no lo ve.
