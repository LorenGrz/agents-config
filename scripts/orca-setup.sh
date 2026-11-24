#!/usr/bin/env bash
# orca-setup.sh: deja Orca como en la otra PC, desde config/orca/ de este repo. Se puede correr más de una vez.
#
#   scripts/orca-setup.sh            tema de Omarchy, skills de Orca, automatización stack-sync y preferencias
#   scripts/orca-setup.sh --export   guarda en config/orca/settings.json las preferencias de esta máquina
#
# 1. Tema: enlaza los hooks de Omarchy (theme-set y font-set), orca-omarchy-settings y las plantillas, genera el
#    plugin local.omarchy-theme con el tema actual y lo instala en Orca.
# 2. Skills de Orca: las de la versión instalada.
# 3. stack-sync (ADR 0045): crea la automatización si no está, con este repo como workspace. Sus repos y su owner
#    salen de ~/.config/stack-sync/config, que no se commitea: sin ese archivo, stack-sync no hace nada.
# 4. Preferencias: scripts/orca-settings.py apply. Con Orca abierto se saltea y lo dice.
# Las cuentas de agentes, el login de GitHub y los repos de cada proyecto se cargan a mano en Orca.
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
O=$REPO/config/orca
ORCA=${ORCA_CLI:-$(command -v orca || echo "$HOME/.config/orca/linux-orca-cli-shim/orca")}

if [ "${1:-}" = --export ]; then exec python3 -I "$REPO/scripts/orca-settings.py" export; fi
[ $# -eq 0 ] || { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }
"$ORCA" status >/dev/null 2>&1 || { echo "Orca no responde: abrilo (orca open) y volvé a correr"; exit 1; }

# enlazar <origen> <destino>: symlink al repo; un archivo distinto que ya estaba queda como .bak
enlazar() {
  mkdir -p "$(dirname "$2")"
  if [ -e "$2" ] && [ ! -L "$2" ] && ! cmp -s "$1" "$2"; then mv "$2" "$2.bak"; echo "  respaldo: $2.bak"; fi
  ln -sfn "$1" "$2"
}

echo "1. Tema de Omarchy"
if [ -d "$HOME/.config/omarchy" ]; then
  enlazar "$O/omarchy/60-orca-theme" "$HOME/.config/omarchy/hooks/theme-set.d/60-orca-theme"
  enlazar "$O/omarchy/60-orca-font" "$HOME/.config/omarchy/hooks/font-set.d/60-orca-font"
  enlazar "$O/omarchy/orca-omarchy-settings" "$HOME/.local/bin/orca-omarchy-settings"
  enlazar "$O/omarchy/orca-theme.json.tpl" "$HOME/.config/omarchy/themed/orca-theme.json.tpl"
  enlazar "$O/omarchy/orca-terminal.json.tpl" "$HOME/.config/omarchy/themed/orca-terminal.json.tpl"
  # Las plantillas se completan con colors.toml en cada theme set: sin un theme set todavía, el plugin no existe.
  [ -f "$HOME/.local/state/omarchy/current/theme/orca-theme.json" ] || { command -v omarchy-theme-set >/dev/null &&
    omarchy-theme-set "$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null || echo default)" >/dev/null 2>&1 || true; }
  "$O/omarchy/60-orca-theme" || true
  if [ -f "$HOME/.local/share/orca-omarchy-theme/orca-plugin.json" ]; then
    "$ORCA" plugin install "$HOME/.local/share/orca-omarchy-theme" >/dev/null && echo "  plugin local.omarchy-theme instalado"
  else
    echo "  todavía no hay tema generado: corré omarchy-theme-set <tema> y volvé a correr"
  fi
else
  echo "  sin Omarchy: se saltea"
fi

echo "2. Skills de Orca"
"$ORCA" skills update >/dev/null 2>&1 || "$ORCA" skills install >/dev/null 2>&1 || echo "  no pude actualizarlas: orca skills update"

echo "3. Automatización stack-sync"
if "$ORCA" automations list 2>/dev/null | grep -q ' stack-sync '; then
  echo "  ya existe (orca automations show <id> para ver su workspace)"
else
  "$ORCA" repo list 2>/dev/null | grep -q " $REPO\$" || "$ORCA" repo add "$REPO" >/dev/null
  "$ORCA" automations create --name stack-sync --provider claude --trigger '*/2 9-17 * * 1-5' \
    --workspace "path:$REPO" --workspace-mode existing \
    --precheck "$REPO/scripts/stack-sync.sh --precheck" --precheck-timeout 300 \
    --prompt 'No hagas nada y terminá: stack-sync corre entero en el precheck y abre sus propios agentes (ADR 0045 de agents-config). El precheck siempre sale con 1, así que esta sesión no debería arrancar nunca.' \
    >/dev/null && echo "  creada"
fi
[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/stack-sync/config" ] ||
  echo "  falta ~/.config/stack-sync/config (STACK_SYNC_OWNER y STACK_SYNC_ROOTS): sin él no sincroniza nada"

echo "4. Preferencias"
python3 -I "$REPO/scripts/orca-settings.py" apply || echo "  aplicalas con Orca cerrado: scripts/orca-settings.py apply"
