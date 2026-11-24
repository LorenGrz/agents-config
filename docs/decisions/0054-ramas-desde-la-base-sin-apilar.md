# 0054 — Toda rama sale de la base, sin apilar

Estado: aceptado (2026-11-24).

## Contexto

En un repo de trabajo se apilaban ramas propias: el PR de un ticket apuntaba a la rama de otro PR abierto. Su CI
corre solo en PR contra `dev`, `qa` o `main`, así que los apilados no tenían CI. El 2026-11-24 un Web Worker que se
importaba a sí mismo colgó `next build` en el PR de abajo; el arreglo entró ahí, pero los dos PR apilados encima
seguían con el build colgado sin que nada lo mostrara, y hubo que llevar el arreglo a mano.

## Decisión

- Toda rama sale de la base del repo (`origin/dev`, o la rama por defecto si no hay `dev`) y su PR apunta a esa base.
- Antes de sacar la rama se revisa si la tarea necesita código de un PR sin mergear. Si lo necesita, se le avisa al
  usuario en vez de apilar: se espera ese merge o se suma la tarea a ese PR.
- Un PR apilado que ya existía se pasa a la base con un push, porque el CI no corre al cambiar la base.
- Va en `config/AGENTS.md` (Git) y en el hook `orquestar.sh`; el repo privado de cada organización lo repite en
  sus políticas y en sus skills de git y de PR.

## Consecuencias

- Cada PR tiene CI, y un arreglo no hay que propagarlo por una pila.
- Un ticket que depende de otro sin mergear espera ese merge o viaja en el mismo PR.
- `stack-sync` (0045, 0050) sigue retargeteando los apilados que queden, hasta que no haya ninguno.
