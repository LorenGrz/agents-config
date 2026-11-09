# Análisis agents-config ↔ caolg + artefacto gráfico + propuesta

## Contexto

Loren quiere entender a fondo qué hace agents-config, cómo lo consumen Claude Code / Codex / agy / Cursor, cómo encaja caolg (líder Opus + workers multi-CLI vía CAO) y cómo reducir el contexto que paga cada sesión limpia. Decisiones ya tomadas por él:
- Alcance: **artefacto + propuesta** (los cambios de código van en un plan posterior a aprobar).
- Dirección: **agents-config es la fuente**; caolg sigue siendo repo propio y consume de ahí.
- Quiere que el modo plan recomiende entre **dos caminos**: liviano (PonyTail para fixes / features chicas) y pesado (superpowers / híbrido con subagentes para features grandes).

Hallazgos de la exploración (dos agentes Explore + lectura propia, cifras de `wc -c`, tokens ≈ bytes/4):

**Costo fijo por sesión de Claude Code: ~35–45 KB ≈ 9–12k tokens** antes del system prompt propio:
- Memoria global (`~/.claude/CLAUDE.md` + 5 imports): ~17.2 KB / ~4.3k tok. `config/CLAUDE.md` volvió a 5.9 KB / 73 líneas (ADR 0004 pedía ≤3.2 KB / ≤60).
- Lista de skills: 37 globales (~2.5–4.3k tok) + plugins (~4k tok: superpowers, mattpocock, claudex-loop, claude-obsidian, codex…).
- superpowers inyecta `using-superpowers` completo en SessionStart (~850 tok).
- Proyecto: CLAUDE.md + AGENTS.md (+ CONTEXT.md) ~1–3k tok.
- Reglas: las 9 tienen `paths:` → 0 al inicio (bien).

**Duplicaciones**: routing de agentes dicho 4 veces (config/CLAUDE.md, profile, session-start.sh, critical-reasoning.sh); lista de skills en config/CLAUDE.md que nombra skills no instaladas globalmente; coaching de inglés, desktop config y git repetidos entre AGENTS/baseline/profile; bloque Shortcuts pagado dos veces en Claude.

**Otros agentes**: Codex recibe `~/.codex/AGENTS.md` (11 KB concatenado) y, vía `~/.agents/skills` → hub entero, posiblemente los 85 SKILL.md (incluye packs, stack y skills privadas de `organizations/<org>`). agy, Copilot, OpenCode y Cursor **no reciben nada global** (rulesync nunca corrió; `sync.sh` saltea el link de Gemini porque Omarchy ya creó la carpeta).

**caolg dentro de agents-config (conflictos reales)**:
1. Los hooks de agents-config corren en cada Claude de CAO: `session-start.sh` le dice a los workers que usen scout/worker/reasoner (los perfiles prohíben abrir agentes) y en repos sin AGENTS.md (repos de una org) que propongan `project-init` antes de trabajar → puede trabar asignaciones.
2. `critical-reasoning.sh` dispara en casi toda asignación (los roles contienen "arquitectura", "migraciones", "seguridad") y empuja a gastar Opus fuera de la rotación de cupo. No tiene dedupe por sesión. **Observado en esta misma sesión**: disparó sobre las notificaciones de los subagentes, y el intent-router también ("email", "Jira ticket" sacados del texto del reporte).
3. Push: `caolg/AGENTS.md` dice "push a main sin preguntar"; `baseline.md` #6 exige confirmación y #7 pide ADR para pisarlo; no existe.
4. intent-router sugiere `git-workflow` (incluye push/merge) a workers que tienen "nunca push".
5. agy/Copilot/OpenCode corren auto-aprobados y sin baseline: las reglas solo están repetidas a mano en cada perfil.
6. Dependencia implícita: caolg lee los caches que escribe `config/hooks/statusline.sh` (`~/.cache/claude/rate-limits.json`, `ctx/$CAO_TERMINAL_ID.json`); no está documentado como contrato.
7. caolg sin `CLAUDE.md` (`@AGENTS.md`), sin `docs/prompts.md` (manda muchos prompts), `.agents/CONTEXT.md` y AGENTS.md desactualizados ("/clear automático"); perfiles dicen "tu worktree" pero ADR 0005 usa la carpeta del rol.

PonyTail (DietrichGebert/ponytail, plugin MIT): modo "escribí menos código" (reusar código/stdlib antes de escribir), comandos `/ponytail`, `/ponytail-review`…, inyecta el modo activo antes de cada turno con hooks en Node. No está instalado.

## Entregable 1 — Artefacto (lo que se construye al aprobar)

Una página HTML publicada con la tool Artifact (privada), en `/tmp/claude-1000/-home-loren-projects-agents-config/09a25437-62c4-47e9-a5c3-dc0b608c3edf/scratchpad/agents-context-map.html`. Antes: `Artifact quickstart intent: "other"` y cargar `artifact-design` (+ `artifact-diagramming` para los SVG). Español, simple, gráfico, claro/oscuro.

Secciones:
1. **Mapa de piezas** — qué es cada cosa en una línea: `config/` (AGENTS, baseline, profile, CLAUDE, rules, hooks, agents, scopes, settings), skills por categoría, packs, `organizations/`, `project-init`/`project-agents.sh`, install/sync; y caolg (`claudes`, CAO, perfiles, roles, state.md, `.caolg-tasks`, watch/tabs/barra).
2. **Qué lee cada agente con sesión limpia, en orden** — diagrama secuencial (carriles) para: Claude Code, Codex, agy/Copilot/OpenCode/Cursor, líder CAO, worker CAO (Claude y no-Claude). Cada paso con barra de tamaño en tokens.
3. **Dónde se va el contexto** — barra apilada del costo fijo (~9–12k) por fuente + lista de duplicaciones.
4. **Conflictos agents-config ↔ caolg** — los 7 de arriba, cada uno con severidad y fix.
5. **Dos caminos de trabajo** — árbol de decisión que aplica el modo plan (ver Entregable 2).
6. **Propuesta de sincronización** — diagrama "agents-config fuente → consumidores" (Claude, Codex, agy, Copilot, OpenCode, caolg).
7. **Contexto por caso de uso** — tabla antes/después (fix chico, feature grande, review, worker CAO, Codex, agy bulk) con qué carga y qué no.
8. **Hoja de ruta** — fases con archivos a tocar.

Cifras: recalcularlas al construir con `wc -c` sobre los archivos reales (no copiar a ojo) y marcar las estimadas (p. ej. catálogo de skills de Codex no confirmado en codex-cli 0.167.0).

## Entregable 2 — Propuesta (va en el artefacto; se implementa en un plan posterior)

### A. Dos caminos, elegidos en modo plan

Regla en un solo lugar (`config/CLAUDE.md`, sección "Workflow lanes", reemplazando el routing repetido):

| | Camino S — liviano | Camino L — pesado |
|---|---|---|
| Cuándo | causa conocida, ≤3 archivos, sin contrato/esquema/migración/auth nuevo, sin decisión de arquitectura | feature nueva, >3 archivos o varios módulos/repos, contrato o datos, decisión con trade-offs |
| Cómo | sesión principal inline + PonyTail (código mínimo); test enfocado → fix → verificación chica. Sin brainstorming ni plan en docs, sin subagentes | `superpowers:brainstorming` → `writing-plans` (spec/plan en `docs/superpowers/`) → `subagent-driven-development` con `worker`/`reasoner`; si cruza repos o conviene repartir cupo entre CLIs → caolg (`claudes`) |
| Revisión | `/ponytail-review` o `code-review low` | `requesting-code-review` / `codex-review` |

- Causa desconocida → primero `systematic-debugging`; según el resultado, S o L.
- El modo plan termina con una línea: "Camino S/L porque …" (criterios de la tabla). Las instrucciones del usuario pisan a `using-superpowers`, así que el camino S explícitamente no exige brainstorming.
- PonyTail: probarlo primero en un proyecto (medir cuánto inyecta por turno) y después decidir si va global en `settings.base.json` o por scope en `scopes.json`. ADR nuevo (0019: el 0018 ya está tomado).

### B. Sincronización (agents-config fuente)

1. **Modo CAO en los hooks** (agents-config): `session-start.sh`, `critical-reasoning.sh`, `intent-router.sh` detectan `CAO_TERMINAL_ID`; workers → silencio (o solo baseline), líder → sin routing de subagentes. `critical-reasoning.sh`: dedupe por sesión (igual que intent-router), callarse en plan mode/Opus, e ignorar texto de notificaciones de tareas.
2. **Baseline para todos los CLIs** (agents-config): `install.sh` genera un archivo compacto (baseline + reglas de git/verificación, ~1.5 KB) para `~/.gemini/GEMINI.md`, `~/.copilot/copilot-instructions.md` y el dir de OpenCode que usa CAO; caolg `install.sh` lo invoca si encuentra agents-config. Los perfiles de caolg dejan de repetir esas reglas y quedan con lo propio del rol (reportar por `send_message`, no abrir agentes).
3. **Vocabulario único de roles**: agents-config define decide / implementa / busca / bulk / revisa una vez; el supervisor de caolg mapea providers a esos roles.
4. **Contrato del statusline** como ADR en agents-config (archivos y campos que caolg lee).
5. **caolg al día** (vía `project-init` adopt): `CLAUDE.md` con `@AGENTS.md`, `docs/prompts.md`, CONTEXT/AGENTS sin "/clear automático", perfiles "carpeta del rol" en vez de "worktree", ADR del override de push (baseline #7) o alinear al flujo real (rama → merge `--no-ff` → push).

### C. Contexto más chico

1. `config/CLAUDE.md` de vuelta a ≤60 líneas: sacar la lista de skills que repite descripciones o nombra skills no globales; routing en un solo lugar (lanes).
2. Dedupe AGENTS / baseline / profile (inglés, desktop, git, orgs).
3. Plugins por scope: claude-obsidian, claudex-loop, mattpocock, codex fuera del global → `scopes.json` o activación a pedido (mayor ahorro, ~3–4k tok por sesión).
4. Codex: `~/.agents/skills` como espejo curado (igual que `~/.claude/skills`), no el hub entero (saca packs, stack y org privadas).
5. Workers CAO: `skills:` en los perfiles para no cargar los 17 skills de CAO; el rol se pasa una vez, sin pedirle releer `CLAUDE.md` que ya se carga solo.

## Archivos (solo lectura ahora; referencia para el plan siguiente)

agents-config: `config/CLAUDE.md`, `config/AGENTS.md`, `config/baseline.md`, `config/profiles/loren.md`, `config/hooks/{session-start,critical-reasoning,intent-router,statusline}.sh`, `config/settings.base.json`, `config/scopes.json`, `install.sh`, `sync.sh`.
caolg: `profiles/*.md`, `AGENTS.md`, `.agents/CONTEXT.md`, `install.sh`, `bin/caolg-session`, `codex/cao-safe.config.toml`.

## Pasos de ejecución al aprobar

1. Recalcular tamaños con un script de solo lectura (`wc -c` sobre la cadena de carga) → JSON en scratchpad.
2. `Artifact quickstart` (intent other) + skills de diseño/diagramas; escribir el HTML en scratchpad y publicarlo.
3. Copiar este plan a `agents-config/docs/superpowers/plans/2026-11-09-context-map-caolg-sync.md` (convención del repo). Sin commit ni push salvo que Loren lo pida.
4. Responder con el link y un resumen corto + la recomendación de camino para la implementación (B+C es camino L: >3 archivos en dos repos).

## Verificación

- Las cifras del artefacto coinciden con la salida del script `wc -c` (revisar 3–4 al azar).
- El artefacto se ve bien en ancho de teléfono y en oscuro (preview tras publicar).
- Nada fuera del scratchpad y del archivo del plan copiado se modifica: `git status --short` limpio en ambos repos salvo ese archivo.
