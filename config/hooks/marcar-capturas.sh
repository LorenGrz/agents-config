#!/usr/bin/env bash
# PostToolUse (Bash): después de un `node pr-screenshots.mjs` (capturas antes/después de un PR), marca
# cada par de la carpeta de salida con `marcar-cambios.sh`: recorte y recuadro rojo donde cambió, más
# la pantalla entera marcada; un par igual queda «sin cambios» y no va al PR. Le dice a la sesión qué
# archivos subir. Nunca bloquea ni hace fallar la herramienta.
#
# El marcador sale de $MARCAR_CAPTURAS o de la primera skill instalada que lo traiga
# (~/.claude/skills/*/scripts/marcar-cambios.sh); sin marcador, el hook no hace nada.
# La carpeta es el --out del comando (por defecto pr-screenshots/), relativa al último `cd` del
# comando o, sin `cd`, al cwd de la sesión. Callado con --login y en subagentes.
set -uo pipefail

payload="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$payload" 2>/dev/null)"
[[ "$cmd" == *pr-screenshots.mjs* && "$cmd" != *--login* ]] || { echo '{}'; exit 0; }
[ -z "$(jq -r '.agent_type // empty' <<<"$payload")" ] || { echo '{}'; exit 0; }

marcador="${MARCAR_CAPTURAS:-}"
if [ -z "$marcador" ]; then
  for m in "$HOME"/.claude/skills/*/scripts/marcar-cambios.sh; do [ -x "$m" ] && { marcador=$m; break; }; done
fi
[ -n "$marcador" ] && [ -x "$marcador" ] || { echo '{}'; exit 0; }

cwd="$(jq -r '.cwd // empty' <<<"$payload")"
dir="$(python3 - "$cmd" "${cwd:-$PWD}" <<'PY'
import os, re, shlex, sys
cmd, cwd = sys.argv[1], sys.argv[2]
try:
    toks = shlex.split(cmd, posix=True)
except ValueError:
    toks = cmd.split()
base, out = cwd, None
for i, t in enumerate(toks):
    if t == 'cd' and i + 1 < len(toks):
        base = os.path.join(base, os.path.expanduser(toks[i + 1]))
    if t.startswith('pr-screenshots.mjs') or t.endswith('/pr-screenshots.mjs'):
        break
for i, t in enumerate(toks):
    if t == '--out' and i + 1 < len(toks):
        out = toks[i + 1]
    elif t.startswith('--out='):
        out = t[6:]
out = os.path.expanduser(os.path.expandvars(out or 'pr-screenshots'))
print(os.path.normpath(os.path.join(base, out)))
PY
)"
[ -d "$dir" ] || { echo '{}'; exit 0; }

subir=() iguales=() fallas=()
shopt -s nullglob
for before in "$dir"/before-*.png; do
  case "$before" in *.marcado.png|*.completa.png) continue;; esac
  after="$dir/after-${before##*/before-}"
  [ -f "$after" ] || continue
  slug="${before##*/before-}"; slug="${slug%.png}"
  if ! res="$("$marcador" "$before" "$after" 2>&1)"; then fallas+=("$slug"); continue; fi
  if [ "$res" = sin-cambios ]; then iguales+=("$slug"); continue; fi
  for f in "${before%.png}".{marcado,completa}.png "${after%.png}".{marcado,completa}.png; do [ -f "$f" ] && subir+=("$f"); done
done
[ ${#subir[@]} -gt 0 ] || [ ${#iguales[@]} -gt 0 ] || [ ${#fallas[@]} -gt 0 ] || { echo '{}'; exit 0; }

msg="Hook marcar-capturas: marqué los pares de $dir (recorte con recuadro y pantalla entera)."
[ ${#subir[@]} -gt 0 ] && msg+=" Subí al PR solo estos archivos, no los PNG crudos: ${subir[*]}. El .marcado.png va en la tabla Antes/Después y el .completa.png en un desplegable <details><summary>Ver pantalla completa</summary> debajo."
[ ${#iguales[@]} -gt 0 ] && msg+=" Sin cambios, no van al PR: ${iguales[*]}. Si un paso del escenario falló, iguales no significa sin cambios: revisalo."
[ ${#fallas[@]} -gt 0 ] && msg+=" No se pudieron marcar: ${fallas[*]}."
jq -n --arg m "$msg" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $m}}'
exit 0
