#!/usr/bin/env bash

run_teacher() {
  local input_text="$1"

  if [[ -z "$TEACH_CMD" ]]; then
    notify "No teach command configured. Set services.lazy-reader.teachCommand first."
    exit 1
  fi

  local taught_text
  if ! taught_text="$(printf '%s' "$input_text" | bash -lc "$TEACH_CMD" 2>/dev/null)"; then
    notify "Teach command failed. Check services.lazy-reader.teachCommand."
    exit 1
  fi

  if [[ -z "${taught_text//[[:space:]]/}" ]]; then
    notify "Teach command returned empty output."
    exit 1
  fi

  trim_text "$taught_text" "$TEACH_MAX_CHARS"
}
