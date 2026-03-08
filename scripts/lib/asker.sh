#!/usr/bin/env bash

# prompt_question — show a GNOME-native zenity entry dialog so the user can
# type a follow-up question.  Stores the question in ASK_QUESTION.
# Returns 0 on success, 2 when the dialog is cancelled or left blank.
prompt_question() {
  if ! command -v zenity >/dev/null 2>&1; then
    notify "Ask mode requires zenity for the question prompt."
    return 1
  fi

  if ! ASK_QUESTION="$(zenity --entry \
       --title="Lazy Reader — Ask" \
       --text="Your question about the selected text:" \
       --width=480 2>/dev/null)"; then
    notify "Ask cancelled."
    return 2
  fi

  if [[ -z "${ASK_QUESTION//[[:space:]]/}" ]]; then
    notify "No question entered. Ask cancelled."
    return 2
  fi
}

# run_asker INPUT_TEXT
# Prompts for a question, then pipes INPUT_TEXT to ASK_CMD with the typed
# question available as LAZY_READER_ASK_QUESTION.  Prints the trimmed answer.
run_asker() {
  local input_text="$1"

  if [[ -z "$ASK_CMD" ]]; then
    notify "No ask command configured. Set services.lazy-reader.askCommand first."
    return 1
  fi

  local ASK_QUESTION
  prompt_question
  local prompt_status=$?
  if [[ "$prompt_status" -ne 0 ]]; then
    return "$prompt_status"
  fi

  local answered_text
  if ! answered_text="$(printf '%s' "$input_text" | LAZY_READER_ASK_QUESTION="$ASK_QUESTION" bash -lc "$ASK_CMD" 2>/dev/null)"; then
    notify "Ask command failed. Check services.lazy-reader.askCommand."
    return 1
  fi

  if [[ -z "${answered_text//[[:space:]]/}" ]]; then
    notify "Ask command returned empty output."
    return 1
  fi

  trim_text "$answered_text" "$ASK_MAX_CHARS"
}
