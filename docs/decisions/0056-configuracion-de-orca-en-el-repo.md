# 0056 — La configuración de Orca vive en el repo, sin secretos

Estado: aceptado (2026-11-24).

## Contexto

La configuración de Orca estaba solo en esta máquina: las preferencias en `profile-state.db`, el tema de Omarchy
para Orca (dos hooks de Omarchy, un script y dos plantillas) fuera de todo repo, y la automatización `stack-sync`
creada a mano. Al mover una carpeta de trabajo, la automatización quedó huérfana y nadie lo vio. Para poner lo
mismo en otra PC había que rehacer todo de memoria.

## Decisión

- `config/orca/settings.json` guarda las preferencias de Orca que se pueden publicar, exportadas con una lista de
  claves permitidas (`scripts/orca-settings.py`). Quedan afuera las cuentas de agentes, cookies, rutas de esta
  máquina, telemetría, nombre de la máquina, proxy y semillas de atajos. `workspaceDir` se guarda relativo al home.
- `config/orca/omarchy/` tiene las piezas del tema; `scripts/orca-setup.sh` las enlaza, genera e instala el plugin,
  actualiza las skills de Orca, crea `stack-sync` con este repo como workspace y aplica las preferencias.
- Las preferencias se escriben solo con Orca cerrado, como `orca-omarchy-settings`: abierto, Orca pisa la base.
- `stack-sync` corre sobre este repo y no sobre una carpeta de trabajo: existe en cualquier PC.

## Consecuencias

- En una PC nueva: clonar el repo, abrir Orca una vez, `scripts/orca-setup.sh`, y cargar a mano las cuentas,
  el login de GitHub, los repos de cada proyecto y `~/.config/stack-sync/config`.
- Un cambio de preferencias en Orca no llega al repo solo: `scripts/orca-settings.py export` y commit.
