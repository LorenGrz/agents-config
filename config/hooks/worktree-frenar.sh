#!/usr/bin/env bash
# worktree-frenar.sh: frena lo que corre dentro de un worktree antes de borrarlo (ADR 0065).
# Un dev server vivo (next dev) vuelve a escribir archivos mientras se borra la carpeta, y el worktree queda a
# medias: fuera de git pero con la carpeta en disco (pasó el 2026-11-25).
#
#   worktree-frenar.sh [<ruta>]            frena con TERM y después KILL; sale 1 si algo no se deja frenar
#   worktree-frenar.sh --listar [<ruta>]   solo lista los procesos; sale 1 si hay alguno
#
# La ruta sale de $ORCA_WORKTREE_PATH (hook `archive` de Orca, que no borra si el hook falla), del argumento o
# del directorio actual. Frena los procesos cuyo directorio de trabajo está adentro, salvo este script y sus
# padres. Nunca corre sobre el worktree principal; fuera de git no hace nada.
set -uo pipefail

listar=0
[ "${1:-}" = --listar ] && { listar=1; shift; }
dir=$(cd "${ORCA_WORKTREE_PATH:-${1:-$PWD}}" 2>/dev/null && pwd -P) || { echo "worktree-frenar: no existe la ruta" >&2; exit 1; }
gitdir=$(git -C "$dir" rev-parse --absolute-git-dir 2>/dev/null) || exit 0
if [ "$gitdir" = "$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir)" ]; then
  echo "worktree-frenar: $dir es el worktree principal, no lo toco" >&2
  exit 1
fi
cd /  # desde afuera: así los subprocesos de este script no cuentan como algo que corre adentro

protegidos=" $$ "
p=$$
while [ "${p:-0}" -gt 1 ]; do
  p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
  protegidos+="$p "
done

adentro() {
  local pid cwd
  if [ -d /proc/self ]; then
    for pid in /proc/[0-9]*; do
      cwd=$(readlink "$pid/cwd" 2>/dev/null) || continue
      pid=${pid#/proc/}
      case "$cwd" in "$dir" | "$dir"/*) [[ $protegidos == *" $pid "* ]] || echo "$pid" ;; esac
    done
  else  # macOS: sin /proc
    lsof -a -d cwd -Fpn 2>/dev/null | awk -v d="$dir" '
      /^p/ { pid = substr($0, 2) }
      /^n/ { n = substr($0, 2); if (n == d || index(n, d "/") == 1) print pid }' |
      while read -r pid; do [[ $protegidos == *" $pid "* ]] || echo "$pid"; done
  fi
}
mostrar() { for pid in $1; do echo "  $pid $(ps -o args= -p "$pid" 2>/dev/null | cut -c1-100)"; done; }

pids=$(adentro)
[ -z "$pids" ] && exit 0
if [ $listar -eq 1 ]; then
  echo "worktree-frenar: corre algo en $dir:"; mostrar "$pids"; exit 1
fi
echo "worktree-frenar: frenando lo que corre en $dir:"; mostrar "$pids"
kill -TERM $pids 2>/dev/null
for _ in 1 2 3 4 5 6 7 8 9 10; do
  sleep 0.5
  pids=$(adentro)
  [ -z "$pids" ] && exit 0
done
# Lo que ignoró TERM. Se repite por los hijos que quedan huérfanos un instante.
for _ in 1 2 3 4 5; do
  kill -KILL $pids 2>/dev/null
  sleep 0.5
  pids=$(adentro)
  [ -z "$pids" ] && exit 0
done
echo "worktree-frenar: no se pudieron frenar: $pids" >&2
exit 1
