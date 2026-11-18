# 0024 — Opus con esfuerzo alto; imágenes en la terminal dentro de tmux

Estado: aceptado (2026-11-10). Reemplaza el esfuerzo medio de
[0018](0018-opus-medium-default-reasoner-high.md) (`model: opus` y `reasoner` en alto siguen).

## Contexto

La base decía esfuerzo medio y cada `install.sh` bajaba el `high` que usa el dueño. Dentro de tmux (caolg)
Claude Code no detecta el kitty graphics protocol y las imágenes pegadas salen como `Image #N` sin miniatura
(`paste-preview`), con `allow-passthrough on` en tmux; CAO hace unset de las variables `CLAUDE*` de la shell.

## Decisión

- `config/settings.base.json`: `effortLevel` y `modelSettings.claude-opus-5-5.effortLevel` = `"high"`.
- `config/settings.base.json` `env`: `"CLAUDE_CODE_FORCE_TERMINAL_IMAGES": "1"` (el `env` de los settings lo
  aplica Claude Code mismo, después del unset de CAO). Probado a mano en tmux dentro de Ghostty: se ven las
  miniaturas.

## Consecuencias

- Más costo y latencia por turno en la sesión principal que en medio.
- Las imágenes se fuerzan en toda terminal, no solo en tmux. Una terminal sin kitty graphics protocol (por
  ejemplo la de VS Code) imprimiría basura: si pasa, se saca la variable y se define por lanzamiento.
