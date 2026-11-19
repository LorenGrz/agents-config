# 0043 — Los conflictos de PR los resuelve una automatización de Orca

Estado: aceptado (2026-11-19). Ajusta 0032 en cómo se lanza el agente. Ajustado por 0044 (sin timer: la automatización sincroniza y el agente pushea).

## Contexto

Hasta ahora `stack-sync`, ante un conflicto, abría un agente suelto con `orca agent launch`. Loren pidió usar las
automatizaciones de Orca: un prompt programado que un agente corre en un workspace registrado, con un precheck
(un comando de shell: si sale con 0 la corrida sigue, si no se saltea y queda en el historial). La carpeta de CX ya
es un workspace de Orca y contiene todos los worktrees de los PR, y Orca lanza Claude sin pedir permisos.

## Decisión

- `stack-sync.sh` ya no lanza agentes: un conflicto deja su brief en `~/.local/state/stack-sync/queue/<repo>-<pr>.md`,
  una vez por (PR, commit base). `stack-sync.sh --pending` sale con 0 si la cola tiene algo y con 1 si no, sin
  tocar nada ni usar la red.
- La automatización de Orca «stack-sync: conflictos de PR» corre cada 5 minutos en el workspace de la carpeta de
  CX, con `--pending` como precheck. Su Claude procesa la cola de a un brief: resuelve en ese worktree, corre los
  checks, commitea el merge, deja la marca de 0042 y borra el brief (o lo mueve a `failed/` con el motivo).
- El agente no pushea, por la guarda de la org; el timer de 0032 pushea la resolución en su corrida siguiente.
- Los merges sin conflicto y los push siguen en el timer de systemd, que anda aunque Orca esté cerrado.

Se instala con (el workspace es la carpeta que contiene los worktrees):

```
orca automations create --name "stack-sync: conflictos de PR" --trigger "*/5 * * * *" \
  --timezone America/Argentina/Buenos_Aires --provider claude --workspace "path:<carpeta>" --fresh-session \
  --precheck "<hub>/scripts/stack-sync.sh --pending" --precheck-timeout 30 \
  --prompt "Procesá la cola de conflictos de stack-sync (ADR 0043 de agents-config). Esto es un brief: ejecutalo sin la pregunta de carril ni la de Continuar/Orquestar. Por cada archivo .md de ~/.local/state/stack-sync/queue/, de a uno, leelo y seguí sus instrucciones al pie de la letra: resolver en ese worktree, checks, commit, marca, y borrar o mover el archivo. Nunca pushees ni edites PRs: stack-sync pushea solo. Si la cola está vacía, terminá sin hacer nada."
```

## Consecuencias

- Las corridas quedan en el historial de Orca (`orca automations runs --id <id>`), y una cola vacía no arranca
  ningún agente.
- Entre el conflicto y el push pasan hasta 35 minutos: 15 del timer, 5 de la automatización, la resolución y
  otros 15 del timer.
- Si Orca está cerrado, los conflictos esperan en la cola; los merges sin conflicto siguen.
