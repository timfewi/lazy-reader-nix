#!/usr/bin/env bash

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

trim_text() {
  local text="$1"
  local max_chars="$2"

  if (( ${#text} > max_chars )); then
    text="${text:0:max_chars}"
  fi

  printf '%s' "$text"
}
