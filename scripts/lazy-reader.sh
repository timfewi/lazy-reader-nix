#!/usr/bin/env bash
set -euo pipefail

readonly API_URL="https://api.groq.com/openai/v1/audio/speech"
readonly API_KEY_VAR="${LAZY_READER_API_KEY_VAR:-LAZY_READER_GROQ_API_KEY}"
readonly MODEL="${LAZY_READER_MODEL:-canopylabs/orpheus-v1-english}"
readonly VOICE="${LAZY_READER_VOICE:-troy}"
readonly RESPONSE_FORMAT="${LAZY_READER_RESPONSE_FORMAT:-wav}"
readonly MAX_CHARS="${LAZY_READER_MAX_CHARS:-2400}"
readonly PLAYER="${LAZY_READER_PLAYER:-mpv}"
readonly CONNECT_TIMEOUT="${LAZY_READER_CONNECT_TIMEOUT:-5}"
readonly TOTAL_TIMEOUT="${LAZY_READER_TOTAL_TIMEOUT:-45}"
readonly SPEED="${LAZY_READER_SPEED:-1.4}"
readonly PLAYBACK_SPEED="${LAZY_READER_PLAYBACK_SPEED:-${SPEED}}"
readonly NOTIFY_TITLE="Lazy Reader"
readonly RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
readonly PID_FILE="${RUNTIME_DIR}/lazy-reader.pid"

PLAYER_PID=""
PAYLOAD_FILE=""
RESPONSE_FILE=""
OWNS_PID_FILE="0"

notify() {
  local message="$1"
  printf '%s\n' "[$NOTIFY_TITLE] $message" >&2
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "$NOTIFY_TITLE" "$message"
  fi
}

is_running() {
  [[ -f "$PID_FILE" ]] || return 1

  local pid
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1

  kill -0 "$pid" 2>/dev/null
}

cleanup_stale_pid_file() {
  if [[ -f "$PID_FILE" ]] && ! is_running; then
    rm -f "$PID_FILE"
  fi
}

kill_reader_tree() {
  local pid="$1"

  pkill -TERM -P "$pid" 2>/dev/null || true
  kill -TERM "$pid" 2>/dev/null || true

  for _ in {1..30}; do
    if ! kill -0 "$pid" 2>/dev/null; then
      break
    fi
    sleep 0.05
  done

  if kill -0 "$pid" 2>/dev/null; then
    pkill -KILL -P "$pid" 2>/dev/null || true
    kill -KILL "$pid" 2>/dev/null || true
  fi
}

stop_running_reader() {
  cleanup_stale_pid_file

  if ! is_running; then
    rm -f "$PID_FILE"
    notify "Nothing is reading right now."
    return 0
  fi

  local pid
  pid="$(cat "$PID_FILE")"
  kill_reader_tree "$pid"
  rm -f "$PID_FILE"
  notify "Stopped reading."
}

cleanup() {
  if [[ -n "$PLAYER_PID" ]] && kill -0 "$PLAYER_PID" 2>/dev/null; then
    kill -TERM "$PLAYER_PID" 2>/dev/null || true
  fi

  if [[ -n "$PAYLOAD_FILE" ]]; then
    rm -f "$PAYLOAD_FILE"
  fi

  if [[ -n "$RESPONSE_FILE" ]]; then
    rm -f "$RESPONSE_FILE"
  fi

  if [[ "$OWNS_PID_FILE" == "1" ]] && [[ -f "$PID_FILE" ]]; then
    local owner
    owner="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [[ "$owner" == "$$" ]]; then
      rm -f "$PID_FILE"
    fi
  fi
}

read_selection() {
  local selected=""

  if command -v wl-paste >/dev/null 2>&1; then
    selected="$(wl-paste --no-newline --primary 2>/dev/null || true)"
    if [[ -z "${selected//[[:space:]]/}" ]]; then
      selected="$(wl-paste --no-newline 2>/dev/null || true)"
    fi
  fi

  printf '%s' "$selected"
}

play_audio() {
  local audio_file="$1"

  case "$PLAYER" in
    mpv)
      mpv --no-terminal --really-quiet --audio-display=no --speed="$PLAYBACK_SPEED" "$audio_file" &
      PLAYER_PID="$!"
      wait "$PLAYER_PID"
      PLAYER_PID=""
      ;;
    ffplay)
      ffplay -nodisp -autoexit -loglevel error -af "atempo=${PLAYBACK_SPEED}" "$audio_file" &
      PLAYER_PID="$!"
      wait "$PLAYER_PID"
      PLAYER_PID=""
      ;;
    *)
      notify "Unsupported audio player: $PLAYER"
      exit 1
      ;;
  esac
}

start_reading() {
  if ! [[ "$SPEED" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    notify "Invalid speed '$SPEED'. Use a number like 1.0, 1.3, or 1.4."
    exit 1
  fi

  if ! [[ "$PLAYBACK_SPEED" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    notify "Invalid playback speed '$PLAYBACK_SPEED'. Use a number like 1.0, 1.3, or 1.4."
    exit 1
  fi

  local api_key="${!API_KEY_VAR:-}"
  if [[ -z "$api_key" ]]; then
    notify "Missing API key. Set $API_KEY_VAR in your session."
    exit 1
  fi

  local text
  text="$(read_selection)"

  if [[ -z "${text//[[:space:]]/}" ]]; then
    notify "No selected text found. Highlight text and press Super+S."
    exit 1
  fi

  if (( ${#text} > MAX_CHARS )); then
    text="${text:0:MAX_CHARS}"
  fi

  PAYLOAD_FILE="$(mktemp)"
  RESPONSE_FILE="$(mktemp --suffix=".${RESPONSE_FORMAT}")"

  jq -n \
    --arg model "$MODEL" \
    --arg voice "$VOICE" \
    --arg input "$text" \
    --arg response_format "$RESPONSE_FORMAT" \
    --arg speed "$SPEED" \
    '{model: $model, voice: $voice, input: $input, response_format: $response_format, speed: ($speed | tonumber)}' > "$PAYLOAD_FILE"

  local status_code
  status_code="$({
    curl \
      --silent \
      --show-error \
      --connect-timeout "$CONNECT_TIMEOUT" \
      --max-time "$TOTAL_TIMEOUT" \
      --request POST \
      --url "$API_URL" \
      --header "Authorization: Bearer ${api_key}" \
      --header "Content-Type: application/json" \
      --data @"$PAYLOAD_FILE" \
      --output "$RESPONSE_FILE" \
      --write-out '%{http_code}'
  } || true)"

  if [[ ! "$status_code" =~ ^2 ]]; then
    if grep -qi 'requires terms acceptance' "$RESPONSE_FILE" 2>/dev/null; then
      notify "Model terms not accepted yet. Open https://console.groq.com/playground?model=${MODEL} and accept terms."
      exit 1
    fi

    local error_preview
    error_preview="$(head -c 180 "$RESPONSE_FILE" 2>/dev/null | tr '\n' ' ' || true)"
    notify "TTS request failed (HTTP ${status_code:-unknown}). ${error_preview}"
    exit 1
  fi

  notify "Reading selected text..."

  if ! play_audio "$RESPONSE_FILE"; then
    notify "Audio playback failed with player '$PLAYER'."
    exit 1
  fi
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
    *)
      notify "Usage: lazy-reader [toggle|start|stop|status]"
      exit 1
      ;;
  esac

  echo "$$" > "$PID_FILE"
  OWNS_PID_FILE="1"
  trap cleanup EXIT INT TERM

  start_reading
}

main "$@"
