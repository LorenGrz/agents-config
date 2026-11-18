# 0021 — Los archivos de cache de la statusline son una interfaz para caolg

Estado: reemplazado por ADR 0028 (2026-11-16): la statusline ya no escribe estos caches.

## Contexto

`config/hooks/statusline.sh`, además de dibujar, escribe dos caches que lee caolg (otro repo): la barra de
cuota (`bin/cao-usage`, `lib/caolg_lib.py`) y el borde de cada agente con su contexto y su carpeta
(`bin/caolg-watch`). Nada lo decía, y cambiar la statusline degradaba la barra y los bordes sin error.

## Decisión

- Los dos archivos son un contrato. `statusline.sh` lo documenta en su cabecera; este ADR es la referencia.

| Archivo | Se escribe cuando | Campos |
|---|---|---|
| `${XDG_CACHE_HOME:-~/.cache}/claude/rate-limits.json` | el input tiene `rate_limits.five_hour` o `.seven_day` | `ts` (epoch, float), `rate_limits` (el objeto del input tal cual: `five_hour` y `seven_day`, cada uno con `used_percentage` y `resets_at`) |
| `${XDG_CACHE_HOME:-~/.cache}/claude/ctx/<CAO_TERMINAL_ID>.json` | `CAO_TERMINAL_ID` está definido y se conoce `used_percentage` | `ts` (epoch, entero), `used_percentage`, `size` (ventana de contexto), `cwd` (`workspace.current_dir`, si no `cwd`; sigue el `cd` del agente) |

- Los dos se escriben de forma atómica (`.tmp` y después `mv`) y nunca contienen tokens ni credenciales.
- Se pueden agregar campos. Renombrar o sacar uno rompe: se actualiza caolg en el mismo cambio y se dice en el
  commit.
- Los rate limits son de la cuenta, no de la sesión: gana el último que escribe.
- caolg sigue andando sin los archivos, con un fallback (transcripts, rollouts de Codex, `gh`), solo que menos
  exacto.

## Consecuencias

- Ninguna vigente: ADR 0028 sacó las dos escrituras.
