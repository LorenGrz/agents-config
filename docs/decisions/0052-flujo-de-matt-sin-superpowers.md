# 0052 — Flujo de Matt Pocock sin superpowers: worker en Opus con TDD y revisión en dos ejes

Estado: aceptado (2026-11-24). Reemplaza el uso de superpowers de 0022, 0025 y 0034 (spec y plan en
`docs/superpowers/`); ajusta el reviewer de 0048 y 0050 y el `worker` en Sonnet de 0003.

## Contexto

- Había dos procesos de diseño cargados a la vez: superpowers (`brainstorming`, `writing-plans`,
  `subagent-driven-development`) y las skills de Matt Pocock (`grilling`, ya obligatorio en el Plan L por 0025).
  Las dos pisaban las mismas decisiones.
- La spec y el plan se commiteaban en `docs/superpowers/` y se borraban en el merge: dos commits de ruido por
  tarea.
- Un solo reviewer mezclaba dos preguntas distintas: si el código sigue las reglas del repo y si hace lo que pidió
  el ticket. Un eje tapaba al otro.
- El worker en Sonnet corría lint, typecheck y la suite, que el reviewer volvía a correr.

## Decisión

- **Sin superpowers.** El plugin queda en `false` en `settings.base.json` y se saca su marketplace. Los atajos pasan
  a `mattpocock-skills:grilling` (diseño, después `to-spec`), `diagnosing-bugs` y `tdd`.
- **Plan L:** `grilling` → `to-spec` → `to-tickets` → ejecución estilo `implement-spec` (un `worker` por ticket
  desbloqueado, en paralelo, cada uno en su worktree; el líder commitea y mergea) → revisión en dos ejes.
  `to-spec`, `to-tickets`, `implement-spec` y `wayfinder` solo los invoca el usuario: la sesión lee su `SKILL.md`
  del plugin y lo sigue. El Plan S sigue con ponytail.
- **Spec y tickets locales.** El tracker de esas skills es markdown en `.scratch/<tema>/` (`spec.md` e
  `issues/NN-<slug>.md`), descripto en el bloque «Issue tracker» de `config/AGENTS.md`. Nunca se versiona:
  `install.sh` agrega `.scratch/` al ignore global de git (`core.excludesFile` o `~/.config/git/ignore`), sin tocar
  los `.gitignore` de los repos. Lo que tiene que durar va a un ADR antes del merge.
- **Worker en Opus:** test primero con `mattpocock-skills:tdd`, después código y docs; corre solo los tests que
  escribió o tocó, no commitea y devuelve archivos, tests y la salida real.
- **Revisión en dos ejes** (`review-handoff`): el padre lanza dos `reviewer` en un mensaje.
  - **Standards:** reglas documentadas del repo y su skill de review, más la lista de smells de Fowler de
    `code-review` de Matt, siempre como juicio y con el repo por encima. Corre los checks del CI una vez.
  - **Spec:** contra el ticket o la spec: lo que falta, lo que sobra y lo mal implementado, citando la línea.
  - Los informes se muestran bajo `## Standards` y `## Spec`, sin mezclar ni reordenar. El bucle de hallazgos no
    cambia: una re-revisión por eje con hallazgos.
- `project-init` genera repos con el mismo flujo: plugin `mattpocock-skills` en `.claude/settings.json` y
  `.scratch/` en su `.gitignore`.

## Consecuencias

- Una revisión cuesta dos agentes Opus en vez de uno; Spec no corre checks, así que el costo extra es de lectura.
- El worker en Opus cuesta más por tarea y ahorra la vuelta del reviewer cuando un test falla.
- La spec no queda en el repo: si la máquina se pierde a mitad de una tarea, se pierde la spec. El ADR y el PR
  guardan lo que dura.
- `install.sh` mergea `extraKnownMarketplaces` por unión: en una máquina ya instalada, el marketplace de
  superpowers se saca a mano de `~/.claude/settings.json`.
- Los ADR anteriores no se reescriben; donde nombran superpowers o `docs/superpowers/`, manda este.
