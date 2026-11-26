# 0039 — «Orquestar»: un líder por rama, en su propia sesión, con un procedimiento fijo

Estado: aceptado (2026-11-19). Ajusta 0036 en cómo se lanza el líder y 0022 en las preguntas de carril. Ajustado por 0064 (cierre de los líderes y orden de lo que depende).

## Contexto

El 2026-11-19, con tres tickets de CX en cuatro ramas (dos repos), la sesión principal armó un Plan S y los
resolvió en serie. Después lanzó subagentes dentro de su propia sesión. Loren pidió que pase otra cosa
siempre que haya varios tickets, o un ticket con back y front: que se proponga orquestar, y que cada rama
la tome un líder Opus en su propia sesión, con el contexto justo, en paralelo, y que pueda lanzar workers.
También pidió que eso no dependa de la memoria del agente, sino que esté fijado en un hook.

Al lanzar el primer líder en Orca, la sesión frenó en «Allow external CLAUDE.md file imports?». El
`CLAUDE.md` de la carpeta del workspace importa archivos que quedan fuera del worktree, y
`--dangerously-skip-permissions` no saltea ese aviso. Claude Code no documenta ninguna forma de
pre-aprobarlo (consultado 2026-11-19).

## Decisión

- Con más de una rama de tarea, después de la pregunta de carril va una segunda: **Continuar · Orquestar**,
  en ese orden. Orquestar es la recomendada. `lane-guard.sh` acepta esa pregunta y deja Continuar primero.
- Elegir Orquestar dispara `config/hooks/orquestar.sh` (PostToolUse de `AskUserQuestion`), que inyecta el
  procedimiento fijo. La sesión principal coordina: tickets, contrato, ramas y worktrees. Hay un líder por
  worktree, como sesión aparte (Orca `worker-start`, T3 Code `t3_thread_launch`) y nunca como subagente.
  Los independientes van en paralelo, y lo que depende de un contrato arranca cuando el contrato está
  commiteado. Cada líder recibe un brief con su entrega, commitea con su reviewer y no hace push, PR ni
  Jira. La sesión principal termina el turno sin pollear.
- Antes de lanzar cada líder, `scripts/approve-claude-imports.sh <worktree>` marca en `~/.claude.json` la
  aprobación de los imports. Lo marca en el worktree y en la raíz del checkout principal, porque medido en
  la 2.1.327 Claude Code lee la aprobación de un worktree desde ahí: marcar solo el worktree no alcanzó.
  Loren lo autorizó para todo worktree nuevo, no solo los de una organización.

## Consecuencias

- La clave de `~/.claude.json` es interna y no está documentada: una versión nueva de Claude Code puede
  moverla, y el síntoma sería que el líder vuelva a frenar en el aviso. Si pasa, hay que volver a medir y
  ajustar el script.
- Aprobar los imports de cualquier worktree saca una barrera pensada para repos de terceros: el script
  solo se corre sobre worktrees que crea la sesión coordinadora.
- Orquestar cuesta más que Continuar, porque cada líder es una sesión Opus. A cambio, cada rama se trabaja
  con su contexto y en paralelo.
