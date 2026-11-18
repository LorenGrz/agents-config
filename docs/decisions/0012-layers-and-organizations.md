# 0012 — Capas: base, organizaciones y proyectos

Estado: aceptado (2026-11-04).

## Contexto

Una persona trabaja para varias empresas o clientes. Las reglas, skills y conocimiento de dominio de cada
empresa se mezclaban con las prácticas personales, y este repo es público.

## Decisión

- Tres capas: la **base** pública (este repo, con `config/baseline.md` como piso que nadie puede bajar), las
  **organizaciones** (`organizations/<name>/`, cada una su propio repo git privado, clonado pero ignorado acá)
  y el **proyecto** (`.agents/project.json`, `POLICIES.md`, `skills.lock`).
- Una org pisa convenciones y suma skills, comandos y preguntas con `org.json` (contrato en
  `organizations/README.md`); no puede debilitar el baseline. `scripts/orgs.sh` las administra.
- Repos anidados e ignorados. Los términos que identifican a cada org van a una blocklist local (ADR 0015).
- Se reconoce la org por el owner de GitHub con `organizations/INDEX.md`, local y no versionado (lo importa
  `install.sh`); `project-init` propone la org y siempre pregunta.
- Una política que reemplaza una práctica base se registra como ADR en el proyecto.
- `orgs.sh validate` (corre en `add`, `pull` y antes de instalar con `--org`; falla cerrado) detecta errores
  de contrato y frases obvias de debilitamiento en políticas, skills y comandos.
- `project-agents.sh --org` valida la org, sus nombres, las claves de `replaces` y los symlinks antes de
  escribir nada; `init.sh` pregunta antes de copiar las políticas privadas de una org a un proyecto cuyo owner
  no es uno de los owners de GitHub de la org.
- `meta/org-creator` es la entrada para una empresa o un cliente nuevo.
- Descartado: submódulos, porque registrarían la URL privada y el SHA en este repo público.

## Consecuencias

- Los push son por repo: el repo público nunca ve commits de una org. Las versiones son independientes,
  fijadas por proyecto en `.agents/skills.lock`; actualizar es explícito.
- El piso del baseline es **orientativo**: `orgs.sh validate` no es una frontera de seguridad. Un repo de org
  es código de confianza: se instalan solo orgs que uno controla.
