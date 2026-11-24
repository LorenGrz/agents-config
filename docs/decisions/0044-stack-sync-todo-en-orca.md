# 0044 — stack-sync corre entero en la automatización de Orca, y el agente pushea

Estado: aceptado (2026-11-19). Ajustado por 0045 (precheck por cambios, un Claude por worktree, limpieza de lo mergeado) y por 0060 (los agentes commitean y pushean con `stack-sync-git.sh`). Reemplaza 0042 y la parte de 0043 que dejaba el push y los merges en el timer;
lo demás de 0043 (la cola, un brief por conflicto) sigue.

## Contexto

Con 0043 había dos piezas: un timer de systemd cada 15 minutos (merges sin conflicto, push, retarget y el push
de la resolución del agente por marca) y la automatización de Orca cada 5 minutos para resolver los conflictos.
Entre un conflicto y su push pasaban hasta 35 minutos. El agente no pusheaba porque la guarda de la org le iba
a pedir confirmación, pero en esta máquina esa guarda no está instalada como plugin y Orca lanza Claude sin
pedir permisos. Loren pidió sacar el timer y que la automatización pushee directo cuando resuelve un conflicto.

## Decisión

- Se borran el timer de systemd y `scripts/stack-sync-install.sh`.
- La automatización «stack-sync: conflictos de PR» corre cada 10 minutos con precheck
  `stack-sync.sh --sync-pending` (timeout 300 s): hace la sincronización completa (merges sin conflicto con push,
  retarget de los apilados cuya base se mergeó, conflictos a la cola) y sale con 0 solo si quedó algo en la cola.
  Sin configuración o con otra corrida en curso sale con 1, para no lanzar un agente de más.
- El agente resuelve cada brief, corre los checks, commitea el merge y pushea a la rama del PR, sin force. No
  edita el PR: si su base cambió, la corrida siguiente lo retargetea.
- Se borran las marcas `resolved-*` y el paso del script que pusheaba por marca.

Se configura con:

```
orca automations edit --id <id> --trigger "*/10 * * * *" --precheck "<hub>/scripts/stack-sync.sh --sync-pending" \
  --precheck-timeout 300 --prompt "<el de 0043, con push sin force a la rama del PR en lugar de la marca>"
```

## Consecuencias

- Todo corre solo con Orca abierto: con Orca cerrado no se traen bases ni se retargetea. Al abrirlo, la
  automatización corre una vez dentro de su ventana de gracia.
- Entre un conflicto y su push pasan hasta 10 minutos más lo que tarde el agente.
- Una sincronización sin novedades tarda unos segundos y no lanza ningún agente.
