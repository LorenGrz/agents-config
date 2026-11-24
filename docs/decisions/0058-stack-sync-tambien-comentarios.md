# 0058 — stack-sync también toma los comentarios del PR

Estado: aceptado (2026-11-24). Ajusta 0047.

## Contexto

El 2026-11-24, en el #510 de CX, el revisor dejó sus pedidos como comentario del PR, no como review. stack-sync
solo miraba las reviews (0047), así que no abrió el agente.

## Decisión

- La lista de PR abiertos trae también `comments`. `last_review` junta las reviews de otra persona
  (`CHANGES_REQUESTED` o `COMMENTED`) con los comentarios del PR de otra persona (ni el autor del PR ni un login
  `*[bot]`) y toma el más nuevo por fecha (`submittedAt` de la review, `createdAt` del comentario).
- La marca sigue siendo por id (`review-<repo>-<pr>-<id>`): cada review o comentario dispara una vez.
- El brief de review dice «dejó una review o un comentario»; un comentario suelto se contesta con
  `gh pr comment`. Todo lo demás de 0047 y 0049 sigue igual.

## Consecuencias

- Un comentario suelto de otra persona (también un «gracias») abre un agente, como la review que solo comenta;
  si no hay nada que cambiar, lo dice y no commitea.
- La primera corrida después del merge dispara por cada PR abierto cuyo elemento más nuevo sea un comentario
  ajeno viejo: antes hay que marcar los ya atendidos.
- `gh pr list --json comments` devuelve el login de un bot sin el sufijo `[bot]` (por ejemplo `vercel`), así que
  el filtro solo frena los que lo traen. Hoy no comenta ningún bot en los repos de CX; si empieza a hacerlo, sus
  comentarios abren agentes (acotados por el tope de 2 intentos por PR y día de 0050).
