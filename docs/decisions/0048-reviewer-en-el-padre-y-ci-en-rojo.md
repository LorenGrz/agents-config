# 0048 — El reviewer lo lanza el padre, el líder no testea, y stack-sync arregla el CI en rojo

Estado: aceptado (2026-11-20). Ajusta 0039, 0040 y 0047, y los checks del perfil del 2026-11-19.
Ajustado por [0052](0052-flujo-de-matt-sin-superpowers.md): el padre lanza dos reviewer por PR (Standards y Spec) en vez de uno.

## Contexto

En el PR B de Difusiones de CX (2026-11-20), el líder lanzó su propio reviewer, corrió lint, typecheck y la suite
y verificó en Playwright. Después la sesión padre volvió a correr los checks: tres corridas de lo mismo y un
brief largo, mucho gasto de tokens. Loren definió el flujo: el worker recibe el contexto justo, resuelve con las
skills de su repo y le contesta al padre, sin testear. El padre lanza el reviewer, en paralelo, sin contexto de
más. Y un PR no se queda trabado: si el CI falla, también se arregla solo.

## Decisión

- **Líder**: implementa con las skills de su repo, puede lanzar `worker` y `scout`, commitea. No lanza reviewer,
  no corre lint, typecheck ni la suite (solo un test puntual para escribir un test) y no verifica en el navegador.
- **Brief**: el ticket, la causa si ya está ubicada, el contrato si cambia, los archivos, las decisiones tomadas y
  las rutas de skills que el repo no expone. Nada que el repo ya le da.
- **Padre**: al volver cada líder lanza un `reviewer` por líder, en paralelo, con solo el diff y el ticket. El
  reviewer corre los checks una vez; nadie los vuelve a correr. Lo chico vuelve al líder; lo grande, al usuario.
- **Arranque y cierre** (en CX, `cx-pr`): antes de analizar se trae `dev` y se miran los PR abiertos; al empezar
  un ticket, Jira a «In Progress» y PR en borrador; terminado y pusheado, PR listo + ticket a pruebas + comentario
  de cierre, todo junto y sin OK aparte.
- **stack-sync, paso 6**: un check del CI en FAILURE, ERROR, TIMED_OUT o STARTUP_FAILURE sobre la punta de un PR
  propio abre un Claude en su worktree, una vez por (PR, commit). Lee los logs que fallaron; si no es del código,
  relanza el run una vez; si es, lo arregla con un commit nuevo, corre solo lo que falló y pushea sin force. Va
  después del conflicto y de la review: en una corrida, un solo agente por PR.

## Consecuencias

- Una corrida de checks por PR en vez de tres, y briefs de pocas líneas.
- Un error que solo se ve en el navegador lo encuentra el reviewer o las capturas, no el líder.
- El CI en rojo se empieza a arreglar en hasta 2 minutos, en el horario de la automatización y con Orca abierto.
