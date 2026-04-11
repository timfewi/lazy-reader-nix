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
# shellcheck source=scripts/lib/narrator.sh
source "${_DIR}/lib/narrator.sh"
# shellcheck source=scripts/lib/explainer.sh
source "${_DIR}/lib/explainer.sh"
# shellcheck source=scripts/lib/summarizer.sh
source "${_DIR}/lib/summarizer.sh"
# shellcheck source=scripts/lib/solver.sh
source "${_DIR}/lib/solver.sh"
# shellcheck source=scripts/lib/asker.sh
source "${_DIR}/lib/asker.sh"
# shellcheck source=scripts/lib/teacher.sh
source "${_DIR}/lib/teacher.sh"

start_reading() {
  validate_config

  local text
  local chunk
  local chunk_index=0
  text="$(read_selection)"

  if [[ -z "${text//[[:space:]]/}" ]]; then
    notify "No selected text found. Highlight text and press Super+S."
    exit 1
  fi

  while IFS= read -r -d '' chunk; do
    if (( chunk_index == 0 )); then
      speak_text "$chunk" "Reading selected text..."
    else
      speak_text "$chunk" ""
    fi
    ((chunk_index += 1))
  done < <(chunk_text_for_reading "$text" "$MAX_CHARS")
}

speak_generated_text() {
  local text="$1"
  local started_message="$2"
  local chunk
  local chunk_index=0

  while IFS= read -r -d '' chunk; do
    if (( chunk_index == 0 )); then
      speak_text "$chunk" "$started_message"
    else
      speak_text "$chunk" ""
    fi
    ((chunk_index += 1))
  done < <(chunk_text_for_reading "$text" "$GENERATED_SPEECH_CHUNK_MAX_CHARS")
}

narrate_selection() {
  validate_config

  local text
  text="$(read_selection)"

  if [[ -z "${text//[[:space:]]/}" ]]; then
    notify "No selected text found. Highlight a passage and press your narrate shortcut."
    exit 1
  fi

  text="$(trim_text "$text" "$NARRATE_INPUT_MAX_CHARS")"

  local narrated_text
  narrated_text="$(run_narrator "$text")"

  speak_generated_text "$narrated_text" "Reading narration..."
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

  speak_generated_text "$explained_text" "Reading explanation..."
}

summarize_selection() {
  validate_config

  local text
  text="$(read_selection)"

  if [[ -z "${text//[[:space:]]/}" ]]; then
    notify "No selected text found. Highlight a passage and press your summarize shortcut."
    exit 1
  fi

  text="$(trim_text "$text" "$SUMMARIZE_INPUT_MAX_CHARS")"

  local summarized_text
  summarized_text="$(run_summarizer "$text")"

  speak_generated_text "$summarized_text" "Reading summary..."
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

  speak_generated_text "$solved_text" "Reading solution..."
}

ask_selection() {
  validate_config

  local text
  text="$(read_selection)"

  if [[ -z "${text//[[:space:]]/}" ]]; then
    notify "No selected text found. Highlight a snippet and press your ask shortcut."
    exit 1
  fi

  text="$(trim_text "$text" "$MAX_CHARS")"

  local answered_text
  local answer_file
  local ask_status
  answer_file="$(mktemp)"
  if run_asker "$text" > "$answer_file"; then
    answered_text="$(cat "$answer_file")"
  else
    ask_status=$?
    rm -f "$answer_file"
    if [[ "$ask_status" -eq 2 ]]; then
      exit 0
    fi
    exit "$ask_status"
  fi
  rm -f "$answer_file"

  if [[ -z "${answered_text//[[:space:]]/}" ]]; then
    exit 0
  fi

  speak_generated_text "$answered_text" "Reading answer..."
}

teach_selection() {
  validate_config

  local text
  text="$(read_selection)"

  if [[ -z "${text//[[:space:]]/}" ]]; then
    notify "No selected text found. Highlight a passage and press your teach shortcut."
    exit 1
  fi

  text="$(trim_text "$text" "$TEACH_INPUT_MAX_CHARS")"

  local taught_text
  taught_text="$(run_teacher "$text")"

  speak_generated_text "$taught_text" "Reading explanation..."
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
    summarize)
      if is_running; then
        stop_running_reader
        exit 0
      fi
      ;;
    narrate)
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
    ask)
      if is_running; then
        stop_running_reader
        exit 0
      fi
      ;;
    teach)
      if is_running; then
        stop_running_reader
        exit 0
      fi
      ;;
    *)
      notify "Usage: lazy-reader [toggle|start|stop|status|narrate|explain|summarize|solve|ask|teach]"
      exit 1
      ;;
  esac

  echo "$$" > "$PID_FILE"
  OWNS_PID_FILE="1"
  trap cleanup EXIT INT TERM

  if [[ "${1:-toggle}" == "narrate" ]]; then
    narrate_selection
  elif [[ "${1:-toggle}" == "explain" ]]; then
    explain_selection
  elif [[ "${1:-toggle}" == "summarize" ]]; then
    summarize_selection
  elif [[ "${1:-toggle}" == "solve" ]]; then
    solve_selection
  elif [[ "${1:-toggle}" == "ask" ]]; then
    ask_selection
  elif [[ "${1:-toggle}" == "teach" ]]; then
    teach_selection
  else
    start_reading
  fi
}

main "$@"
