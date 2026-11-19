#!/usr/bin/env bash
# stack-sync-install.sh - opt-in: runs scripts/stack-sync.sh every 15 minutes as a systemd user timer
# (ADR 0032). Units are generated with this hub's path, so nothing personal is committed.
#   stack-sync-install.sh            install and start the timer
#   stack-sync-install.sh --remove   stop it and delete the units
set -euo pipefail
HUB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
command -v systemctl >/dev/null || { echo "stack-sync-install: no hay systemctl" >&2; exit 1; }

if [ "${1:-}" = "--remove" ]; then
  systemctl --user disable --now stack-sync.timer 2>/dev/null || true
  rm -f "$UNIT_DIR/stack-sync.service" "$UNIT_DIR/stack-sync.timer"
  systemctl --user daemon-reload
  echo "stack-sync: timer borrado"; exit 0
fi

mkdir -p "$UNIT_DIR"
cat >"$UNIT_DIR/stack-sync.service" <<EOF
[Unit]
Description=stack-sync: trae la base a las ramas de mis PRs, resuelve conflictos y pushea (agents-config, ADR 0032, 0041, 0042)

[Service]
Type=oneshot
Environment=PATH=$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=$HUB/scripts/stack-sync.sh
EOF
cat >"$UNIT_DIR/stack-sync.timer" <<'EOF'
[Unit]
Description=stack-sync cada 15 minutos

[Timer]
OnBootSec=2min
OnUnitActiveSec=15min
Persistent=true

[Install]
WantedBy=timers.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now stack-sync.timer
echo "stack-sync: timer activo (systemctl --user list-timers stack-sync.timer; log en ~/.local/state/stack-sync/stack-sync.log)"
