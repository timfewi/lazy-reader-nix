#!/usr/bin/env bash
set -euo pipefail

# Source lib files relative to this script.
# When run via the Nix wrapper, ${../scripts} copies the full directory to the
# Nix store so BASH_SOURCE[0] resolves correctly in both cases.
_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/config.sh
source "${_DIR}/lib/config.sh"
# shellcheck source=scripts/lib/notify.sh
source "${_DIR}/lib/notify.sh"
# shellcheck source=scripts/lib/pid.sh
source "${_DIR}/lib/pid.sh"
# shellcheck source=scripts/lib/selection.sh
source "${_DIR}/lib/selection.sh"
# shellcheck source=scripts/lib/audio.sh
source "${_DIR}/lib/audio.sh"
# shellcheck source=scripts/lib/tts.sh
source "${_DIR}/lib/tts.sh"
# shellcheck source=scripts/lib/explainer.sh
source "${_DIR}/lib/explainer.sh"
# shellcheck source=scripts/lib/solver.sh
source "${_DIR}/lib/solver.sh"

start_reading() {
  validate_config

  local text
  text="$(read_selection)"

  if [[ -z "${text//[[:space:]]/}" ]]; then
    notify "No selected text found. Highlight text and press Super+S."
    exit 1
  fi

  text="$(trim_text "$text" "$MAX_CHARS")"

  speak_text "$text" "Reading selected text..."
}

explain_selection() {
  validate_config

  local text
  text="$(read_selection)"

  if [[ -z "${text//[[:space:]]/}" ]]; then
    notify "No selected text found. Highlight a snippet and press your explain shortcut."
    exit 1
  fi

  text="$(trim_text "$text" "$MAX_CHARS")"

  local explained_text
  explained_text="$(run_explainer "$text")"

  speak_text "$explained_text" "Reading explanation..."
}

solve_selection() {
  validate_config

  local text
  text="$(read_selection)"

  if [[ -z "${text//[[:space:]]/}" ]]; then
    notify "No selected text found. Highlight a snippet and press your solve shortcut."
    exit 1
  fi

  text="$(trim_text "$text" "$MAX_CHARS")"

  local solved_text
  solved_text="$(run_problem_solver "$text")"

  speak_text "$solved_text" "Reading solution..."
}

main() {
  mkdir -p "$RUNTIME_DIR"
  cleanup_stale_pid_file

  case "${1:-toggle}" in
    stop)
      stop_running_reader
      exit 0
      ;;
    toggle)
      if is_running; then
        stop_running_reader
        exit 0
      fi
      ;;
    start)
      if is_running; then
        notify "Already reading. Press Super+S again to stop."
        exit 0
      fi
      ;;
    status)
      if is_running; then
        echo "reading"
      else
        echo "idle"
      fi
      exit 0
      ;;
    explain)
      if is_running; then
        stop_running_reader
        exit 0
      fi
      ;;
    solve)
      if is_running; then
        stop_running_reader
        exit 0
      fi
      ;;
    *)
      notify "Usage: lazy-reader [toggle|start|stop|status|explain|solve]"
      exit 1
      ;;
  esac

  echo "$$" > "$PID_FILE"
  OWNS_PID_FILE="1"
  trap cleanup EXIT INT TERM

  if [[ "${1:-toggle}" == "explain" ]]; then
    explain_selection
  elif [[ "${1:-toggle}" == "solve" ]]; then
    solve_selection
  else
    start_reading
  fi
}

main "$@"
