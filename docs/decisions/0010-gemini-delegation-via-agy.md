# 0010 — Delegar trabajo a Gemini con `agy`

Estado: aceptado (2026-10-31). Ajustado por 0037: se usa solo cuando el usuario lo pide.

## Contexto

Antigravity CLI (`agy`) está instalado y ya lee las mismas reglas y skills que Claude Code (ADR 0002). Loren
tenía cuota de Google sin usar mientras los tokens de Anthropic pagaban lectura masiva y escritura mecánica.

## Decisión

- **`meta/gemini-delegate`**: una skill más `scripts/gemini-delegate.sh` con dos modos: `run` (`agy -p`
  headless; la sesión principal espera y revisa el diff) y `open` (`agy -i` interactivo en un split de tmux o
  en la terminal por defecto, lo maneja el usuario).
- **`--dangerously-skip-permissions` en `run`**, elegido por el usuario y protegido por una guarda: el script
  rechaza un worktree sucio (exit 2) salvo con `--allow-dirty`, así el diff es exactamente lo que hizo Gemini.
- `Bash(*gemini-delegate.sh *)` está permitido en `config/settings.base.json`; `agy` a secas sigue
  preguntando.
- Descartado: un subagente, porque su arranque en frío gasta tokens de Anthropic: la sesión principal llama al
  script por Bash.

## Consecuencias

- Gemini no ve la conversación: la spec tiene que estar completa y la sesión principal revisa el diff y corre
  la aceptación. El modelo (`gemini-3.8-flash-high`) puede cambiar: `GEMINI_DELEGATE_MODEL`.
- Depende de que `agy` esté instalado y de la cuota y la disponibilidad de Google.
