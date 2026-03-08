#!/usr/bin/env bash

validate_config() {
  if ! [[ "$SPEED" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    notify "Invalid speed '$SPEED'. Use a number like 1.0, 1.3, or 1.4."
    exit 1
  fi

  if ! [[ "$SPEAKER" =~ ^[0-9]+$ ]]; then
    notify "Invalid speaker '$SPEAKER'. Use a non-negative integer."
    exit 1
  fi

  if ! [[ "$MAX_CHARS" =~ ^[0-9]+$ ]] || (( MAX_CHARS <= 0 )); then
    notify "Invalid max chars '$MAX_CHARS'. Use a positive integer."
    exit 1
  fi

  if ! [[ "$EXPLAIN_MAX_CHARS" =~ ^[0-9]+$ ]] || (( EXPLAIN_MAX_CHARS <= 0 )); then
    notify "Invalid explain max chars '$EXPLAIN_MAX_CHARS'. Use a positive integer."
    exit 1
  fi

  if ! [[ "$PROBLEM_SOLVER_MAX_CHARS" =~ ^[0-9]+$ ]] || (( PROBLEM_SOLVER_MAX_CHARS <= 0 )); then
    notify "Invalid problem solver max chars '$PROBLEM_SOLVER_MAX_CHARS'. Use a positive integer."
    exit 1
  fi

  if ! [[ "$ASK_MAX_CHARS" =~ ^[0-9]+$ ]] || (( ASK_MAX_CHARS <= 0 )); then
    notify "Invalid ask max chars '$ASK_MAX_CHARS'. Use a positive integer."
    exit 1
  fi

  if [[ ! -f "$MODEL" ]]; then
    notify "Piper model not found at '$MODEL'. Set services.lazy-reader.model to a valid .onnx file path."
    exit 1
  fi

  if [[ -n "$MODEL_CONFIG" ]] && [[ ! -f "$MODEL_CONFIG" ]]; then
    notify "Piper model config not found at '$MODEL_CONFIG'."
    exit 1
  fi
}

speak_text() {
  local text="$1"
  local started_message="$2"

  local length_scale
  length_scale="$(awk -v speed="$SPEED" 'BEGIN { printf "%.6f", 1.0 / speed }')"

  # piper-tts auto-detects config as "${model}.json" and ignores -c.
  # Bundle model + config into a temp dir so auto-detection finds both.
  local model_path="$MODEL"
  if [[ -n "$MODEL_CONFIG" ]]; then
    MODEL_DIR="$(mktemp -d)"
    ln -sf "$MODEL" "$MODEL_DIR/model.onnx"
    ln -sf "$MODEL_CONFIG" "$MODEL_DIR/model.onnx.json"
    model_path="$MODEL_DIR/model.onnx"
  fi

  local -a piper_cmd
  piper_cmd=(piper -m "$model_path" -s "$SPEAKER" --length-scale "$length_scale")

  if [[ -n "$PIPER_DATA_DIR" ]]; then
    piper_cmd+=( --data-dir "$PIPER_DATA_DIR" )
  fi

  notify "$started_message"

  if [[ "$STREAM_PLAYBACK" == "1" ]]; then
    if ! printf '%s' "$text" | "${piper_cmd[@]}" -f - 2>/dev/null | play_audio_stream >/dev/null 2>&1; then
      notify "Streaming playback failed. Falling back to file playback."
    else
      return 0
    fi
  fi

  RESPONSE_FILE="$(mktemp --suffix=".wav")"

  if ! printf '%s' "$text" | "${piper_cmd[@]}" -f "$RESPONSE_FILE" >/dev/null 2>&1; then
    notify "Local Piper synthesis failed. Check model path, model config, and speaker ID."
    exit 1
  fi

  if ! play_audio "$RESPONSE_FILE"; then
    notify "Audio playback failed with player '$PLAYER'."
    exit 1
  fi
}
