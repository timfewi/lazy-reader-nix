#!/usr/bin/env bash

run_explainer() {
  local input_text="$1"

  if [[ -z "$EXPLAIN_CMD" ]]; then
    notify "No explainer configured. Set services.lazy-reader.explainCommand first."
    exit 1
  fi

  local explained_text
  if ! explained_text="$(printf '%s' "$input_text" | bash -lc "$EXPLAIN_CMD" 2>/dev/null)"; then
    notify "Explain command failed. Check services.lazy-reader.explainCommand."
    exit 1
  fi

  if [[ -z "${explained_text//[[:space:]]/}" ]]; then
    notify "Explain command returned empty output."
    exit 1
  fi

  trim_text "$explained_text" "$EXPLAIN_MAX_CHARS"
}
