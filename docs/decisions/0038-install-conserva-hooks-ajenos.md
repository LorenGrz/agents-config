# 0038 — `install.sh` conserva los hooks y el tema de otras herramientas

Estado: aceptado (2026-11-18).

## Contexto

`install.sh` mergeaba `config/settings.base.json` en `~/.claude/settings.json` con la base ganando en `hooks`
y `theme`. Orca agrega sus propias entradas de hooks (16, en eventos como `PreToolUse`, `SessionStart`,
`Elicitation` o `SessionEnd`, todas con `~/.orca/agent-hooks/claude-hook.sh`) y pone `"theme": "custom:orca"`.
Cada instalación real las borraba y volvía el tema a `dark`; había que restaurarlas a mano desde el backup.

## Decisión

- Una entrada de hooks es del hub cuando un comando suyo corre un script de la carpeta de hooks instalada:
  contiene `~/.claude/hooks/<nombre>` (o `$HOME/`, `${HOME}/`) como palabra entera, como los escribe la base.
- Las entradas del hub que ya estaban se descartan y se ponen las de la base, así un hook que la base quitó o
  cambió no queda colgado. Las demás se conservan después de las de la base en su evento, en su orden; un
  evento que solo tiene el archivo existente queda si le queda alguna entrada.
- `theme` de la base es solo un valor por defecto: se usa cuando el archivo no tiene uno.
- `scripts/test-install-settings.sh` cubre los casos, incluida la idempotencia.

## Consecuencias

- Orca y otras herramientas sobreviven a una reinstalación sin restaurar nada del backup.
- Un hook propio escrito con ruta absoluta (`/home/<usuario>/.claude/hooks/...`) no cuenta como del hub y se
  conserva; la base nunca lo escribe así.
- Para volver al tema de la base hay que borrar `theme` de `~/.claude/settings.json` y reinstalar.
