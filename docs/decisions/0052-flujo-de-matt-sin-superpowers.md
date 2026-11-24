# 0052 — Flujo de Matt Pocock sin superpowers: worker en Opus con TDD y revisión en dos ejes

Estado: aceptado (2026-11-24). Reemplaza el Plan L con `brainstorming` y `writing-plans` de 0022, la spec y el
plan en `docs/superpowers/` de 0034 y los atajos de superpowers de 0017; ajusta el reviewer único por PR de 0048 y
0050 y el `worker` en Sonnet de 0003 y 0036.

## Contexto

Loren pidió (plan del 2026-11-24):

- **Sin superpowers:** el Plan S sigue con ponytail y el Plan L pasa a las skills de Matt Pocock (`grilling` ya era
  obligatorio en el Plan L por 0025).
- **Spec y tickets solo locales,** en `.scratch/<tema>/`, nunca versionados. Hasta ahora la spec y el plan se
  commiteaban en `docs/superpowers/` y se borraban en el merge (0034).
- **Worker en Opus:** escribe el test, el código y las docs, corre solo los tests que creó y le devuelve el
  trabajo al orquestador.
- **Revisión al estilo de `code-review` de Matt:** dos revisores en paralelo, Standards y Spec, en vez de un
  reviewer por PR (0048, 0050). Ese skill los separa porque un código puede seguir todas las reglas e implementar
  otra cosa, o al revés, y un informe único deja que un eje tape al otro.

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
- El worker en Opus cuesta más por tarea que en Sonnet.
- La spec no queda en el repo: si la máquina se pierde a mitad de una tarea, se pierde la spec. El ADR y el PR
  guardan lo que dura.
- `install.sh` mergea `extraKnownMarketplaces` por unión: en una máquina ya instalada, el marketplace de
  superpowers se saca a mano de `~/.claude/settings.json`.
- Los ADR anteriores no se reescriben; donde nombran superpowers o `docs/superpowers/`, manda este.
