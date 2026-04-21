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
# shellcheck source=scripts/lib/input.sh
source "${_DIR}/lib/input.sh"
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

MODE="toggle"
INPUT_TEXT_ARG=""
INPUT_SOURCE_OVERRIDE=""

usage_error() {
  notify "Usage: lazy-reader [toggle|start|stop|status|narrate|explain|summarize|solve|ask|teach] [--source auto|provider|stdin|primary|clipboard|argument] [--text 'text to read']"
  exit 1
}

parse_args() {
  local mode_seen="0"

  MODE="toggle"
  INPUT_TEXT_ARG=""
  INPUT_SOURCE_OVERRIDE=""

  while (( $# )); do
    case "$1" in
      toggle|start|stop|status|narrate|explain|summarize|solve|ask|teach)
        if [[ "$mode_seen" == "1" ]]; then
          usage_error
        fi
        MODE="$1"
        mode_seen="1"
        shift
        ;;
      --text)
        if (( $# < 2 )) || [[ -n "$INPUT_TEXT_ARG" ]]; then
          usage_error
        fi
        INPUT_TEXT_ARG="$2"
        shift 2
        ;;
      --source)
        if (( $# < 2 )) || [[ -n "$INPUT_SOURCE_OVERRIDE" ]]; then
          usage_error
        fi
        INPUT_SOURCE_OVERRIDE="$2"
        shift 2
        ;;
      *)
        usage_error
        ;;
    esac
  done
}

read_mode_input_or_exit() {
  local empty_message="$1"
  local text

  text="$(resolve_input_text "$INPUT_TEXT_ARG" "$INPUT_SOURCE_OVERRIDE")"

  if [[ -z "${text//[[:space:]]/}" ]]; then
    notify "$empty_message"
    exit 1
  fi

  printf '%s' "$text"
}

start_reading() {
  validate_config

  local text
  local section_index=0
  local section_kind
  local section_text
  text="$(read_mode_input_or_exit "No input text found. Highlight text, copy text, pipe text in, or pass --text.")"

  while IFS= read -r -d '' section_kind && IFS= read -r -d '' section_text; do
    if (( section_index == 0 )); then
      speak_reading_section "$section_kind" "$section_text" "Reading selected text..."
    else
      speak_reading_section "$section_kind" "$section_text" ""
    fi
    ((section_index += 1))
  done < <(split_text_into_reading_sections "$text")
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

speak_reading_section() {
  local section_kind="$1"
  local section_text="$2"
  local started_message="$3"
  local chunk
  local chunk_index=0

  if [[ "$section_kind" == "code" ]]; then
    if [[ -n "$EXPLAIN_CMD" ]]; then
      section_text="$(trim_text "$section_text" "$MAX_CHARS")"
      speak_generated_text "$(run_explainer "$section_text")" "$started_message"
      return 0
    fi

    if [[ -n "$NARRATE_CMD" ]]; then
      section_text="$(trim_text "$section_text" "$NARRATE_INPUT_MAX_CHARS")"
      speak_generated_text "$(run_narrator "$section_text")" "$started_message"
      return 0
    fi
  fi

  while IFS= read -r -d '' chunk; do
    if (( chunk_index == 0 )); then
      speak_text "$chunk" "$started_message"
    else
      speak_text "$chunk" ""
    fi
    ((chunk_index += 1))
  done < <(chunk_text_for_reading "$section_text" "$MAX_CHARS")
}

narrate_selection() {
  validate_config

  local text
  text="$(read_mode_input_or_exit "No input text found. Highlight, copy, pipe, or pass --text before narrate.")"

  text="$(trim_text "$text" "$NARRATE_INPUT_MAX_CHARS")"

  local narrated_text
  narrated_text="$(run_narrator "$text")"

  speak_generated_text "$narrated_text" "Reading narration..."
}

explain_selection() {
  validate_config

  local text
  text="$(read_mode_input_or_exit "No input text found. Highlight, copy, pipe, or pass --text before explain.")"

  text="$(trim_text "$text" "$MAX_CHARS")"

  local explained_text
  explained_text="$(run_explainer "$text")"

  speak_generated_text "$explained_text" "Reading explanation..."
}

summarize_selection() {
  validate_config

  local text
  text="$(read_mode_input_or_exit "No input text found. Highlight, copy, pipe, or pass --text before summarize.")"

  text="$(trim_text "$text" "$SUMMARIZE_INPUT_MAX_CHARS")"

  local summarized_text
  summarized_text="$(run_summarizer "$text")"

  speak_generated_text "$summarized_text" "Reading summary..."
}

solve_selection() {
  validate_config

  local text
  text="$(read_mode_input_or_exit "No input text found. Highlight, copy, pipe, or pass --text before solve.")"

  text="$(trim_text "$text" "$MAX_CHARS")"

  local solved_text
  solved_text="$(run_problem_solver "$text")"

  speak_generated_text "$solved_text" "Reading solution..."
}

ask_selection() {
  validate_config

  local text
  text="$(read_mode_input_or_exit "No input text found. Highlight, copy, pipe, or pass --text before ask.")"

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
  text="$(read_mode_input_or_exit "No input text found. Highlight, copy, pipe, or pass --text before teach.")"

  text="$(trim_text "$text" "$TEACH_INPUT_MAX_CHARS")"

  local taught_text
  taught_text="$(run_teacher "$text")"

  speak_generated_text "$taught_text" "Reading explanation..."
}

main() {
  parse_args "$@"
  mkdir -p "$RUNTIME_DIR"
  cleanup_stale_pid_file

  case "$MODE" in
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
  esac

  echo "$$" > "$PID_FILE"
  OWNS_PID_FILE="1"
  trap cleanup EXIT INT TERM

  if [[ "$MODE" == "narrate" ]]; then
    narrate_selection
  elif [[ "$MODE" == "explain" ]]; then
    explain_selection
  elif [[ "$MODE" == "summarize" ]]; then
    summarize_selection
  elif [[ "$MODE" == "solve" ]]; then
    solve_selection
  elif [[ "$MODE" == "ask" ]]; then
    ask_selection
  elif [[ "$MODE" == "teach" ]]; then
    teach_selection
  else
    start_reading
  fi
}

main "$@"
