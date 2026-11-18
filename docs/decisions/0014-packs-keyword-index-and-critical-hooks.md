# 0014 — Packs, índice de palabras clave y hooks críticos

Estado: aceptado (2026-11-04).

## Contexto

Las skills se activaban solo por su `description`, que es probabilístico, y las skills de stack ignoraban la
arquitectura elegida.

## Decisión

- **Packs** (`packs/<name>/`: `pack.json`, `skills/`, `commands/`) agrupan skills y slash commands por
  arquitectura. `project-agents.sh` instala los packs `always` más los que cumplen su `when` contra el
  manifiesto (stack Y decisiones), y encima la org (`--org`).
- **Índice, no imposición**: una tabla de palabras clave en el `AGENTS.md` del proyecto (14 filas como máximo)
  y triggers bilingües en cada `description`. El detalle se lee a pedido y el contexto queda chico.
- **Hooks solo en puntos críticos**: `.agents/critical.json` (palabra clave o ruta -> skill) lo lee
  `config/hooks/critical-reasoning.sh`, que sugiere la skill (nunca bloquea) y se suma al empujón existente
  hacia `reasoner`.
- El ruteo de modelos sale de la base y pasa al perfil; la base nombra roles (scout, reasoner, worker) y dice
  que al planear se recomiendan subagentes y se pregunta.
- Se elimina `react-scalable-frontend` (sus reglas viven en `ui-builder`, `ui-review` y
  `feature-architecture`); `react-component-validator` queda porque la doctrina de `useEffect` no está en otro
  lado.
- El contenido de las skills se escribe de cero (inspirado en proyectos reales, sin dominio).
- Las skills de una org reemplazan a las de un pack con `replaces`, y los comandos del pack se reescriben para
  apuntar al reemplazo.

## Consecuencias

- Los packs que solo listan `when.stacks` (frontend-ui, spring-testing, python-testing) se instalan también
  sin manifiesto.
