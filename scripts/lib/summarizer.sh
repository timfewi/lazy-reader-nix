#!/usr/bin/env bash

run_summarizer() {
  local input_text="$1"

  if [[ -z "$SUMMARIZE_CMD" ]]; then
    notify "No summarizer configured. Set services.lazy-reader.summarizeCommand first."
    exit 1
  fi

  local summarized_text
  if ! summarized_text="$(printf '%s' "$input_text" | bash -lc "$SUMMARIZE_CMD" 2>/dev/null)"; then
    notify "Summarize command failed. Check services.lazy-reader.summarizeCommand."
    exit 1
  fi

  if [[ -z "${summarized_text//[[:space:]]/}" ]]; then
    notify "Summarize command returned empty output."
    exit 1
  fi

  trim_text "$summarized_text" "$SUMMARIZE_MAX_CHARS"
}
