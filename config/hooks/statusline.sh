#!/usr/bin/env bash
# Statusline minimalista, solo ASCII: modelo, esfuerzo, costo de sesion,
# contexto y uso 5h/7d con tiempo al reset. Colores por umbral, responsiva a $COLUMNS
# y alineada a la derecha. NO_COLOR desactiva los colores.
set -uo pipefail

# --- Umbrales (ajustables) ---
PCT_WARN=50    # amarillo desde aca (contexto y uso)
PCT_CRIT=80    # rojo desde aca
COST_WARN=1    # USD de la sesion: amarillo desde aca
COST_CRIT=5    # rojo desde aca

if [[ -n "${NO_COLOR:-}" ]]; then
  G=""; Y=""; R=""; D=""; Z=""
else
  G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; D=$'\e[2m'; Z=$'\e[0m'
fi

entrada=$(cat)

IFS='|' read -r modelo esfuerzo costo pct tam u5 r5 u7 r7 < <(
  printf '%s' "$entrada" | jq -r '[
    (.model.display_name // "?"),
    (.effort.level // ""),
    (.cost.total_cost_usd // 0 | tostring),
    (.context_window.used_percentage // "" | tostring),
    (.context_window.context_window_size // "" | tostring),
    (.rate_limits.five_hour.used_percentage // "" | tostring),
    (.rate_limits.five_hour.resets_at // "" | tostring),
    (.rate_limits.seven_day.used_percentage // "" | tostring),
    (.rate_limits.seven_day.resets_at // "" | tostring)
  ] | join("|")' 2>/dev/null
) || exit 0

# Copia de los límites 5h/7d para otras herramientas (p. ej. la barra de caolg): son de la cuenta, no
# de la sesión, así que vale la última que llegue. Escritura atómica; nunca incluye tokens.
if [[ -n "$u5$u7" ]]; then
  cache="${XDG_CACHE_HOME:-$HOME/.cache}/claude"
  mkdir -p "$cache" 2>/dev/null &&
    printf '%s' "$entrada" | jq -c '{ts: now, rate_limits}' >"$cache/rate-limits.json.tmp" 2>/dev/null &&
    mv -f "$cache/rate-limits.json.tmp" "$cache/rate-limits.json"
fi
# Agentes lanzados por CAO: % de contexto exacto de esta sesión, por terminal (lo lee la barra de caolg).
if [[ -n "${CAO_TERMINAL_ID:-}" && -n "$pct" ]]; then
  ctxd="${XDG_CACHE_HOME:-$HOME/.cache}/claude/ctx"
  mkdir -p "$ctxd" 2>/dev/null &&
    printf '{"ts":%s,"used_percentage":%s,"size":%s}\n' "$(date +%s)" "$pct" "${tam:-null}" \
      >"$ctxd/$CAO_TERMINAL_ID.json.tmp" 2>/dev/null &&
    mv -f "$ctxd/$CAO_TERMINAL_ID.json.tmp" "$ctxd/$CAO_TERMINAL_ID.json"
fi

cols=${COLUMNS:-80}
max=$((cols - 2))
ahora=$(date +%s)

redondear() { printf '%.0f' "$1"; }

# Color segun porcentaje entero
color_pct() {
  local n=$1
  if ((n >= PCT_CRIT)); then printf '%s' "$R"
  elif ((n >= PCT_WARN)); then printf '%s' "$Y"
  else printf '%s' "$G"; fi
}

color_costo() {
  awk -v c="$1" -v w="$COST_WARN" -v k="$COST_CRIT" -v G="$G" -v Y="$Y" -v R="$R" \
    'BEGIN { printf "%s", (c >= k ? R : (c >= w ? Y : G)) }'
}

# Tiempo restante hasta un reset (epoch en s/ms o fecha ISO)
resta() {
  local r=${1%%.*} e d
  [[ -z "$r" ]] && { printf '%s' "--"; return; }
  if [[ "$r" =~ ^[0-9]+$ ]]; then e=$r
  else e=$(date -d "$1" +%s 2>/dev/null) || { printf '%s' "--"; return; }
  fi
  ((e > 1000000000000)) && e=$((e / 1000))
  d=$((e - ahora))
  if ((d <= 0)); then printf '%s' "--"
  elif ((d < 3600)); then printf '%sm' "$((d / 60))"
  elif ((d < 86400)); then printf '%sh%02dm' "$((d / 3600))" "$((d % 3600 / 60))"
  else printf '%sd%sh' "$((d / 86400))" "$((d % 86400 / 3600))"; fi
}

# --- Composicion: P = texto plano (para medir), C = con colores (para imprimir) ---
P=""; C=""
put() { P+="$1"; C+="${2:-$1}"; }
sep() { put " | " "${D} | ${Z}"; }
reset_buf() { P=""; C=""; }

costo_f=$(printf '%.2f' "$costo")
cc=$(color_costo "$costo")

ctx_n=""; ctx_txt="--"
if [[ -n "$pct" ]]; then ctx_n=$(redondear "$pct"); ctx_txt="${ctx_n}%"; fi
ctx_col=""; [[ -n "$ctx_n" ]] && ctx_col=$(color_pct "$ctx_n")

tam_f=""
if [[ -n "$tam" ]]; then
  if ((tam >= 1000000)); then tam_f="/$((tam / 1000000))M"; else tam_f="/$((tam / 1000))k"; fi
fi

# --- Segmentos (cada uno es una unidad que no se parte) ---
SEG_P=(); SEG_C=()
add_seg() { SEG_P+=("$P"); SEG_C+=("$C"); }

reset_buf
m="$modelo"
[[ -n "$esfuerzo" ]] && m="$modelo ($esfuerzo)"
put "$m"; add_seg

reset_buf
put "\$${costo_f}" "${cc}\$${costo_f}${Z}"; put " sesion"; add_seg

reset_buf
put "ctx "
if [[ -n "$ctx_col" ]]; then put "$ctx_txt" "${ctx_col}${ctx_txt}${Z}"; else put "$ctx_txt"; fi
put "$tam_f"; add_seg

# Uso: "5h 12% 2h13m" (porcentaje coloreado + tiempo que falta para el reset)
bloque_uso() {
  local etiqueta=$1 u=$2 r=$3 n t
  reset_buf
  put "$etiqueta "
  if [[ -n "$u" ]]; then
    n=$(redondear "$u")
    put "${n}%" "$(color_pct "$n")${n}%${Z}"
  else
    put "--"
  fi
  t=$(resta "$r")
  put " ${t}"
  add_seg
}
[[ -n "$u5" ]] && bloque_uso "5h" "$u5" "$r5"
[[ -n "$u7" ]] && bloque_uso "7d" "$u7" "$r7"

# --- Empaquetado: los segmentos se acomodan en las lineas que hagan falta ---
imprimir() {
  local plano=$1 color=$2
  if ((${#plano} > max)); then
    plano="${plano:0:max}"; color="$plano"
  fi
  printf '%*s%s\n' "$((max - ${#plano}))" "" "$color"
}

lp=""; lc=""
for i in "${!SEG_P[@]}"; do
  if [[ -z "$lp" ]]; then
    lp="${SEG_P[i]}"; lc="${SEG_C[i]}"
  elif ((${#lp} + 3 + ${#SEG_P[i]} <= max)); then
    lp+=" | ${SEG_P[i]}"; lc+="${D} | ${Z}${SEG_C[i]}"
  else
    imprimir "$lp" "$lc"
    lp="${SEG_P[i]}"; lc="${SEG_C[i]}"
  fi
done
[[ -n "$lp" ]] && imprimir "$lp" "$lc"
