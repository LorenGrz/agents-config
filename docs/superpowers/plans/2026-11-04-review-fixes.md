# Corregir los hallazgos del review (agents-config)

## Context
Un `reasoner` revisó (solo lectura) las 7 ramas apiladas del trabajo modular (base / organizaciones / proyectos). Encontró 4 bugs HIGH reproducidos, 10 MEDIUM y varios LOW. Los HIGH bloquean el merge: `--org` sin `--manifest` falla en silencio, `replaces` y `orgs.sh remove` pueden borrar rutas fuera de lo debido, y el leak guard no mira mensajes de commit. Objetivo: dejar el repo mergeable, con una prueba de regresión por cada hallazgo.

Alcance aprobado por el usuario: primero los bloqueos y la seguridad (HIGH 1-4 y MEDIUM 5-11, 13, 14 más doc), después una segunda pasada (enums, CI con tests, LOW). No incluye mergear, pushear ni correr `install.sh`: eso se confirma al final.

## Método
- Rama nueva `fix/review-findings` desde `docs/layers-and-orgs` (hub en `~/.agents/skills`). Un commit por bloque.
- Por cada hallazgo: primero el test que falla (reproduce el bug), después el arreglo.
- Implementación inline (los cambios están acoplados y son scripts sensibles). Recomiendo una re-revisión final de solo lectura con `reasoner` sobre el diff completo; la confirmás vos.
- Antes de implementar se copia este plan (sin nombres de la org) a `docs/superpowers/plans/2026-11-04-review-fixes.md`.
- Reutilizar: `valid-name` regex `^[a-z0-9][a-z0-9-]*$` (ya usado en `orgs.sh:85`), helper `sed_esc` de `init.sh`, `ENVIRON` en awk (ya usado en `project-agents.sh`), `scripts/test-*.sh` como base de los tests.

## Parte A - bloqueos y seguridad

### A1. `scripts/project-agents.sh` (HIGH 1, HIGH 2, MEDIUM 11)
- **ALL pipeline (línea ~296)**: reemplazar `{ ...; [ -n "$MANIFEST" ] && jq ...; }` por `if [ -n "$MANIFEST" ]; then jq ...; fi`. Test: `--org X` sin `--manifest` termina con 0 e instala la org.
- **Validación de nombres**: función `valid_name` (`^[a-z0-9][a-z0-9-]*$`). Se valida `--org`, cada clave y valor de `replaces` (sin la `/` inicial), nombres de packs, y los nombres de skills/commands de la org (`^[a-z0-9][a-z0-9._-]*$`, `.md` en commands). Cualquier fallo: error claro y exit 1 antes de tocar archivos.
- **Sin `sed` con valores de la org**: helper `replace_literal` con awk + `ENVIRON` (sustitución literal) para las filas del índice y para reescribir `.claude/skills/<from>/` en commands; escribir a archivo temporal en vez de `sed -i` (portabilidad).
- **Symlinks**: rechazar la org si `find "$OD" -type l` devuelve algo; copiar org y packs con `cp -r` (sin `-L`). `-L` queda solo para skills de stack del propio hub (`find_skill`).
- Tests (en `scripts/test-orgs.sh`): clave `../../src` y `/../../x` rechazadas y `src/` intacto; org con symlink rechazada; `replaces` con `|` y `&` no rompe filas; `--org` sin manifest.

### A2. `scripts/orgs.sh` (HIGH 3, MEDIUM 8, 9, 10)
- **Validar nombres** con `valid_name` en `remove`, `push`, `validate`, `detect`-por-nombre y `resolve`; `remove` exige que el nombre esté en el registro y que el directorio resuelto sea hijo directo de `organizations/`. Test: `remove ""`, `remove ../config`, `remove "" --force` fallan sin borrar nada.
- **Template**: `organizations/_template/org.json` con `"blocklist_terms": []`; `add --init` fija el nombre con `jq` (sin `sed -i`). `validate` rechaza el placeholder `acme` cuando el nombre de la org no es `acme`.
- **sync_blocklist**: agregar también `match.gh_owners` (las `remote_patterns` son regex y no sirven como términos fijos; se documenta).
- **validate sin `eval`**: cada chequeo es una función que devuelve estado (los bucles en subshell), así un fallo no mata el script y corren todos los chequeos. Mismo arreglo en `scripts/test-packs.sh:50-52`.
- **Baseline consultivo pero automático**: `validate` corre desde `add`, `pull` y `project-agents.sh --org` (falla cerrada: sin validación ok no se instala). El chequeo de frases prohibidas también barre `skills/` y `commands/` de la org. ADRs 0012/0015 y `organizations/README.md` dicen explícitamente "consultivo, no una garantía".
- Tests: placeholder `acme` rechazado; un chequeo que falla no impide los siguientes; `pull`/`--org` con org inválida abortan.

### A3. `scripts/leak-guard.sh` + hooks + CI (HIGH 4, MEDIUM 5, 6, 7)
- **Salida sin términos**: nunca imprimir un path o línea que contenga un término. El chequeo 1 imprime solo la cantidad. Los hits imprimen `file:line` salvo que el path contenga un término (entonces `<path redactado #n>`). En CI solo conteos.
- **Sin blocklist en CI falla**: si `CI` está definido y no hay términos, exit 1 con mensaje ("falta el secret LEAK_BLOCKLIST"); localmente sigue avisando.
- **Nuevos modos**: `--message <archivo>` (mensaje de commit) y `--log <rango>` (mensajes y refs `%B%n%D` de un rango).
- **Modo staged reescrito**: en vez de parsear el diff, recorrer `git diff --cached --name-only --diff-filter=ACMR` (cubre renames) y revisar (a) el nombre del path y (b) el blob con `git show ":$f" | grep -aiF` (cubre binarios y archivos vacíos por nombre). Modo `--all` también con `grep -a` y chequeo de nombres de `git ls-files`.
- **Hooks**: `.githooks/commit-msg` (llama `--message "$1"`) y `.githooks/pre-push` (`--all` más `--log` del rango que se empuja). `guard.yml`: `fetch-depth: 0` y un paso `--log` sobre el rango del push o del PR.
- Test nuevo `scripts/test-leak-guard.sh` (repo git temporal, término sintético): término en contenido, en nombre de archivo, en mensaje, en binario, en rename, archivo vacío con término en el nombre, `organizations/` trackeado, secretos, CI sin blocklist falla, y la salida nunca contiene el término.

### A4. Verificación online y documentación (hallazgos 13 y doc)
- **Flag de Spotless en Gradle** (`templates/{java-spring,kotlin-spring}/.claude/hooks/lint-on-edit.sh`): la búsqueda no fue concluyente y mi prueba anterior no distinguía "formatea solo el archivo" de "formatea todo". Experimento en scratch con proyecto Gradle real: dos archivos mal formateados, correr el hook sobre uno y comprobar cuál cambia, con `-PspotlessFiles` y con `-PspotlessIdeHook=<ruta absoluta>`. Regla de decisión: usar el flag que toque solo el archivo editado; si ninguno lo hace, el hook de Gradle pasa a no-op documentado (Maven queda como está). Se agrega ese chequeo a `e2e.sh`/test.
- **Ya verificado**: Spotless 3.11.0 (Maven) y 8.11.0 (Gradle) existen en Maven Central; `gitleaks-action@v3` existe. Sin cambios.
- **ADR 0013**: corregir "byte a byte idéntico": ahora cada proyecto recibe además la tabla de keywords, los commands de `workflow` y la skill `run-app` (intencional). ADR 0015: la blocklist protege solo lo listado.
- **MEDIUM 14**: `init.sh` avisa y pide confirmación cuando el owner o remote del proyecto no coincide con el `match` de la org elegida (evita copiar políticas privadas a un repo público personal).

## Parte B - segunda pasada
- **MEDIUM 12**: enums `backend-style` (`hexagonal|modular|layered`) y `frontend-style` (`feature-sliced|hexagonal|simple`) validados en `manifest.sh`, tokens listados en `references/interview.md`; `project-agents.sh` avisa cuando hay un estilo decidido y ningún pack de arquitectura coincide.
- **Items 7 de los pasos**: `guard.yml` corre `test-packs`, `test-orgs`, `test-manifest`, `test-leak-guard`; caso offline "con org vs personal sin términos de la org" en `test-orgs.sh`; `test-orgs.sh:8` copia solo `README.md` y `_template/` (el `--exclude` actual no excluye nada y arrastra la org privada al hub de prueba).
- **Reinstalación limpia**: `skills.lock` guarda `installed` (skills y commands copiados); una nueva corrida quita lo instalado antes que ya no corresponde (solo lo listado en el lock) y borra `critical.json` si queda vacío. Reescribir también menciones con backticks a skills reemplazadas dentro de skills/commands de packs.
- **LOW**: `key` de decisiones con `^[a-z0-9-]+$` en `manifest.sh`; escapar `{{PROJECT}}`/`{{OWNER}}` con `sed_esc` en `init.sh`; el hook crítico ignora (con `try`) una regex inválida sin silenciar las demás; descripciones de packs: "Use when…" en vez de "Auto-triggers…"; nota en `hexagonal-architecture` de que `create()/restore()` es una convención a adaptar al ADR del proyecto; `config/CLAUDE.md`: etiquetas de roles en inglés y redacción sin la aparente contradicción planificar-vs-delegar (respetando el tope de líneas); README: requisitos de bash 4+ y GNU sed (macOS: `brew install bash gnu-sed`).

## Parte C - cierre (requiere tu confirmación)
Batería completa y commits por bloque en `fix/review-findings`; después preguntar: (1) correr `./install.sh` de verdad, (2) mergear a `master` y pushear (o PR), (3) re-revisión final con `reasoner`.

## Archivos críticos
`scripts/project-agents.sh`, `scripts/orgs.sh`, `scripts/leak-guard.sh`, `scripts/test-orgs.sh`, `scripts/test-packs.sh`, `scripts/test-leak-guard.sh` (nuevo), `.githooks/{pre-commit,commit-msg,pre-push}`, `.github/workflows/guard.yml`, `organizations/_template/org.json`, `organizations/README.md`, `devops/project-init/scripts/{init.sh,manifest.sh,e2e.sh}`, `devops/project-init/references/interview.md`, `templates/{java-spring,kotlin-spring}/.claude/hooks/lint-on-edit.sh`, `config/hooks/critical-reasoning.sh`, `config/CLAUDE.md`, `docs/decisions/{0012,0013,0015}`, `README.md`.

## Verificación
- `bash scripts/test-packs.sh`, `bash scripts/test-orgs.sh`, `bash devops/project-init/scripts/test-manifest.sh`, `bash scripts/test-leak-guard.sh`: todos en verde, con los tests de regresión nuevos (cada uno falla antes del arreglo).
- `scripts/gen-plugin.sh --check` y `scripts/leak-guard.sh --all` limpios; commits reales pasan los hooks `pre-commit` y `commit-msg`.
- `devops/project-init/scripts/e2e.sh --stack node-ts|python|java-spring|java-spring-gradle` (red); el e2e Gradle incluye el chequeo del hook de Spotless.
- Pruebas manuales en scratch: aplicar la org privada real a un backend y un frontend de ejemplo (instala lo esperado) y comprobar que un `org.json` hostil (claves `../..`, symlinks) falla sin tocar nada.
