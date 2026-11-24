# 0049 — Un PR nunca queda atrás de dev, y la review se contesta

Estado: aceptado (2026-11-20). Ajusta 0045 y 0047.

## Contexto

El 2026-11-20 el agente de review pusheó el arreglo del #510 de CX, pero el PR quedó atrás de `dev`: stack-sync
solo traía `dev` si había conflicto. Y la review quedó sin respuesta: el revisor no sabía qué se cambió.

## Decisión

- Antes de abrir un PR o de pushear a uno abierto, se trae la base (`git merge origin/dev`) y se resuelven los
  conflictos.
- stack-sync trae la base a todo PR que esté atrás, con conflicto o sin él. Un conflicto abre el agente de siempre.
- Los agentes de review y de CI traen la base antes de pushear.
- El agente de review contesta cada comentario con qué cambió y en qué commit, o por qué no. No resuelve los hilos.
- Ajuste del 2026-11-24:
  - Un worktree limpio que solo está atrás de la punta de su PR se adelanta con fast-forward y sigue. Antes se
    salteaba en cada pasada: el #513 de CX quedó trabado así.
  - Si el PR de abajo se mergeó a una rama que no es `dev` (el #512 de CX se mergeó sobre su base apilada), el PR
    de arriba trae esa rama y se retargetea a ella, no a `dev`.
- Ajuste del 2026-11-24 (tarde): stack-sync trae `dev` solo cuando el PR choca con `dev` o cuando ya está listo
  (no borrador). Un borrador atrasado sin choque queda como está. Traerlo en cada pasada llenaba los PR de merges
  (el #521 de CX llegó a 106 commits) y volvía a correr el CI cada vez. Los agentes de review y de CI siguen trayendo
  `dev` antes de pushear, y la regla de traer la base antes de abrir un PR o pushear a uno no cambia.

## Consecuencias

- Cada merge a `dev` genera un merge y un push en cada PR listo; un borrador lo recibe solo si choca.
- El revisor ve la respuesta en el PR sin preguntar.
