#!/usr/bin/env bash

# Runtime configuration — values sourced from LAZY_READER_* env vars.
# Mutable globals used by cleanup() and play_audio*().
# shellcheck disable=SC2034  # Shared globals are consumed by sibling sourced files.

normalize_speed_alias() {
  case "${1,,}" in
    slow)
      echo "0.8"
      ;;
    normal)
      echo "1.0"
      ;;
    fast)
      echo "1.4"
      ;;
    *)
      echo "$1"
      ;;
  esac
}

openrouter_api_key_file="${LAZY_READER_OPENROUTER_API_KEY_FILE:-}"
if [[ -z "${LAZY_READER_OPENROUTER_API_KEY:-}" ]] && [[ -n "$openrouter_api_key_file" ]] && [[ -r "$openrouter_api_key_file" ]]; then
  export LAZY_READER_OPENROUTER_API_KEY="$(< "$openrouter_api_key_file")"
fi
readonly OPENROUTER_API_KEY_FILE="$openrouter_api_key_file"

readonly MODEL="${LAZY_READER_MODEL:-/var/lib/piper/en_US-lessac-medium.onnx}"
readonly MODEL_CONFIG="${LAZY_READER_MODEL_CONFIG:-}"
readonly PIPER_DATA_DIR="${LAZY_READER_PIPER_DATA_DIR:-}"
readonly SPEAKER="${LAZY_READER_SPEAKER:-0}"
readonly MAX_CHARS="${LAZY_READER_MAX_CHARS:-2400}"
readonly PLAYER="${LAZY_READER_PLAYER:-mpv}"
SPEED="$(normalize_speed_alias "${LAZY_READER_SPEED:-${LAZY_READER_PLAYBACK_SPEED:-1.4}}")"
readonly SPEED
PLAYBACK_SPEED="$(normalize_speed_alias "${LAZY_READER_PLAYBACK_SPEED:-1.0}")"
readonly PLAYBACK_SPEED
readonly GENERATED_SPEECH_CHUNK_MAX_CHARS="${LAZY_READER_GENERATED_SPEECH_CHUNK_MAX_CHARS:-1400}"
readonly STREAM_PLAYBACK="${LAZY_READER_STREAM_PLAYBACK:-1}"
TTS_PROVIDER="${LAZY_READER_TTS_PROVIDER:-piper}"
TTS_MODEL="${LAZY_READER_TTS_MODEL:-tts-1}"
TTS_VOICE="${LAZY_READER_TTS_VOICE:-alloy}"
readonly NARRATE_CMD="${LAZY_READER_NARRATE_CMD:-}"
readonly NARRATE_INPUT_MAX_CHARS="${LAZY_READER_NARRATE_INPUT_MAX_CHARS:-4800}"
readonly NARRATE_MAX_CHARS="${LAZY_READER_NARRATE_MAX_CHARS:-${MAX_CHARS}}"
readonly EXPLAIN_CMD="${LAZY_READER_EXPLAIN_CMD:-}"
readonly EXPLAIN_MAX_CHARS="${LAZY_READER_EXPLAIN_MAX_CHARS:-${MAX_CHARS}}"
readonly SUMMARIZE_CMD="${LAZY_READER_SUMMARIZE_CMD:-}"
readonly SUMMARIZE_MAX_CHARS="${LAZY_READER_SUMMARIZE_MAX_CHARS:-3200}"
readonly SUMMARIZE_INPUT_MAX_CHARS="${LAZY_READER_SUMMARIZE_INPUT_MAX_CHARS:-6000}"
readonly PROBLEM_SOLVER_CMD="${LAZY_READER_PROBLEM_SOLVER_CMD:-}"
readonly PROBLEM_SOLVER_MAX_CHARS="${LAZY_READER_PROBLEM_SOLVER_MAX_CHARS:-${MAX_CHARS}}"
readonly ASK_CMD="${LAZY_READER_ASK_CMD:-}"
readonly ASK_MAX_CHARS="${LAZY_READER_ASK_MAX_CHARS:-${MAX_CHARS}}"
readonly TEACH_CMD="${LAZY_READER_TEACH_CMD:-}"
readonly TEACH_MAX_CHARS="${LAZY_READER_TEACH_MAX_CHARS:-3000}"
readonly TEACH_INPUT_MAX_CHARS="${LAZY_READER_TEACH_INPUT_MAX_CHARS:-5000}"
readonly NOTIFY_TITLE="Lazy Reader"
readonly RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
readonly PID_FILE="${RUNTIME_DIR}/lazy-reader.pid"

NOTIFY_ID=""
PLAYER_PID=""
RESPONSE_FILE=""
MODEL_DIR=""
OWNS_PID_FILE="0"
