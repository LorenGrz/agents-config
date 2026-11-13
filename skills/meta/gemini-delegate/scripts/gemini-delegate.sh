#!/usr/bin/env bash
# Delegate a task to Gemini through the Antigravity CLI (`agy`).
#   run  — headless (`agy -p`): waits, logs the full output, prints a short summary + git diff --stat
#   open — hand-off: opens an interactive `agy -i` session (tmux split or terminal window)
# The prompt comes from -f <file> or a quoted argument; it is never interpolated into a shell string.
set -euo pipefail

MODEL="${GEMINI_DELEGATE_MODEL:-gemini-3.8-flash-high}"
TIMEOUT="20m"
ALLOW_DIRTY=0
PROMPT_FILE=""

usage() {
  cat >&2 <<'EOF'
Usage:
  gemini-delegate.sh run  [--model M] [--timeout 20m] [--allow-dirty] (-f spec.md | "prompt")
  gemini-delegate.sh open [--model M] (-f spec.md | "prompt")
Env: GEMINI_DELEGATE_MODEL overrides the default model (gemini-3.8-flash-high).
EOF
  exit 64
}

command -v agy >/dev/null || { echo "agy not found in PATH" >&2; exit 127; }

mode="${1:-}"; [ -n "$mode" ] || usage; shift
args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --model) MODEL="${2:?--model needs a value}"; shift 2 ;;
    --timeout) TIMEOUT="${2:?--timeout needs a value}"; shift 2 ;;
    --allow-dirty) ALLOW_DIRTY=1; shift ;;
    -f) PROMPT_FILE="${2:?-f needs a file}"; shift 2 ;;
    -h|--help) usage ;;
    *) args+=("$1"); shift ;;
  esac
done

work_dir="${TMPDIR:-/tmp}/gemini-delegate"
mkdir -p "$work_dir"
stamp="$(date +%Y%m%d-%H%M%S)"
prompt_path="$work_dir/$stamp.prompt.md"

if [ -n "$PROMPT_FILE" ]; then
  [ -r "$PROMPT_FILE" ] || { echo "cannot read $PROMPT_FILE" >&2; exit 66; }
  cp "$PROMPT_FILE" "$prompt_path"
elif [ ${#args[@]} -gt 0 ]; then
  printf '%s\n' "${args[*]}" > "$prompt_path"
else
  usage
fi

case "$mode" in
  run)
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "run needs a git repo (the diff is the safety net for --dangerously-skip-permissions)" >&2
      exit 2
    fi
    if [ "$ALLOW_DIRTY" -eq 0 ] && [ -n "$(git status --porcelain)" ]; then
      echo "worktree is dirty: commit/stash first or pass --allow-dirty (Gemini's edits would mix with yours)" >&2
      exit 2
    fi
    log="$work_dir/$stamp.log"
    rc=0
    agy -p "$(cat "$prompt_path")" --model "$MODEL" --dangerously-skip-permissions \
      --print-timeout "$TIMEOUT" --output-format text >"$log" 2>&1 || rc=$?
    echo "exit code: $rc"
    echo "model:     $MODEL"
    echo "log:       $log"
    echo "--- last 40 lines of the response ---"
    tail -n 40 "$log"
    echo "--- git diff --stat ---"
    git status --short
    git diff --stat
    exit "$rc"
    ;;
  open)
    cmd='agy -i "$(cat "$1")" --model "$2"'
    if [ -n "${TMUX:-}" ]; then
      tmux split-window -h -c "$PWD" "bash -c '$cmd' _ '$prompt_path' '$MODEL'"
    elif command -v xdg-terminal-exec >/dev/null; then
      nohup xdg-terminal-exec bash -c "$cmd" _ "$prompt_path" "$MODEL" >/dev/null 2>&1 &
    elif command -v ghostty >/dev/null; then
      nohup ghostty -e bash -c "$cmd" _ "$prompt_path" "$MODEL" >/dev/null 2>&1 &
    else
      echo "no tmux/xdg-terminal-exec/ghostty found" >&2; exit 127
    fi
    echo "opened agy interactive session (model $MODEL, prompt $prompt_path)"
    ;;
  *) usage ;;
esac
