# 0059 — stack-sync commitea y pushea el conflicto que resuelve el agente

Estado: aceptado (2026-11-24). Ajusta 0044 (el agente de conflictos ya no commitea ni pushea).

## Contexto

Los repos de una org de trabajo versionan en `.claude/settings.json` reglas `ask` para
`git commit *` y `git push *`. El agente de conflictos de stack-sync corre en `bypassPermissions`, pero según la doc
de Claude Code una regla `ask` pide confirmación igual: no la pisan ese modo, ni un `allow` del usuario o de
`settings.local.json`, ni un hook PreToolUse que devuelva `allow`. Cada conflicto frenaba esperando a Loren. La
regla es del equipo y Loren no quiere cambiarla en los repos: el cambio va solo de su lado.

## Decisión

- El agente resuelve, hace `git add`, confirma que no queda ningún archivo sin resolver y deja la marca
  `~/.local/state/stack-sync/resolved-<repo>-<pr>`. No commitea ni pushea.
- La corrida siguiente de `stack-sync.sh`, que corre fuera de Claude, ve la marca y, si hay un merge en curso sin
  archivos sin resolver, hace `git commit --no-edit` y `git push origin HEAD:<rama>` (sin force). La marca se borra
  siempre; si algo falla, se avisa una vez y el worktree queda para Loren.
- El `--precheck` sincroniza cuando hay una marca de resuelto, aunque GitHub no tenga novedades: el push no espera
  al piso de 30 minutos.
- Los agentes de review y de CI rojo no cambian: siguen commiteando y pusheando ellos.

## Consecuencias

- Entre la resolución y el push pasan hasta 2 minutos (el intervalo de la automatización).
- Los hooks de git del repo (pre-commit, pre-push) corren en el commit y el push del script, como antes en los del
  agente.
- El push del script se apoya en el OK permanente de Loren para pushear sus propias ramas, como los merges sin
  conflicto de 0032 y 0044.
- Si se descartara `--setting-sources user,local` para lanzar a los agentes: Orca no deja pasar flags a Claude, y
  saltear el settings del repo también saca sus hooks (la guarda de la librería del front).
