# agents-config modular: base + organizaciones + project-init multi-stack

## Context
Software factory: tu config personal (pública) más N organizaciones privadas, con proyectos ligados a una org. Hoy `project-init` es solo TS, no entrevista, y las prácticas de Acme están mezcladas con su dominio. Objetivo: capas claras, poco contexto cargado, decisiones críticas siempre consultadas.

## Capas
| Capa | Dónde | Qué tiene |
|---|---|---|
| Base (pública) | `~/.agents/skills` | Prácticas genéricas, `config/baseline.md` (piso no negociable), packs por stack/arquitectura |
| Perfil | `config/profiles/<user>.md` | Preferencias personales, **incluido el routing de modelos** (ej. implementador = `worker`/Sonnet) |
| Org (privada) | `organizations/<org>/` (repo propio, ignorado por el público) | `POLICIES.md`, skills, commands, templates, `org.json` |
| Proyecto | `.agents/project.json` | Org, respuestas de la entrevista, packs, versiones |

- Una org puede pisar convenciones, pero nunca el baseline: secretos, verificación, mínimo privilegio, sin push forzado, no asumir arquitectura.
- Las orgs son repos anidados e ignorados, no submódulos. Cada repo se pushea por separado con `scripts/orgs.sh` (`add|status|pull|push`).
- Las versiones de la base y de la org quedan en `.agents/skills.lock`.

## Dónde poner índices (eficiencia de contexto)
1. **`description` de cada skill**: es el índice principal y no cuesta nada extra, porque Claude ya lo carga. Hasta 2 líneas con palabras clave ES/EN.
2. **`AGENTS.md` del proyecto**: una tabla `palabras clave → skill` de 10 filas como máximo, solo para lo ambiguo o crítico. Sin archivo de índice aparte.
3. **`POLICIES.md` de la org**: empieza con un resumen de unas 10 líneas y anclas por sección; el detalle se lee solo cuando hace falta.
4. **Global**: `organizations/INDEX.md` (local, ignorado), con una línea por org (`org | cómo reconocerla | ruta a POLICIES`), importado en `~/.claude/CLAUDE.md`.

Nada más se carga siempre. Los cuerpos de las skills se leen solo cuando se usan.

## Hooks: solo en puntos críticos
- Generalizar `config/hooks/critical-reasoning.sh` para que lea un mapa `critical.json` (base + org + proyecto). Cada entrada es `keywords|paths → skill`, por ejemplo:
  - migraciones → `database-persistence-patterns`
  - auth → `auth-security-basics`
  - ERP → `acme/erp-integration`
- Inyecta "leé skill X / consultá reasoner". No bloquea.
- Ningún hook más para la activación normal.

## Planificación
- La regla base deja de ser "siempre subagentes". Pasa a ser: **al planificar, recomendar si conviene usar subagentes, y cuáles, y preguntar**.
- La recomendación por defecto sale del perfil.

## Fases
0. **Limpieza de la base**
   - Pasar el routing de modelos de `config/CLAUDE.md` al perfil y dejar en la base roles genéricos (relevar / decidir / implementar).
   - `baseline.md`.
   - `plugin.json`: exportar solo lo global.
   - Generar `hooks.json` desde `settings.base.json`.
   - Mover `orca-cli/` y `orchestration/` a `meta/`.
   - Leak guard (pre-commit + CI, blocklist local).
1. **Entrevista de `project-init`** (`references/interview.md`):
   - Preguntas: org (detectada por el remote, siempre se confirma), stacks, backend, frontend, datos/auth, testing/deploy, SDD.
   - Las respuestas críticas nunca toman un default; si no hay respuesta quedan `pending`.
   - Salida: `project.json` + ADRs.
2. **Templates** `java-spring`, `kotlin-spring` y `python`:
   - lint, CI y `pre-push`
   - Spring Initializr / `uv init`
   - `init.sh` parametrizado
3. **Packs genéricos** (inspirados en Acme, escritos de cero):
   - Backend hexagonal o modular (Spring y Python).
   - Frontend feature-sliced o hexagonal.
   - `ui-library`.
   - `workflow` con los commands `/smart-commit`, `/pr-message`, `/ship-pr`, `/issue`.
   - `run-app`.
   - `project-agents.sh` copia skills y commands, y escribe la tabla en `AGENTS.md`.
4. **Org Acme + `meta/org-creator`**:
   - `POLICIES.md` extraído (sin inventar) de los `CLAUDE.md` y commands de los repos de la org.
   - Las skills de dominio (design system, ERP, DB, Jira) van a la org.
   - Los repos actuales de Acme no se tocan.
   - El repo privado en GitHub se crea solo tras confirmar el owner.
5. **Docs**:
   - ADRs: capas/orgs, entrevista, índices + hooks críticos, leak guard.
   - README y `CONTEXT.md` concisos.

Ejecución: una rama por fase. Antes de cada fase grande recomiendo si conviene usar `worker`s y te pregunto.

## Verificación
- `leak-guard.sh` da 0 hits en el público. `git check-ignore organizations/acme` responde que sí.
- Test del mapa de hooks críticos: JSON de ejemplo → la skill esperada.
- `e2e.sh` en el scratchpad con 4 casos: java+org acme, java personal, kotlin, python. Verifica los archivos generados, los builds y que el caso personal no tenga términos de Acme.
- `eval-skills.sh` sobre los triggers.
