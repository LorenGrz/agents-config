# 0038 — `install.sh` conserva los hooks y el tema de otras herramientas

Estado: aceptado (2026-11-18).

## Contexto

`install.sh` mergeaba `config/settings.base.json` en `~/.claude/settings.json` con la base ganando en `hooks`
y `theme`. Orca agrega sus propias entradas de hooks (16, en eventos como `PreToolUse`, `SessionStart`,
`Elicitation` o `SessionEnd`, todas con `~/.orca/agent-hooks/claude-hook.sh`) y pone `"theme": "custom:orca"`.
Cada instalación real las borraba y volvía el tema a `dark`; había que restaurarlas a mano desde el backup.

## Decisión

- Un comando de hook es del hub cuando corre un script de la carpeta de hooks instalada: tiene
  `~/.claude/hooks/<nombre>` (o `$HOME/`, `${HOME}/`) al principio o después de un espacio, como los escribe
  la base.
- Los comandos del hub que ya estaban se descartan y se ponen las entradas de la base, así un hook que la
  base quitó o cambió no queda colgado. Los demás se conservan después de las entradas de la base en su
  evento, en su orden. Una entrada que mezclaba comandos del hub y ajenos conserva solo los ajenos; un evento
  queda mientras le quede alguna entrada.
- `theme` de la base es solo un valor por defecto: se usa cuando el archivo no tiene uno.
- `scripts/test-install-settings.sh` cubre los casos, incluida la idempotencia.

## Consecuencias

- Orca y otras herramientas sobreviven a una reinstalación sin restaurar nada del backup.
- Un hook propio escrito con ruta absoluta (`/home/<usuario>/.claude/hooks/...`) o entre comillas no cuenta
  como del hub y se conserva; la base nunca lo escribe así.
- Una entrada mal formada no rompe el merge: se conserva tal cual.
- Para volver al tema de la base hay que borrar `theme` de `~/.claude/settings.json` y reinstalar.
