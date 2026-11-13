# Plan S — Recorte de skills personales (agents-config)

## Contexto
Mismo proceso que se aplicó a las skills de la organización (repo privado de la org), ahora sobre las skills propias de `~/projects/agents-config`: revisores Fable sacan repetición, relleno y conocimiento genérico, mueven material de consulta a archivos aparte y corrigen errores e incongruencias. Objetivo: menos tokens cargados por skill sin perder reglas, valores propios ni disparadores.

Decisiones del usuario (entrevista):
- Revisores Fable en paralelo, y ellos aplican los cambios.
- `description` no se toca: los problemas que tenga van a "Propuestas".
- Todo lo demás se aplica directo: recortes, mudanzas a referencias y arreglos de errores o incongruencias.
- La repetición entre skills siempre se deduplica.
- Afuera: `skills/external/*` y las exentas `frontend-design`, `orca-cli` y `orchestration`. Estas tres se leen solo para detectar contradicciones.
- Alcance: `skills/` (48 skills) más las 16 de `packs/`.
- Organización: solo se avisan las diferencias entre `packs/frontend-ui` y `backend-hexagonal-spring` y sus equivalentes de la org. No se edita.
- Entrega: worktree, merge a `master` y push.

## Hechos verificados
- `scripts/project-agents.sh` copia la carpeta entera de la skill (`cp -rL` L114 stack, `cp -r` L208 packs) y `sync.sh` enlaza el directorio. Las referencias se instalan siempre, ya existe `skills/aws/serverless-scanner/references/` como precedente.
- Una skill de pack o stack se instala sola en el proyecto. Por eso un puntero a otra skill solo va dentro de la misma unidad de instalación (mismo pack, mismo stack, o global a global). Si la dueña queda afuera, la regla dura se deja en una línea y se agrega el puntero.
- `lint-docs.sh` mira solo `SKILL.md` y exige la plantilla de ADR 0026 (hoy da 0 violaciones). `## Shortcuts`, presente en 8 skills, alimenta `gen-intents.sh` y tiene que quedar byte a byte igual.
- El pre-commit corre `leak-guard --staged` y `gen-plugin.sh --check`. Nada de la organización entra en archivos ni en mensajes de commit: las diferencias van solo al reporte en el chat.

## Pasos
0. **Preparación**
   - Copiar este plan a `docs/superpowers/plans/2026-11-13-recorte-skills-personales.md`. Va en el mismo commit.
   - `git -C ~/projects/agents-config worktree add ../agents-config-recorte -b refactor/skills-recorte master`.
   - Línea base en el scratchpad: copia de `skills/` y `packs/`, `wc -w` y el resultado de `lint-docs --strict`.
1. **Cuatro revisores Fable en paralelo**, cada uno solo sobre sus carpetas dentro del worktree:
   - **A · Integraciones y meta:** `integrations/*` y `meta/*` menos `orca-cli` y `orchestration`. Son 17 skills, unas 7.800 palabras.
   - **B · Código y nube:** `development/*` menos `frontend-design`, más `security/*` y `aws/*`. Son 17 skills, unas 7.350 palabras.
   - **C · Packs y calidad:** las 16 skills de `packs/` y `quality/*`, unas 7.200 palabras. Además compara con la org en solo lectura.
   - **D · Gigantes:** `productivity/*` y `devops/*`, unas 10.600 palabras. Incluye `image-annotations`, `project-init` y `ats-resume-formatting`.

   **Brief común**
   - Frontmatter intacto y plantilla de ADR 0026.
   - Las mudanzas van a `references/<tema>.md`, con un puntero bajo `## Reference` que diga cuándo leerlas.
   - Antes de editar, cada revisor extrae a `scratchpad/must/<skill>.txt` los literales que deben sobrevivir: rutas, comandos, tools, números y las líneas con MUST, NEVER, nunca o siempre. Al terminar, `grep -rF` con cero faltantes.
   - Cada arreglo de error se anota con antes, después y motivo.
   - Los duplicados dentro del grupo se deduplican en el momento. Los que cruzan grupos se reportan sin editar.
   - Cada revisor entrega `wc -w` antes y después y el resultado de `lint-docs --strict --files`. Ninguno hace commits.
2. **Deduplicación entre grupos:** junto las cuatro listas, fijo la dueña de cada tema y un solo agente Fable las aplica en serie. Candidatos:
   - `team-*-agent` y `code-review-safety`
   - las skills de testing: `unit-test-generator`, `execute-test-suite`, `vitest-rtl`, `spring-testing` y `pytest-conventions`
   - `react-component-validator` y `ui-review`
   - `github-usage` y `conventional-commit-generator`
   - `jira-usage` y `jira-ticket-review`
3. **Verificación**, dentro del worktree:
   - `scripts/lint-docs.sh --strict`
   - `scripts/gen-intents.sh --check` y `scripts/gen-plugin.sh --check`
   - `for t in scripts/test-*.sh; do bash "$t" || echo "FALLA $t"; done`
   - `scripts/leak-guard.sh --all`
   - Frontmatter igual al de `master`: `diff` del bloque `---` de cada `SKILL.md` cambiado.
   - `git diff --name-status master`: solo M en `SKILL.md` y A en `references/` y en el plan.
   - Todos los punteros a `references/` existen.
   - Grep final de los literales de `must/`.
   - Tabla de `wc -w`.
4. **Entrega**
   - Dos commits en `refactor/skills-recorte`: el recorte por grupos (con el plan) y la deduplicación entre grupos.
   - En `~/projects/agents-config`: `git status --short`. Si otra sesión dejó cambios, aviso y no piso nada.
   - `git pull --ff-only` y `git merge --no-ff refactor/skills-recorte`.
   - Volver a correr lint y `test-intents.sh`, y después `git push origin master`.
   - `git worktree remove ../agents-config-recorte` y `git branch -d`, local y remota si se pusheó.
   - `./sync.sh` solo si cambió alguna carpeta de skill (no se espera).
   - Revisar `.agents/CONTEXT.md` y `AGENTS.md`, y actualizarlos solo si cambió algo documentado.

## Reporte final
1. **Cambios aplicados:** palabras antes y después por skill, referencias creadas y totales.
2. **Errores corregidos:** qué decía, qué dice y por qué.
3. **Propuestas de `description`:** sin aplicar.
4. **Diferencias con la organización:** solo en el chat.
5. **Verificación:** lint, tests, leak guard y hash del merge.

Plan S because: el usuario lo eligió. Es trabajo de texto acotado a un repo, con plantilla y tests que lo verifican. Se usan revisores Fable por pedido explícito y no hay `worker` ni `reasoner`.
