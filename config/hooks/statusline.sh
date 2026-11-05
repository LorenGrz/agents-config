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

# Linea 1: modelo | costo | contexto
linea1() {
  local largo=$1 m
  reset_buf
  m="$modelo"
  if [[ -n "$esfuerzo" ]]; then
    if ((largo)); then m="$modelo ($esfuerzo)"; else m="$modelo ${esfuerzo:0:3}"; fi
  fi
  put "$m"; sep
  put "\$${costo_f}" "${cc}\$${costo_f}${Z}"
  ((largo)) && put " sesion"
  sep
  put "ctx "
  if [[ -n "$ctx_col" ]]; then put "$ctx_txt" "${ctx_col}${ctx_txt}${Z}"; else put "$ctx_txt"; fi
  ((largo)) && put "$tam_f"
}

# Un bloque de uso: "5h 12% reset 2h13m"
bloque_uso() {
  local etiqueta=$1 u=$2 r=$3 largo=$4 n t
  put "$etiqueta "
  if [[ -n "$u" ]]; then
    n=$(redondear "$u")
    put "${n}%" "$(color_pct "$n")${n}%${Z}"
  else
    put "--"
  fi
  t=$(resta "$r")
  if ((largo)); then put " reset ${t}"; else put " ${t}"; fi
}

# Linea de uso: 5h | 7d
linea_uso() {
  local largo=$1
  reset_buf
  bloque_uso "5h" "$u5" "$r5" "$largo"; sep
  bloque_uso "7d" "$u7" "$r7" "$largo"
}

hay_uso=0
[[ -n "$u5" || -n "$u7" ]] && hay_uso=1

imprimir() {
  local plano=$P color=$C
  if ((${#plano} > max)); then
    plano="${plano:0:max}"; color="$plano"
  fi
  printf '%*s%s\n' "$((max - ${#plano}))" "" "$color"
}

# Todo en una linea (largo)
linea1 1; l1_p=$P; l1_c=$C
todo_p=$l1_p; todo_c=$l1_c
if ((hay_uso)); then
  linea_uso 1; u_p=$P; u_c=$C
  todo_p="${l1_p} | ${u_p}"
  todo_c="${l1_c}${D} | ${Z}${u_c}"
fi

if ((${#todo_p} <= max)); then
  P=$todo_p; C=$todo_c; imprimir
else
  # Dos lineas; cada una cae a forma corta si no entra
  linea1 1
  if ((${#P} > max)); then linea1 0; fi
  imprimir
  if ((hay_uso)); then
    linea_uso 1
    if ((${#P} > max)); then linea_uso 0; fi
    imprimir
  fi
fi
