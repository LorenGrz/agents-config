# 0055 — Entorno del CI, checks colgados, tests en rojo y diseño ante la misma clase de hallazgo

Estado: aceptado (2026-11-24).

## Contexto

Una retro de cinco días de trabajo en un repo de una organización encontró cuatro problemas de proceso que no
dependen del repo:

- Los workers instalaban con `pnpm` por defecto y corrían con el Node local (26), mientras el CI usa `npm ci`
  con Node 20: el lint fallaba solo en local y se perdían vueltas averiguando por qué.
- Un `next build` colgado (un Web Worker que se importaba a sí mismo) se tomó como lento y se dejó para el CI,
  que esperó su tope de 20 minutos y lo canceló.
- Un arreglo pasó la review con un test que seguía en verde sin el arreglo.
- La review de un lector de archivos encontró un ataque nuevo en cada vuelta (doce commits en cinco días): se
  parcheaba cada caso y el diseño que cerraba la clase (proceso aparte con tope) llegó al final.
- Las capturas se leían enteras (200.000 a 365.000 caracteres cada una), varias dos veces, y seis sesiones se
  quedaron sin contexto.

## Decisión

- Runtime y gestor de paquetes salen del CI del repo; `pnpm` solo para un proyecto nuevo o sin CI. Un
  resultado local que no coincide con el CI es una diferencia de entorno hasta que el entorno coincide.
- Un check que pasa de tres veces su duración habitual está en rojo: se corta y se diagnostica antes de pushear.
- El worker devuelve la salida en rojo de cada test nuevo antes del código; el revisor Spec marca `major` un
  arreglo cuyos tests siguen en verde sin él.
- Ante el segundo caso de la misma clase de problema en una review, se propone un diseño que cierre la clase
  antes de parchear el caso.
- Una captura se lee una vez, de una copia reducida.

## Consecuencias

- Las instrucciones viven en `config/AGENTS.md` (Working Style y Verification), `config/agents/worker.md` y
  `config/agents/reviewer.md`.
- El tope de tres veces es un criterio, no un timeout: cada repo puede llevarlo a sus scripts de checks.
