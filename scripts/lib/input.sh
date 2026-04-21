#!/usr/bin/env bash

input_is_blank() {
  local text="${1:-}"
  [[ -z "${text//[[:space:]]/}" ]]
}

read_input_from_provider() {
  local provider_cmd="${INPUT_PROVIDER_CMD:-}"
  if [[ -z "$provider_cmd" ]]; then
    return 1
  fi

  local provided_text
  if ! provided_text="$(bash -lc "$provider_cmd" 2>/dev/null)"; then
    notify "Input provider command failed. Check LAZY_READER_INPUT_PROVIDER_CMD."
    exit 1
  fi

  printf '%s' "$provided_text"
}

input_has_stdin() {
  [[ ! -t 0 ]]
}

read_input_from_stdin() {
  cat
}

read_input_from_primary_selection() {
  local selected=""

  if command -v wl-paste >/dev/null 2>&1; then
    selected="$(wl-paste --no-newline --primary 2>/dev/null || true)"
  fi

  printf '%s' "$selected"
}

read_input_from_clipboard() {
  local selected=""

  if command -v wl-paste >/dev/null 2>&1; then
    selected="$(wl-paste --no-newline 2>/dev/null || true)"
  fi

  printf '%s' "$selected"
}

validate_input_source_name() {
  case "${1:-auto}" in
    auto|provider|stdin|primary|selection|clipboard|argument|arg|text)
      return 0
      ;;
    *)
      notify "Unsupported input source '${1}'. Use auto, provider, stdin, primary, clipboard, or argument."
      exit 1
      ;;
  esac
}

resolve_input_text() {
  local argument_text="${1:-}"
  local requested_source="${2:-${INPUT_SOURCE:-auto}}"
  local text=""

  validate_input_source_name "$requested_source"

  if [[ -n "${argument_text//[[:space:]]/}" ]]; then
    if [[ "$requested_source" != "auto" && "$requested_source" != "argument" && "$requested_source" != "arg" && "$requested_source" != "text" ]]; then
      notify "--text cannot be combined with --source '$requested_source'. Use --source argument or omit --source."
      exit 1
    fi

    printf '%s' "$argument_text"
    return 0
  fi

  case "$requested_source" in
    auto)
      text="$(read_input_from_provider || true)"
      if ! input_is_blank "$text"; then
        printf '%s' "$text"
        return 0
      fi

      if input_has_stdin; then
        text="$(read_input_from_stdin)"
        if ! input_is_blank "$text"; then
          printf '%s' "$text"
          return 0
        fi
      fi

      text="$(read_input_from_primary_selection)"
      if ! input_is_blank "$text"; then
        printf '%s' "$text"
        return 0
      fi

      text="$(read_input_from_clipboard)"
      printf '%s' "$text"
      ;;
    provider)
      if ! text="$(read_input_from_provider)"; then
        notify "No input provider configured. Set LAZY_READER_INPUT_PROVIDER_CMD or choose another source."
        exit 1
      fi
      printf '%s' "$text"
      ;;
    stdin)
      if input_has_stdin; then
        read_input_from_stdin
      fi
      ;;
    primary|selection)
      read_input_from_primary_selection
      ;;
    clipboard)
      read_input_from_clipboard
      ;;
    argument|arg|text)
      printf '%s' "$argument_text"
      ;;
  esac
}
