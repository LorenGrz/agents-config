# 0013 — Entrevista, manifiesto y perfiles de stack de project-init

Estado: aceptado (2026-11-04).

## Contexto

`project-init` suponía TypeScript, no preguntaba nada de arquitectura y no podía armar proyectos Java, Kotlin
ni Python.

## Decisión

- **Primero la entrevista** (`devops/project-init/references/interview.md`): org, stack, estilo de backend y
  de frontend, datos, auth, testing, deploy, SDD. Las respuestas críticas nunca toman un default; «no sé»
  queda como `pending`.
- **Manifiesto** `.agents/project.json` (schema v1) con las respuestas; `manifest.sh` lo valida (claves
  obligatorias), escribe un ADR por decisión y lista las pendientes en `.agents/CONTEXT.md`.
  `init.sh --manifest` lo consume.
- **Perfiles de stack**: `templates/<stack>/stack.env` (comandos, texto de lint, comandos permitidos),
  variantes opcionales `@maven`/`@gradle` detectadas en el proyecto generado y un `setup.sh` por stack
  (Spotless, ruff/mypy/pytest). Los archivos del stack ganan sobre `templates/common`, que usa placeholders;
  los stacks que no son node escriben `.agents/stack.env` para `gh-flow.sh pr` y `verify-ci.sh`.
- La respuesta `sdd` (`required|light|off`, validada) reescribe el paso 2 del `AGENTS.md` generado
  (`references/sdd/`); `required` deja el texto del template. El `docs-check.sh` generado lee cambios de
  dependencias en package.json, pom.xml, archivos y catálogo de Gradle, pyproject.toml y requirements*.txt.
- Stacks nuevos: `python`, `java-spring` (Maven y Gradle) y `kotlin-spring` (Gradle). `kotlin.md` no se
  adjunta a `kotlin-spring`: prescribe una arquitectura en capas, y eso lo decide la entrevista.

## Consecuencias

- En los stacks TS los archivos generados no cambian, salvo `scripts/gh-flow.sh` (una rama para `stack.env`) y
  lo que los packs agregan a propósito: la tabla de palabras clave en `AGENTS.md`, los comandos de `workflow`
  y la skill `run-app` (comprobado comparando contra una línea base).
- Cada stack tiene un e2e (`e2e.sh`); `test-manifest.sh` cubre el manifiesto sin red.
