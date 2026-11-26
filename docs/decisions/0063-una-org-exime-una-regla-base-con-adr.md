# 0063 — Una org exime una regla base solo con un ADR en su repo

Estado: aceptado (2026-11-25). Precisa `config/baseline.md` (reglas 6 y 7) y la sección de orgs de `config/AGENTS.md`.

## Contexto

La regla 6 pide confirmación antes de toda acción hacia afuera, y la sección de orgs decía que una org suma
reglas pero nunca las relaja. Una org pidió que su guarda confirme solo la apertura de un PR, no cada push:
con la guarda corriendo en todas sus sesiones, cada push frenaba al agente. La regla 7 ya pedía un ADR para
una política de org que reemplaza una práctica base, pero el resto del texto lo prohibía.

## Decisión

- Una org puede eximir una acción puntual de la regla 6 solo con un ADR en su propio repo, y su skill de git
  dice la excepción.
- Las demás orgs y los repos personales siguen con la regla base.
- El `intent-router` nombra la skill de reemplazo con el prefijo de su plugin cuando vive en la carpeta
  `shared` (ADR 0062), así el agente la invoca con el nombre que espera la herramienta.

## Consecuencias

- Toda excepción queda en un archivo con fecha y motivo, en el repo de la org.
- Un agente que lee la regla base y la política de la org ve el mismo criterio en los dos lados.
