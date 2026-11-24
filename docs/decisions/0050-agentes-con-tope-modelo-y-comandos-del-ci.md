# 0050 — Agentes con tope, uno por worktree, modelo según el intento, y los comandos del CI

Estado: aceptado (2026-11-20). Ajusta 0045, 0047, 0048 y 0049.
Ajustado por [0052](0052-flujo-de-matt-sin-superpowers.md): la revisión por PR es un par Standards y Spec, no un reviewer solo.

## Contexto

Un agente de stack-sync que pushea y vuelve a romper el CI abría otro sin fin. Dos agentes podían caer en el mismo
worktree. Todo corría en Opus. Y los checks locales no eran los del CI (`pnpm` contra `npm ci`): daban errores que
el CI no ve.

## Decisión

- stack-sync abre un agente por worktree a la vez: una marca de ocupado que el agente borra al terminar y que vence
  a los 60 minutos. Mientras está, el PR se saltea entero.
- Como mucho 2 intentos automáticos por PR y por día. Después se avisa una vez y queda para Loren.
- Conflictos y CI en rojo: primer intento con Sonnet, segundo con Opus en high. Reviews: siempre Opus en high. Los
  líderes, siempre Opus (corregido el mismo día: Loren pidió Sonnet solo para los conflictos).
- Un reviewer por PR (back y front de un mismo PR, uno solo).
- Instalar y correr los checks siempre con los comandos del CI del repo (`.github/workflows`), nunca con un gestor
  de paquetes fijo.

## Consecuencias

- Un PR que falla dos veces en el día espera a Loren.
- Si el CI cambia de gestor (por ejemplo, a `pnpm`), nada de esto cambia.
