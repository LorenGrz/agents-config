# 0023 — PonyTail, solo en Plan S

Estado: aceptado (2026-11-09). Completa ADR 0022 (Plan S) y cierra la prueba de PonyTail que dejó abierta ADR
0020.

## Contexto

PonyTail (`DietrichGebert/ponytail`, 5.3.3, MIT) empuja al cambio completo más chico; sus ahorros son
autodeclarados. Leído el código: tres hooks de Node (SessionStart, SubagentStart, UserPromptSubmit), modo
`full` por defecto, una band de UI que guarda un CSV por turno y red solo por un webhook opcional vacío.

## Decisión

- **Instalado y habilitado globalmente**, pero **apagado por defecto**: `settings.base.json` lo habilita y
  fija `env.PONYTAIL_DEFAULT_MODE = "off"` y `pluginConfigs["ponytail@ponytail"].options.ledger = false` (la
  band no escribe su fila CSV por turno en `~/.config/ponytail/band/`).
- **Plan S lo carga explícitamente**: en `config/CLAUDE.md`, Plan S corre inline con la skill
  `ponytail:ponytail` cargada al empezar la ejecución. Fuera de Plan S no se invoca ninguna skill `ponytail*`
  salvo pedido, digan lo que digan sus descripciones ("use on any coding task").
- **`install.sh`** fusiona `env` y `pluginConfigs` igual que `enabledPlugins` (la base gana en sus claves, las
  del usuario sobreviven; las opciones de plugin con merge profundo). También crea `~/.claude/.ponytail-band`
  con `off` (oculta la band) una vez, sin pisar nunca la elección del usuario.

## Consecuencias

- Toda sesión paga ~641 tokens por la lista de skills, las de Plan S ~1.1k más cuando carga la skill, y las
  demás nada más: con modo `off` los hooks no suman contexto.
- Escribir `/ponytail` lo prende por el resto de la sesión; "stop ponytail" lo apaga.
- Corre código de terceros en cada inicio de sesión y en cada prompt. Actualizar el plugin trae código nuevo:
  se revisa el diff antes de `claude plugin marketplace update ponytail`.
- Un plugin instalado a mitad de sesión recién está disponible en la sesión siguiente.
