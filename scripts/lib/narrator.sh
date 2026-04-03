#!/usr/bin/env bash

run_narrator() {
  local input_text="$1"

  if [[ -z "$NARRATE_CMD" ]]; then
    notify "No narrate command configured. Set LAZY_READER_NARRATE_CMD first."
    exit 1
  fi

  local narrated_text
  if ! narrated_text="$(printf '%s' "$input_text" | bash -lc "$NARRATE_CMD" 2>/dev/null)"; then
    notify "Narrate command failed. Check LAZY_READER_NARRATE_CMD."
    exit 1
  fi

  if [[ -z "${narrated_text//[[:space:]]/}" ]]; then
    notify "Narrate command returned empty output."
    exit 1
  fi

  trim_text "$narrated_text" "$NARRATE_MAX_CHARS"
}
